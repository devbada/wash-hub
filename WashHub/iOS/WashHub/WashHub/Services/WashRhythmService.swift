import Foundation
import Combine
import Supabase

/// 세차 리듬 서비스 — wash_logs 조회 + 정거장 변환 + 다음 세차일 계산 + 주기 설정 저장
@MainActor
final class WashRhythmService: ObservableObject {
    @Published var summary: WashRhythmSummary?
    @Published var isLoading: Bool = false
    /// 다음 세차일에 대한 날씨 정보 (P3-013)
    @Published var nextWashWeather: NextWashWeather?
    @Published var isWeatherLoading: Bool = false

    // 차량별 마지막 fetch 시점 캐싱 (60초 throttle)
    private static let cacheTTL: TimeInterval = 60
    private static let summaryCache = TimedCache<String, WashRhythmSummary>(ttl: cacheTTL)
    /// 날씨는 1시간 캐싱 (단기/장기 모두) — 같은 날짜 반복 조회 시 트래픽 절감
    private static let weatherCacheTTL: TimeInterval = 60 * 60
    private static let nextWeatherCache = TimedCache<String, NextWashWeather>(ttl: weatherCacheTTL)

    /// 캐시 무효화 — wash_log mutation 또는 주기 변경 시
    static func invalidateCache(carId: String? = nil) {
        if let carId = carId {
            summaryCache.invalidate(for: carId)
        } else {
            summaryCache.invalidateAll()
        }
    }

    // MARK: - 차량 리듬 로드
    /// - Parameters:
    ///   - car: 대상 차량
    ///   - forceRefresh: 캐시 무시
    func loadRhythm(for car: MyCar, forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = Self.summaryCache.value(for: car.id) {
            summary = cached
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // 최근 6개월 + 노선도 표시용 최근 30건 — 두 조건 모두 만족
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            let cutoffDateStr = dateFormatter.string(from: sixMonthsAgo)

            let persistLogs: [WashLog] = try await supabase
                .from("wash_logs")
                .select("*, feeds(id, content, thumbnail_url, like_count, comment_count)")
                .eq("car_id", value: car.id)
                .eq("status", value: "ACTIVE")
                .gte("wash_date", value: cutoffDateStr)
                .order("wash_date", ascending: true)
                .limit(30)
                .execute()
                .value

            // 정거장 변환
            let parsedStations: [WashRhythmStation] = persistLogs.compactMap { log in
                guard let washDate = Self.parseDate(log.washDate) else { return nil }
                return WashRhythmStation(
                    id: log.id,
                    date: washDate,
                    kind: .past,
                    washLogId: log.id,
                    feedId: log.feedId,
                    memo: log.memo
                )
            }

            // 평균/최근 간격 계산
            let intervals = Self.calcIntervals(stations: parsedStations)
            let avgInterval = Self.average(intervals)
            let recentInterval = intervals.last

            // 적용 주기 + 다음 세차일 계산
            let effectiveInterval = car.effectiveWashIntervalDays
            let lastDate = parsedStations.last?.date
            let nextDate: Date? = lastDate.map {
                Calendar.current.date(byAdding: .day, value: effectiveInterval, to: $0)
            } ?? nil

            // 다음 추천 정거장 추가
            var stations = parsedStations
            if let nextDate = nextDate {
                stations.append(
                    WashRhythmStation(
                        id: "next-\(car.id)-\(Self.dateKey(nextDate))",
                        date: nextDate,
                        kind: .nextRecommended,
                        washLogId: nil,
                        feedId: nil,
                        memo: nil
                    )
                )
            }

            // 다음 세차일까지 남은 일수 (KST 기준 자정 비교)
            let daysUntil: Int? = nextDate.flatMap { next in
                Self.daysBetween(from: Date(), to: next)
            }

            // 올해 누적 — 1/1 부터 현재까지 wash_logs 건수 (별도 쿼리)
            let washCountThisYear = try await loadWashCountThisYear(carId: car.id)

            let result = WashRhythmSummary(
                stations: stations,
                averageIntervalDays: avgInterval,
                recentIntervalDays: recentInterval,
                effectiveIntervalDays: effectiveInterval,
                isAutoMode: car.isAutoIntervalMode,
                lastWashDate: lastDate,
                nextWashDate: nextDate,
                daysUntilNextWash: daysUntil,
                washCountThisYear: washCountThisYear
            )

            summary = result
            Self.summaryCache.set(result, for: car.id)

            // 다음 세차일 날씨도 함께 로드 (가능한 경우)
            if let next = nextDate, let days = daysUntil {
                await loadNextWashWeather(for: next, daysUntil: days)
            }
        } catch {
            print("WashRhythm load error: \(error)")
            summary = nil
        }
    }

