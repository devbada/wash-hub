import Foundation
import Combine
import Supabase

@MainActor
final class WashIndexService: ObservableObject {
    @Published var washIndex: WashIndex?
    // 뷰가 처음 렌더링될 때 카드가 영(0) 높이로 접히지 않도록 true 로 초기화
    @Published var isLoading = true
    @Published var forecast: [DailyForecast] = []
    @Published var isForecastLoading = false
    /// 현재 날씨 데이터의 지역명 (예: "서울", "경기 김포", "대구")
    @Published var regionName: String = ""

    // MARK: - 캐시 (3시간 TTL — 기상청도 단기예보를 3h 단위로 갱신)
    // @StateObject 가 매 뷰마다 인스턴스를 만들기 때문에 static 으로 인스턴스 간 공유한다
    private static let weatherCacheTTL: TimeInterval = 3 * 60 * 60
    private static let washIndexCache = TimedCache<String, WashIndex>(ttl: weatherCacheTTL)
    private static let forecastCache = TimedCache<String, [DailyForecast]>(ttl: weatherCacheTTL)

    /// 캐시 키 — 기상청 격자(nx, ny) 기준
    private static func cacheKey(nx: Int, ny: Int) -> String { "\(nx)-\(ny)" }

    /// 강제 새로고침이 필요할 때 호출 (pull-to-refresh)
    func invalidateWeatherCache() {
        Self.washIndexCache.invalidateAll()
        Self.forecastCache.invalidateAll()
    }

    // MARK: - 세차지수 로드 (Supabase Edge Function 'weather-proxy' 호출)
    // 기상청 API Hub + 에어코리아 API 키는 Edge Function Secrets 에만 보관
    // iOS 앱에는 API 키가 포함되지 않음 (Secure Coding)
    /// - Parameter forceRefresh: true면 캐시 무시하고 API 강제 호출
    func loadWashIndex(latitude: Double = 37.5665, longitude: Double = 126.9780, forceRefresh: Bool = false) async {
        let grid = convertToGrid(lat: latitude, lng: longitude)
        let key = Self.cacheKey(nx: grid.x, ny: grid.y)
        regionName = guessRegionLabel(lat: latitude, lng: longitude)

        // 1) 캐시 hit → 즉시 반환 (네트워크 호출 skip)
        if !forceRefresh, let cached = Self.washIndexCache.value(for: key) {
            washIndex = cached
            isLoading = false
            return
        }

        // 2) 캐시 miss → 새 데이터 fetch. 정합성을 위해 forecast 캐시도 동시 무효화
        // (두 캐시 만료 시점이 어긋나면 카드 점수 vs 7일 예보 점수가 불일치할 수 있음)
        Self.forecastCache.invalidate(for: key)

        isLoading = true

        do {
            let sidoName = guesssSido(lat: latitude, lng: longitude)

            // [v2 버그 수정] 'current' 모드는 KMA 현재값 조회 실패 시 폴백(강수0/습도50/온도20)이
            // 그대로 점수 계산에 들어가 비 오는 날에도 항상 99점 "완벽한 날"이 나오는 결함이 있었음.
            // → 정상 동작하는 'forecast' 모드를 호출하고 '오늘' 데이터로 세차지수를 구성한다.
            struct ForecastRequest: Encodable {
                let nx: Int
                let ny: Int
                let sidoName: String
                let mode: String
            }
            let payload = ForecastRequest(nx: grid.x, ny: grid.y, sidoName: sidoName, mode: "forecast")

            // Supabase SDK 가 자동으로 Authorization 헤더(JWT)를 포함
            let result: ForecastProxyResponse = try await supabase.functions
                .invoke(
                    "weather-proxy",
                    options: .init(body: payload)
                )

            // '오늘' 예보 항목으로 세차지수 카드 구성 — 7일 예보 화면과 동일 값으로 정합성 보장
            guard let today = result.forecasts.first(where: { $0.dayLabel == "오늘" })
                    ?? result.forecasts.first else {
                throw NSError(domain: "WashIndex", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "오늘 예보 데이터 없음"])
            }

            let loaded = WashIndex(
                score: today.score,
                message: today.message,
                recommendation: recommendation(forScore: today.score),
                forecastNote: nil,
                details: WashIndex.WashIndexDetails(
                    rainProbability: today.rainProbability,
                    fineDust: today.dustPm10,
                    humidity: today.humidity,
                    temperature: Double(today.tempMax)
                )
            )
            washIndex = loaded
            Self.washIndexCache.set(loaded, for: key)
            // 7일 예보도 같은 응답으로 캐시에 채워둠 — 예측 화면 진입 시 재호출 불필요 + 점수 정합성
            Self.forecastCache.set(result.forecasts, for: key)
        } catch {
            print("WashIndex load error: \(error)")
            // 에러 시 기본값 (캐시에 저장하지 않음 — 다음 호출에 재시도)
            washIndex = WashIndex(
                score: 50,
                message: "날씨 정보를 가져올 수 없어요",
                recommendation: "날씨를 직접 확인해주세요",
                forecastNote: nil,
                details: WashIndex.WashIndexDetails(
                    rainProbability: 0,
                    fineDust: 0,
                    humidity: 50,
                    temperature: 20
                )
            )
        }

