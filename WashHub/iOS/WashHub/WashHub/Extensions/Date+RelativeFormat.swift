import Foundation

extension Date {
    /// ISO8601 문자열을 상대 시간으로 변환
    /// - Parameters:
    ///   - dateString: ISO8601 형식 날짜 문자열
    ///   - now: 기준 시각 (타이머 갱신 시 주입)
    /// - Returns: "방금 전", "5분 전", "2시간 전" 등
    static func relativeTime(from dateString: String, now: Date = Date()) -> String {
        // Supabase는 마이크로초(6자리) 포함 ISO8601 반환 — DateFormatter로 유연하게 파싱
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")

        // 1) 마이크로초 포함: 2026-04-14T12:34:56.789012+00:00
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        var date = df.date(from: dateString)

        // 2) 밀리초 포함: 2026-04-14T12:34:56.789+00:00
        if date == nil {
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            date = df.date(from: dateString)
        }

        // 3) 초 단위만: 2026-04-14T12:34:56+00:00
        if date == nil {
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            date = df.date(from: dateString)
        }

        // 4) ISO8601DateFormatter 폴백
        if date == nil {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = iso.date(from: dateString)
        }
        if date == nil {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: dateString)
        }

        guard let created = date else { return String(dateString.prefix(10)) }

        let interval = now.timeIntervalSince(created)

        // 미래 시간 방지 (서버 시간 차이)
        guard interval >= 0 else { return "방금 전" }

        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }

        // 7일 이상이면 날짜 고정 — 타이머 갱신 불필요
        return String(dateString.prefix(10))
    }
}
