import Foundation
import CoreLocation
import Combine

@MainActor
final class WashIndexService: ObservableObject {
    @Published var washIndex: WashIndex?
    @Published var isLoading = false

    // MARK: - 세차지수 계산 (기상청 API 기반)
    // TODO-minam: 실제 기상청 API 키 등록 후 실제 데이터 연동
    func loadWashIndex(latitude: Double = 37.5665, longitude: Double = 126.9780) async {
        isLoading = true

        do {
            // 기상청 단기예보 API 호출
            let weatherData = try await fetchWeatherData(latitude: latitude, longitude: longitude)
            washIndex = calculateIndex(from: weatherData)
        } catch {
            print("WashIndex load error: \(error)")
            // 에러 시 기본값 (날씨 데이터 없을 때)
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

    // MARK: - 기상청 API 호출
    private func fetchWeatherData(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        // 기상청 단기예보 API URL
        // TODO-minam: 실제 API 키로 교체
        let apiKey = "DEMO_KEY"
        let grid = convertToGrid(lat: latitude, lng: longitude)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let baseDate = dateFormatter.string(from: Date())

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "HH"
        let currentHour = Int(hourFormatter.string(from: Date())) ?? 6
        // 기상청 발표 시간: 02, 05, 08, 11, 14, 17, 20, 23
        let baseTimes = [2, 5, 8, 11, 14, 17, 20, 23]
        let baseTime = baseTimes.last(where: { $0 <= currentHour }) ?? 23
        let baseTimeStr = String(format: "%02d00", baseTime)

        let urlString = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst?serviceKey=\(apiKey)&numOfRows=50&pageNo=1&dataType=JSON&base_date=\(baseDate)&base_time=\(baseTimeStr)&nx=\(grid.x)&ny=\(grid.y)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)

        // API 응답 파싱
        var rain = 0
        var humidity = 50
        var temp = 20.0

        for item in response.response.body.items.item {
            switch item.category {
            case "POP": rain = Int(item.fcstValue) ?? 0          // 강수확률
            case "REH": humidity = Int(item.fcstValue) ?? 50     // 습도
            case "TMP": temp = Double(item.fcstValue) ?? 20      // 기온
            default: break
            }
        }

        return WeatherResponse(rainProbability: rain, humidity: humidity, temperature: temp, fineDust: 30)
    }

    // MARK: - 세차지수 계산 (룰 기반)
    private func calculateIndex(from weather: WeatherResponse) -> WashIndex {
        var score = 100

        // 강수확률
        if weather.rainProbability > 80 {
            score -= 60
        } else if weather.rainProbability > 60 {
            score -= 40
        } else if weather.rainProbability > 40 {
            score -= 20
        } else if weather.rainProbability > 20 {
            score -= 10
        }

        // 미세먼지 (PM10 기준: 좋음 0-30, 보통 31-80, 나쁨 81-150, 매우나쁨 151+)
        if weather.fineDust > 150 {
            score -= 30
        } else if weather.fineDust > 80 {
            score -= 20
        } else if weather.fineDust > 50 {
            score -= 10
        }

        // 습도
        if weather.humidity > 90 {
            score -= 15
        } else if weather.humidity > 80 {
            score -= 10
        } else if weather.humidity > 70 {
            score -= 5
        }

        // 기온 (너무 춥거나 더우면 감점)
        if weather.temperature < 0 {
            score -= 15
        } else if weather.temperature < 5 {
            score -= 10
        } else if weather.temperature > 35 {
            score -= 10
        }

        score = max(score, 0)

        let message: String
        let recommendation: String
        switch score {
        case 80...100:
            message = "세차하기 완벽한 날!"
            recommendation = "지금 바로 세차하세요"
        case 60..<80:
            message = "세차하기 좋은 날"
            recommendation = weather.humidity > 70 ? "낮 시간대를 추천합니다" : "아무 때나 OK"
        case 40..<60:
            message = "세차 가능하지만 주의"
            recommendation = weather.rainProbability > 40 ? "비 예보를 확인하세요" : "미세먼지에 유의하세요"
        case 20..<40:
            message = "세차 비추천"
            recommendation = "내일 날씨를 확인해보세요"
        default:
            message = "오늘은 세차를 쉬세요"
            recommendation = "비가 와도 세차? 오늘은 참으세요 😅"
        }

        return WashIndex(
            score: score,
            message: message,
            recommendation: recommendation,
            details: WashIndex.WashIndexDetails(
                rainProbability: weather.rainProbability,
                fineDust: weather.fineDust,
                humidity: weather.humidity,
                temperature: weather.temperature
            )
        )
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
}

// MARK: - 기상청 API 응답 모델
private struct WeatherResponse {
    let rainProbability: Int
    let humidity: Int
    let temperature: Double
    let fineDust: Int
}

private struct WeatherAPIResponse: Codable {
    let response: WeatherAPIBody
}

private struct WeatherAPIBody: Codable {
    let body: WeatherAPIBodyContent
}

private struct WeatherAPIBodyContent: Codable {
    let items: WeatherAPIItems
}

private struct WeatherAPIItems: Codable {
    let item: [WeatherAPIItem]
}

private struct WeatherAPIItem: Codable {
    let category: String
    let fcstValue: String
}