        isLoading = false
    }

    /// 세차지수 점수 → 추천 문구 (해요체)
    private func recommendation(forScore score: Int) -> String {
        switch score {
        case 80...:     return "지금 세차하기 딱 좋아요"
        case 60..<80:   return "세차할 만한 날이에요"
        case 40..<60:   return "괜찮지만 날씨를 한 번 더 확인해요"
        case 20..<40:   return "오늘은 미루는 게 좋아요"
        default:        return "오늘은 좀 쉬어요"
        }
    }

    // MARK: - 7일 예보 로드
    /// - Parameter forceRefresh: true면 캐시 무시하고 API 강제 호출
    func loadForecast(latitude: Double = 37.5665, longitude: Double = 126.9780, forceRefresh: Bool = false) async {
        let grid = convertToGrid(lat: latitude, lng: longitude)
        let key = Self.cacheKey(nx: grid.x, ny: grid.y)
        if regionName.isEmpty {
            regionName = guessRegionLabel(lat: latitude, lng: longitude)
        }

        // 1) 캐시 hit → 즉시 반환
        if !forceRefresh, let cached = Self.forecastCache.value(for: key) {
            forecast = cached
            isForecastLoading = false
            return
        }

        // 2) 캐시 miss → 새 데이터 fetch. washIndex 캐시도 동시 무효화 (정합성)
        Self.washIndexCache.invalidate(for: key)

        isForecastLoading = true

        do {
            let sidoName = guesssSido(lat: latitude, lng: longitude)

            struct ForecastRequest: Encodable {
                let nx: Int
                let ny: Int
                let sidoName: String
                let mode: String
            }
            let payload = ForecastRequest(nx: grid.x, ny: grid.y, sidoName: sidoName, mode: "forecast")

            let result: ForecastProxyResponse = try await supabase.functions
                .invoke(
                    "weather-proxy",
                    options: .init(body: payload)
                )

            forecast = result.forecasts
            Self.forecastCache.set(result.forecasts, for: key)
        } catch {
            print("Forecast load error: \(error)")
            forecast = []
            // 에러 시 캐시에 저장하지 않음
        }

        isForecastLoading = false
    }

    // MARK: - 위경도 → 기상청 격자 변환
    private func convertToGrid(lat: Double, lng: Double) -> (x: Int, y: Int) {
        let RE = 6371.00877
        let GRID = 5.0
        let SLAT1 = 30.0
        let SLAT2 = 60.0
        let OLON = 126.0
        let OLAT = 38.0
        let XO = 43.0
        let YO = 136.0

        let DEGRAD = Double.pi / 180.0

        let re = RE / GRID
        let slat1 = SLAT1 * DEGRAD
        let slat2 = SLAT2 * DEGRAD
        let olon = OLON * DEGRAD
        let olat = OLAT * DEGRAD

        var sn = tan(Double.pi * 0.25 + slat2 * 0.5) / tan(Double.pi * 0.25 + slat1 * 0.5)
        sn = log(cos(slat1) / cos(slat2)) / log(sn)
        var sf = tan(Double.pi * 0.25 + slat1 * 0.5)
        sf = pow(sf, sn) * cos(slat1) / sn
        var ro = tan(Double.pi * 0.25 + olat * 0.5)
        ro = re * sf / pow(ro, sn)

        var ra = tan(Double.pi * 0.25 + lat * DEGRAD * 0.5)
        ra = re * sf / pow(ra, sn)
        var theta = lng * DEGRAD - olon
        if theta > Double.pi { theta -= 2.0 * Double.pi }
        if theta < -Double.pi { theta += 2.0 * Double.pi }
        theta *= sn

        let x = Int(ra * sin(theta) + XO + 0.5)
        let y = Int(ro - ra * cos(theta) + YO + 0.5)
        return (x, y)
    }

    // MARK: - 위경도 → 표시용 지역명 (넓은 지역 단위)
    // 사용자에게 보여줄 지역명: "서울", "경기 김포", "대구" 등
    private func guessRegionLabel(lat: Double, lng: Double) -> String {
        // 주요 도시/지역 좌표 — 넓은 단위로 매칭
        let regions: [(name: String, lat: Double, lng: Double)] = [
            // 서울 세분화
            ("서울", 37.5665, 126.9780),
            // 경기 주요 도시
            ("경기 수원", 37.2636, 127.0286),
            ("경기 성남", 37.4200, 127.1267),
            ("경기 고양", 37.6584, 126.8320),
            ("경기 용인", 37.2411, 127.1776),
            ("경기 김포", 37.6153, 126.7156),
            ("경기 파주", 37.7599, 126.7802),
            ("경기 화성", 37.1995, 126.8313),
            ("경기 안양", 37.3943, 126.9568),
            ("경기 평택", 36.9921, 127.1129),
            // 광역시
            ("부산", 35.1796, 129.0756),
            ("대구", 35.8714, 128.6014),
            ("인천", 37.4563, 126.7052),
            ("광주", 35.1595, 126.8526),
            ("대전", 36.3504, 127.3845),
            ("울산", 35.5384, 129.3114),
            ("세종", 36.4800, 127.0000),
            // 도 단위
            ("강원 춘천", 37.8813, 127.7300),
            ("강원 원주", 37.3422, 127.9202),
            ("강원 강릉", 37.7519, 128.8761),
            ("충북 청주", 36.6424, 127.4890),
            ("충북 충주", 36.9910, 127.9259),
            ("충남 천안", 36.8151, 127.1139),
            ("충남 아산", 36.7898, 127.0018),
            ("전북 전주", 35.8242, 127.1480),
            ("전남 여수", 34.7604, 127.6622),
            ("전남 순천", 34.9506, 127.4873),
            ("전남 목포", 34.8118, 126.3922),
            ("경북 포항", 36.0190, 129.3435),
            ("경북 경주", 35.8562, 129.2247),
            ("경남 창원", 35.2281, 128.6812),
            ("경남 김해", 35.2285, 128.8894),
            ("제주", 33.4996, 126.5312),
        ]

        var closest = "서울"
        var minDist = Double.greatestFiniteMagnitude
        for region in regions {
            let dist = pow(lat - region.lat, 2) + pow(lng - region.lng, 2)
            if dist < minDist {
                minDist = dist
                closest = region.name
            }
        }
        return closest
    }

    // MARK: - 위경도 → 시도 추정 (에어코리아 시도별 조회용)
    // TODO-minam: Phase 2 에서 CLLocationManager + 역지오코딩으로 정확한 시도 판별
    private func guesssSido(lat: Double, lng: Double) -> String {
        // 주요 광역시/도 중심 좌표 기준 가장 가까운 시도 반환
        let sidos: [(name: String, lat: Double, lng: Double)] = [
            ("서울", 37.5665, 126.9780),
            ("부산", 35.1796, 129.0756),
            ("대구", 35.8714, 128.6014),
            ("인천", 37.4563, 126.7052),
            ("광주", 35.1595, 126.8526),
            ("대전", 36.3504, 127.3845),
            ("울산", 35.5384, 129.3114),
            ("세종", 36.4800, 127.0000),
            ("경기", 37.2750, 127.0094),
            ("강원", 37.8228, 128.1555),
            ("충북", 36.6357, 127.4912),
            ("충남", 36.5184, 126.8000),
            ("전북", 35.8203, 127.1089),
            ("전남", 34.8161, 126.4629),
            ("경북", 36.4919, 128.8889),
            ("경남", 35.4606, 128.2132),
            ("제주", 33.4996, 126.5312),
        ]

        var closest = "서울"
        var minDist = Double.greatestFiniteMagnitude
        for sido in sidos {
            let dist = pow(lat - sido.lat, 2) + pow(lng - sido.lng, 2)
            if dist < minDist {
                minDist = dist
                closest = sido.name
            }
        }
        return closest
    }
}

