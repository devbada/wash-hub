import UIKit
import Supabase

/// 마지막 세차일 기준으로 앱 아이콘을 5단계로 자동 변경하는 서비스
///
/// - Just Washed (Primary, nil): 세차 직후 (0~2일)
/// - Clean   (AppIconClean):   3~5일
/// - Normal  (AppIconNormal):  6~10일
/// - Dirty   (AppIconDirty):   11~20일
/// - Wash Me (AppIconWashMe):  21일 이상
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

    /// 마지막 세차 기록을 조회하여 앱 아이콘을 자동 변경
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

    // MARK: - DB 조회

    /// wash_logs 테이블에서 가장 최근 세차일 조회 → 경과 일수 반환
    /// 아이콘 변경 기준: 마지막 세차 기록(wash_date)
    private func fetchDaysSinceLastWash(userId: String) async -> Int {
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
                // 세차 기록 없음 → 가장 더러운 상태
                return 999
            }

            // "2026-04-20" 형식 → Date 변환
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Asia/Seoul")

            guard let washDate = formatter.date(from: String(latest.washDate.prefix(10))) else {
                return 999
            }

            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: washDate, to: Date()).day ?? 999
            return max(days, 0)
        } catch {
            print("DynamicIconService: fetch error - \(error)")
            return 999
        }
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
