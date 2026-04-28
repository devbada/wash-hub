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

    /// 디버그 모드에서 자동 업데이트 방지용 플래그
    #if DEBUG
    private var debugOverrideActive = false
    #endif

    // MARK: - 아이콘 단계 결정

    /// 마지막 세차일로부터 경과 일수에 따른 아이콘 이름 반환
    /// - Returns: nil = Primary(Stage1), "AppIconStage2"~"AppIconWashMe"
    func iconName(daysSinceWash days: Int) -> String? {
        switch days {
        case 0...2:  return nil              // Stage 1: Primary Icon
        case 3...5:  return "AppIconStage2"  // Clean
        case 6...10: return "AppIconStage3"  // Normal
        case 11...20: return "AppIconStage4" // Dirty
        default:     return "AppIconWashMe"  // Wash Me (21+)
        }
    }

    // MARK: - 아이콘 업데이트

    /// 마지막 세차 기록을 조회하여 앱 아이콘을 자동 변경
    func updateIconIfNeeded() async {
        #if DEBUG
        // 디버그 테스트 중이면 자동 업데이트 건너뛰기
        if debugOverrideActive {
            print("🧪 DynamicIconService: debugOverride active — skipping auto update")
            return
        }
        #endif

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
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ DynamicIconService: supportsAlternateIcons = false")
            return
        }
        print("🔄 DynamicIconService: attempting setAlternateIconName(\(name ?? "nil/Primary"))")
        print("🔄 DynamicIconService: current alternateIconName = \(UIApplication.shared.alternateIconName ?? "nil/Primary")")
        do {
            try await UIApplication.shared.setAlternateIconName(name)
            print("✅ DynamicIconService: icon changed to \(name ?? "Primary")")
        } catch {
            print("❌ DynamicIconService: setAlternateIconName FAILED - \(error)")
            print("❌ DynamicIconService: error localizedDescription - \(error.localizedDescription)")
        }
    }

    // MARK: - 디버그 (개발 중 테스트용 — 출시 전 제거)

    /// 특정 Stage로 강제 변경 (1=Primary, 2~5)
    /// 자동 업데이트를 30초간 비활성화하여 테스트 결과 확인 가능
    /// - Note: Stage 5는 iOS 26.4에서 "AppIconStage5" 이름이 거부되는 이슈가 있어 "AppIconWashMe"로 매핑됨
    func debugSetStage(_ stage: Int) async {
        debugOverrideActive = true
        let name: String?
        switch stage {
        case ...1:  name = nil               // Primary (Stage 1)
        case 2:     name = "AppIconStage2"
        case 3:     name = "AppIconStage3"
        case 4:     name = "AppIconStage4"
        default:    name = "AppIconWashMe"   // Stage 5+
        }
        print("🧪 DynamicIconService: DEBUG force set to Stage \(stage) → \(name ?? "Primary")")
        print("🧪 DynamicIconService: auto-update disabled for 30s")
        await setIcon(name)

        // 30초 후 자동 업데이트 복원
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            debugOverrideActive = false
            print("🧪 DynamicIconService: auto-update re-enabled")
        }
    }
}
