import UIKit
import Supabase

/// 마지막 세차일 기준으로 앱 아이콘을 5단계로 자동 변경하는 서비스
///
/// - Just Washed (Primary, nil): 세차 직후 (0~2일)
/// - Clean   (AppIconClean):   3~5일
/// - Normal  (AppIconNormal):  6~10일
/// - Dirty   (AppIconDirty):   11~20일
/// - Wash Me (AppIconWashMe):  21일 이상
///
/// 마지막 세차일은 UserDefaults에 캐싱(TTL 24h)하여 매 호출마다 Supabase를 조회하지 않음.
/// wash_log 변경 시점(`FeedService.createFeed`, `MyCarListView` 차량/세차기록 삭제 등)에 명시적 invalidation 필요.
@MainActor
final class DynamicIconService {
    static let shared = DynamicIconService()
    private init() {}

    // MARK: - 아이콘 단계 결정

    /// 마지막 세차일로부터 경과 일수에 따른 아이콘 이름 반환
    /// - Returns: nil = Primary(Just Washed), 그 외에는 alternate icon 이름
    func iconName(daysSinceWash days: Int) -> String? {
        switch days {
        case 0...2:   return nil                // Just Washed (Primary)
        case 3...5:   return "AppIconClean"
        case 6...10:  return "AppIconNormal"
        case 11...20: return "AppIconDirty"
        default:      return "AppIconWashMe"    // 21일 이상
        }
    }

    // MARK: - 아이콘 업데이트

    /// 마지막 세차 기록을 조회(캐시 우선)하여 앱 아이콘을 자동 변경
    func updateIconIfNeeded() async {
        // 게스트 또는 미로그인 시 기본 아이콘
        guard let userId = supabase.auth.currentUser?.id.uuidString else {
            await setIcon(nil)
            return
        }

        let days = await fetchDaysSinceLastWash(userId: userId)
        let targetIcon = iconName(daysSinceWash: days)

        // 현재 아이콘과 다를 때만 변경 (시스템 알림 최소화)
        let currentIcon = UIApplication.shared.alternateIconName
        if currentIcon != targetIcon {
            await setIcon(targetIcon)
        }
    }

    // MARK: - 캐시 (UserDefaults)

    private enum CacheKey {
        static let userId      = "DynamicIconService.washLog.userId"
        static let washDate    = "DynamicIconService.washLog.washDate"     // "yyyy-MM-dd"
        static let cachedAt    = "DynamicIconService.washLog.cachedAt"     // Date
        static let hasNoRecord = "DynamicIconService.washLog.hasNoRecord"  // Bool — true면 세차 기록 없음
    }

    /// 캐시 TTL — 24시간 (디바이스 간 동기화/예외 케이스 대비 fallback)
    private static let cacheTTL: TimeInterval = 24 * 60 * 60