// MARK: - Forecast 응답 모델
struct DailyForecast: Codable, Identifiable {
    var id: String { date }
    let date: String           // "2026-04-10"
    let dayLabel: String       // "오늘", "내일", "모레", ""
    let dayOfWeek: String      // "월","화",...
    let rainProbability: Int
    let humidity: Int
    let tempMin: Int
    let tempMax: Int
    let sky: Int               // 1:맑음 3:구름많음 4:흐림
    let pty: Int               // 0:없음 1:비 ...
    let dustGrade: String      // "좋음","보통","나쁨","매우나쁨"
    let dustPm10: Int
    let score: Int
    let grade: String
    let message: String

    /// 날씨 SF Symbol
    var weatherIcon: String {
        if pty > 0 {
            switch pty {
            case 3: return "cloud.snow.fill"
            default: return "cloud.rain.fill"
            }
        }
        switch sky {
        case 1: return "sun.max.fill"
        case 3: return "cloud.sun.fill"
        default: return "cloud.fill"
        }
    }

    /// 날짜 포맷: "4/10"
    var shortDate: String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        let month = Int(parts[1]) ?? 0
        let day = Int(parts[2]) ?? 0
        return "\(month)/\(day)"
    }
}

private struct ForecastProxyResponse: Codable {
    let forecasts: [DailyForecast]
}

// MARK: - Edge Function 응답 모델
private struct WeatherProxyResponse: Codable {
    let weather: WeatherData
    let dust: DustData
    let score: Int
    let message: String
    let recommendation: String
    let grade: String
    /// 내일/모레 강수 예보 안내 문구. Edge Function 에서 조건 충족 시에만 채워진다.
    let forecastNote: String?

    struct WeatherData: Codable {
        let rainProbability: Int
        let humidity: Int
        let temperature: Double
        let sky: Int
        let pty: Int
    }

    struct DustData: Codable {
        let pm10: Int
        let pm25: Int
    }
}
