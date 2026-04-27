import UIKit
import Supabase

/// 마지막 세차일 기준으로 앱 아이콘을 5단계로 자동 변경하는 서비스
///
/// - Stage 1 (nil / Primary): 세차 직후 (0~2일)
/// - Stage 2: 깨끗함 (3~5일)
/// - Stage 3: 보통 (6~10일)
/// - Stage 4: 더러움 (11~20일)
/// - Stage 5: 세차 필요 (21일 이상)
@MainActor
final class DynamicIconService {
    static let shared = DynamicIconService()
    private init() {}

    // MARK: - 아이콘 단계 결정

    /// 마지막 세차일로부터 경과 일수에 따른 아이콘 이름 반환
    /// - Returns: nil = Primary(Stage1), "AppIconStage2"~"AppIconStage5"
    func iconName(daysSinceWash days: Int) -> String? {
        switch days {
        case 0...2:  return nil              // Stage 1: Primary Icon
        case 3...5:  return "AppIconStage2"  // Clean
        case 6...10: return "AppIconStage3"  // Normal
        case 11...20: return "AppIconStage4" // Dirty
        default:     return "AppIconStage5"  // Wash Me (21+)
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

    private func setIcon(_ name: String?) async {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(name)
            print("DynamicIconService: icon changed to \(name ?? "Primary")")
        } catch {
            print("DynamicIconService: setAlternateIconName error - \(error)")
        }
    }
}