    /// 날짜 문자열 ↔ Date 변환용 (Asia/Seoul 기준)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        return f
    }()

    /// 캐시 hit 여부와 캐시된 마지막 세차일 반환
    /// - Returns: hit=true면 cache 사용 가능. washDate=nil은 "세차 기록 없음" 캐싱 상태
    private func cachedWashDate(userId: String) -> (hit: Bool, washDate: Date?) {
        let defaults = UserDefaults.standard
        guard let persistCachedUserId = defaults.string(forKey: CacheKey.userId),
              persistCachedUserId == userId,
              let persistCachedAt = defaults.object(forKey: CacheKey.cachedAt) as? Date,
              Date().timeIntervalSince(persistCachedAt) < Self.cacheTTL else {
            return (false, nil)
        }

        if defaults.bool(forKey: CacheKey.hasNoRecord) {
            return (true, nil)  // 캐시 hit, 기록 없음 상태
        }

        guard let persistWashDateStr = defaults.string(forKey: CacheKey.washDate),
              let washDate = Self.dateFormatter.date(from: persistWashDateStr) else {
            return (false, nil)
        }
        return (true, washDate)
    }

    /// 캐시 저장 — washDate=nil이면 "기록 없음" 상태로 저장
    private func saveCachedWashDate(_ washDate: Date?, userId: String) {
        let defaults = UserDefaults.standard
        defaults.set(userId, forKey: CacheKey.userId)
        defaults.set(Date(), forKey: CacheKey.cachedAt)
        if let washDate = washDate {
            defaults.set(Self.dateFormatter.string(from: washDate), forKey: CacheKey.washDate)
            defaults.set(false, forKey: CacheKey.hasNoRecord)
        } else {
            defaults.removeObject(forKey: CacheKey.washDate)
            defaults.set(true, forKey: CacheKey.hasNoRecord)
        }
    }

    /// 새 wash_log 생성 시 호출 — DB 재조회 없이 캐시 즉시 갱신
    /// - Parameters:
    ///   - washDate: 새로 기록된 세차일
    ///   - userId: 현재 사용자 ID
    func recordWashDate(_ washDate: Date, userId: String) {
        saveCachedWashDate(washDate, userId: userId)
    }

    /// 캐시 무효화 — wash_log 삭제, 사용자 로그아웃 등에 호출
    /// 다음 `updateIconIfNeeded()` 호출 시 DB에서 다시 조회됨
    func invalidateWashLogCache() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CacheKey.userId)
        defaults.removeObject(forKey: CacheKey.washDate)
        defaults.removeObject(forKey: CacheKey.cachedAt)
        defaults.removeObject(forKey: CacheKey.hasNoRecord)
    }

    // MARK: - DB 조회

    /// 마지막 세차일 → 경과 일수 (캐시 우선, miss 시 Supabase 조회)
    private func fetchDaysSinceLastWash(userId: String) async -> Int {
        // 1) 캐시 우선 조회
        let cached = cachedWashDate(userId: userId)
        if cached.hit {
            return daysFrom(cached.washDate)
        }

        // 2) 캐시 miss → Supabase 조회 + 캐시 저장
        do {
            struct WashDateRow: Codable {
                let washDate: String
                enum CodingKeys: String, CodingKey {
                    case washDate = "wash_date"
                }
            }

            let persistWashLogs: [WashDateRow] = try await supabase
                .from("wash_logs")
                .select("wash_date")
                .eq("user_id", value: userId)
                .eq("status", value: "ACTIVE")
                .order("wash_date", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let latest = persistWashLogs.first else {
                // 세차 기록 없음 → "기록 없음" 상태도 캐싱하여 다음 호출에서 재조회 방지
                saveCachedWashDate(nil, userId: userId)
                return 999
            }

            guard let washDate = Self.dateFormatter.date(from: String(latest.washDate.prefix(10))) else {
                return 999
            }
            saveCachedWashDate(washDate, userId: userId)
            return daysFrom(washDate)
        } catch {
            print("DynamicIconService: fetch error - \(error)")
            // 조회 실패 시 캐싱하지 않음 (다음 시도에 다시 조회되도록)
            return 999
        }
    }

    /// 마지막 세차일에서 오늘까지 경과 일수 (음수 방지)
    /// - Parameter washDate: nil이면 999 반환 (기록 없음 → 가장 더러운 상태)
    private func daysFrom(_ washDate: Date?) -> Int {
        guard let washDate = washDate else { return 999 }
        let days = Calendar.current.dateComponents([.day], from: washDate, to: Date()).day ?? 999
        return max(days, 0)
    }

    // MARK: - 아이콘 설정

    /// 같은 아이콘으로 너무 짧은 시간에 재호출되는 것을 막기 위한 타임스탬프
    private var lastSetIconAt: Date?

    /// EAGAIN(POSIX 35) 등 일시적 에러 시 자동 재시도 횟수
    private static let maxRetries = 2

    /// 재시도 간 대기 시간 (초)
    private static let retryDelaySeconds: UInt64 = 1

    private func setIcon(_ name: String?, attempt: Int = 0) async {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ DynamicIconService: supportsAlternateIcons = false")
            return
        }

        // 동일 아이콘이면 skip — 시스템 알림/리소스 낭비 방지
        let currentIcon = UIApplication.shared.alternateIconName
        if currentIcon == name {
            return
        }

        // 너무 짧은 간격(1초 이내) 연속 호출 방지 (FeedService + scenePhase 중첩 케이스)
        if let last = lastSetIconAt, Date().timeIntervalSince(last) < 1.0 {
            return
        }
        lastSetIconAt = Date()

        do {
            try await UIApplication.shared.setAlternateIconName(name)
            print("✅ DynamicIconService: icon changed to \(name ?? "Primary")")
        } catch {
            let nsError = error as NSError
            let isEAGAIN = nsError.domain == NSPOSIXErrorDomain && nsError.code == 35

            if isEAGAIN && attempt < Self.maxRetries {
                // LSIconAlertManager 일시적 락 — 잠시 대기 후 재시도
                let nextAttempt = attempt + 1
                print("⚠️ DynamicIconService: EAGAIN — \(Self.retryDelaySeconds)초 후 재시도 (\(nextAttempt)/\(Self.maxRetries))")
                try? await Task.sleep(nanoseconds: Self.retryDelaySeconds * 1_000_000_000)
                lastSetIconAt = nil  // 재시도는 throttle 우회
                await setIcon(name, attempt: nextAttempt)
            } else {
                print("❌ DynamicIconService: setAlternateIconName FAILED - \(error.localizedDescription)")
            }
        }
    }
}
