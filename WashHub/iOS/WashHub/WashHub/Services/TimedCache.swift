import Foundation

/// 시간 기반(TTL) 캐시 — 키별로 값 + 저장 시각을 보관하고 TTL을 넘기면 무효 처리
///
/// 사용 예:
/// ```
/// private static let weatherCache = TimedCache<String, WeatherData>(ttl: 3 * 60 * 60)  // 3h
///
/// if let cached = Self.weatherCache.value(for: gridKey) {
///     return cached
/// }
/// // ... fetch ...
/// Self.weatherCache.set(fetched, for: gridKey)
/// ```
///
/// - Important: `@MainActor` 서비스에서 사용 시 동시성은 자동 직렬화됨. 그 외 환경에서는 외부 락 필요.
@MainActor
final class TimedCache<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let storedAt: Date
    }

    private var entries: [Key: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    /// TTL 내 유효한 값. 만료/없음이면 nil 반환 (만료 엔트리는 자동 제거)
    func value(for key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        if Date().timeIntervalSince(entry.storedAt) > ttl {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    /// 값 저장 (저장 시각 = now)
    func set(_ value: Value, for key: Key) {
        entries[key] = Entry(value: value, storedAt: Date())
    }

    /// 특정 키 무효화
    func invalidate(for key: Key) {
        entries.removeValue(forKey: key)
    }

    /// 전체 캐시 무효화
    func invalidateAll() {
        entries.removeAll()
    }
}
