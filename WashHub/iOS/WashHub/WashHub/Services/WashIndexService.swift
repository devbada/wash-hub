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

    // MARK: - 세차지수 로드 (Supabase Edge Function 'weather-proxy' 호출)
    // 기상청 API Hub + 에어코리아 API 키는 Edge Function Secrets 에만 보관
    // iOS 앱에는 API 키가 포함되지 않음 (Secure Coding)
    func loadWashIndex(latitude: Double = 37.5665, longitude: Double = 126.9780) async {
        isLoading = true

        do {
            let grid = convertToGrid(lat: latitude, lng: longitude)
            let sidoName = guesssSido(lat: latitude, lng: longitude)

            // Edge Function 호출 페이로드
            struct WeatherRequest: Encodable {
                let nx: Int
                let ny: Int
                let sidoName: String
            }
            let payload = WeatherRequest(nx: grid.x, ny: grid.y, sidoName: sidoName)

            // Supabase SDK 가 자동으로 Authorization 헤더(JWT)를 포함
            let result: WeatherProxyResponse = try await supabase.functions
                .invoke(
                    "weather-proxy",
                    options: .init(body: payload)
                )

            washIndex = WashIndex(
                score: result.score,
                message: result.message,
                recommendation: result.recommendation,
                details: WashIndex.WashIndexDetails(
                    rainProbability: result.weather.rainProbability,
                    fineDust: result.dust.pm10,
                    humidity: result.weather.humidity,
                    temperature: result.weather.temperature
                )
            )
        } catch {
            print("WashIndex load error: \(error)")
            // 에러 시 기본값
            washIndex = WashIndex(
                score: 50,
                message: "날씨 정보를 가져올 수 없습니다",
                recommendation: "날씨를 직접 확인해주세요",
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

    // MARK: - 7일 예보 로드
    func loadForecast(latitude: Double = 37.5665, longitude: Double = 126.9780) async {
        isForecastLoading = true

        do {
            let grid = convertToGrid(lat: latitude, lng: longitude)
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
        } catch {
            print("Forecast load error: \(error)")
            forecast = []
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