    // MARK: - 주기 설정 저장
    /// - Parameters:
    ///   - car: 대상 차량
    ///   - option: 사용자 선택 옵션
    func saveInterval(for car: MyCar, option: WashIntervalOption) async throws {
        let session = try await supabase.auth.session
        // 본인 차량만 수정 — RLS 가 동일 사용자 검증
        let payload: [String: Int?] = [
            "preferred_wash_interval_days": option.storedValue
        ]
        try await supabase
            .from("my_cars")
            .update(payload)
            .eq("id", value: car.id)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()

        // 캐시 무효화 + 화면들에 변경 알림 → cars 배열 재로드 트리거
        Self.invalidateCache(carId: car.id)
        NotificationCenter.default.post(
            name: .washCarIntervalChanged,
            object: nil,
            userInfo: ["carId": car.id]
        )
    }

    // MARK: - Helpers

    /// "2026-04-22" 또는 "2026-04-22T00:00:00+09:00" 형식 모두 파싱
    private static func parseDate(_ raw: String) -> Date? {
        let truncated = String(raw.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: truncated)
    }

    private static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    /// 정거장 간 일수 차이 배열
    private static func calcIntervals(stations: [WashRhythmStation]) -> [Int] {
        guard stations.count >= 2 else { return [] }
        var result: [Int] = []
        for i in 1..<stations.count {
            let prev = stations[i - 1].date
            let curr = stations[i].date
            if let days = daysBetween(from: prev, to: curr), days > 0, days <= 60 {
                result.append(days)
            }
        }
        return result
    }

    private static func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return Int(round(Double(sum) / Double(values.count)))
    }

    /// 두 날짜 사이 일수 (자정 기준, KST)
    static func daysBetween(from: Date, to: Date) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let startOfFrom = calendar.startOfDay(for: from)
        let startOfTo = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: startOfFrom, to: startOfTo).day
    }

    // MARK: - 다음 세차일 날씨 로드 (P3-013)

    /// 다음 세차 추천일의 날씨 정보 로드
    /// - D-Day 거리에 따라 단기/장기 자동 분기
    /// - 결과는 `nextWashWeather` 에 publish 됨
    func loadNextWashWeather(for nextDate: Date, daysUntil: Int) async {
        let cacheKey = Self.dateKey(nextDate) + "-d\(daysUntil)"

        if let cached = Self.nextWeatherCache.value(for: cacheKey) {
            nextWashWeather = cached
            isWeatherLoading = false
            return
        }

        isWeatherLoading = true
        defer { isWeatherLoading = false }

        // D-30+ 또는 음수(이미 지남) 는 표시 안 함
        guard daysUntil >= 0 && daysUntil <= 30 else {
            let unavailable = NextWashWeather(
                source: .unavailable,
                date: nextDate, daysUntil: daysUntil,
                rainProbability: nil, temperature: nil, score: nil,
                message: daysUntil < 0
                    ? "이미 추천일이 지났어요. 곧 다음 세차일이 표시됩니다."
                    : "30일 이상은 예측이 어려워요.",
                reliability: 0,
                isRainExpected: false
            )
            nextWashWeather = unavailable
            return
        }

        let result: NextWashWeather
        if daysUntil <= 7 {
            // 단기 — 7일 예보 데이터 사용 (앱 다른 곳에서 이미 forecast 호출 중이면 재활용)
            result = await loadShortTermWeather(for: nextDate, daysUntil: daysUntil)
        } else {
            // 장기 — Edge Function longrange mode 호출
            result = await loadLongRangeWeather(for: nextDate, daysUntil: daysUntil)
        }

        nextWashWeather = result
        Self.nextWeatherCache.set(result, for: cacheKey)
    }

    /// 단기(D-1~7) — WashIndexService 의 forecast 데이터를 재사용
    private func loadShortTermWeather(for nextDate: Date, daysUntil: Int) async -> NextWashWeather {
        // 7일 예보를 호출 (이미 캐시되어 있으면 즉시 반환)
        let weatherService = WashIndexService()
        await weatherService.loadForecast()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let targetDateStr = formatter.string(from: nextDate)

        if let day = weatherService.forecast.first(where: { $0.date == targetDateStr }) {
            // 신뢰도: D-1 ★★★★★, D-7 ★★★★
            let reliability = max(4, 5 - daysUntil / 3)
            let isRainExpected = day.rainProbability >= 60 || day.pty > 0
            let weatherEmoji = day.weatherIcon
            // 친화적 메시지
            let weatherText: String = {
                if day.pty > 0 { return "비 예보" }
                switch day.sky {
                case 1: return "맑음"
                case 3: return "구름많음"
                default: return "흐림"
                }
            }()
            let msg = "\(weatherText) · \(day.score)점 \(weatherEmoji)"
            return NextWashWeather(
                source: .shortTerm,
                date: nextDate, daysUntil: daysUntil,
                rainProbability: day.rainProbability,
                temperature: Double(day.tempMax + day.tempMin) / 2.0,
                score: day.score,
                message: msg,
                reliability: reliability,
                isRainExpected: isRainExpected
            )
        }

        // 단기 예보에 해당 일자가 없으면 장기로 fallback
        return await loadLongRangeWeather(for: nextDate, daysUntil: daysUntil)
    }

    /// 장기(D-8~30) — Edge Function `weather-proxy` 의 `mode: "longrange"` 호출
    private func loadLongRangeWeather(for nextDate: Date, daysUntil: Int) async -> NextWashWeather {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let targetDateStr = formatter.string(from: nextDate)

        // 사용자 위치 — 현재는 서울 기본 (P3-013 후속에서 CLLocationManager 정확도 향상)
        let nx = 60, ny = 127, sidoName = "서울"

        struct LongRangeRequest: Encodable {
            let nx: Int
            let ny: Int
            let sidoName: String
            let mode: String
            let targetDate: String
        }
        let payload = LongRangeRequest(nx: nx, ny: ny, sidoName: sidoName, mode: "longrange", targetDate: targetDateStr)

        do {
            let resp: LongRangeWeatherResponse = try await supabase.functions
                .invoke("weather-proxy", options: .init(body: payload))

            if !resp.hasData {
                return NextWashWeather(
                    source: .longRange,
                    date: nextDate, daysUntil: daysUntil,
                    rainProbability: nil, temperature: nil, score: nil,
                    message: resp.message,
                    reliability: 1,
                    isRainExpected: false
                )
            }

            let isRainExpected = resp.rainDays >= 4
            return NextWashWeather(
                source: .longRange,
                date: nextDate, daysUntil: daysUntil,
                rainProbability: nil,
                temperature: resp.avgTemp,
                score: resp.avgScore,
                message: resp.message,
                reliability: resp.reliability,
                isRainExpected: isRainExpected
            )
        } catch {
            print("LongRange weather load error: \(error)")
            return NextWashWeather(
                source: .unavailable,
                date: nextDate, daysUntil: daysUntil,
                rainProbability: nil, temperature: nil, score: nil,
                message: "장기 예측 데이터를 가져올 수 없어요. 곧 새 예보가 나옵니다.",
                reliability: 0,
                isRainExpected: false
            )
        }
    }

    private func loadWashCountThisYear(carId: String) async throws -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let yearStart = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: Date()), month: 1, day: 1
        ))!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let yearStartStr = formatter.string(from: yearStart)

        struct CountRow: Decodable { let id: String }
        let rows: [CountRow] = try await supabase
            .from("wash_logs")
            .select("id")
            .eq("car_id", value: carId)
            .eq("status", value: "ACTIVE")
            .gte("wash_date", value: yearStartStr)
            .execute()
            .value
        return rows.count
    }
}
