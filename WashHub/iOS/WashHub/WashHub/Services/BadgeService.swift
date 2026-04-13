import Foundation
import Combine
import Supabase

@MainActor
final class BadgeService: ObservableObject {
    @Published var allBadges: [Badge] = []
    @Published var myBadges: [UserBadge] = []
    @Published var newlyUnlocked: [NewlyUnlockedBadge] = []
    @Published var isLoading = false

    // MARK: - 모든 뱃지 조회
    func loadAllBadges() async {
        do {
            let persistBadges: [Badge] = try await supabase
                .from("badges")
                .select("*")
                .order("sort_order", ascending: true)
                .execute()
                .value
            allBadges = persistBadges
        } catch {
            print("Badge load error: \(error)")
        }
    }

    // MARK: - 내 뱃지 조회 (조인)
    func loadMyBadges(userId: String) async {
        do {
            let persistUserBadges: [UserBadge] = try await supabase
                .from("user_badges")
                .select("*, badges(*)")
                .eq("user_id", value: userId)
                .order("unlocked_at", ascending: true)
                .execute()
                .value
            myBadges = persistUserBadges
        } catch {
            print("My badges load error: \(error)")
        }
    }

    // MARK: - 다른 사용자 뱃지 조회
    func loadUserBadges(userId: String) async -> [UserBadge] {
        do {
            let persistUserBadges: [UserBadge] = try await supabase
                .from("user_badges")
                .select("*, badges(*)")
                .eq("user_id", value: userId)
                .order("unlocked_at", ascending: true)
                .execute()
                .value
            return persistUserBadges
        } catch {
            print("User badges load error: \(error)")
            return []
        }
    }

    // MARK: - 뱃지 체크 (RPC 호출 → 새로 획득한 뱃지 반환)
    func checkAndUnlockBadges() async {
        do {
            let persistNewBadges: [NewlyUnlockedBadge] = try await supabase
                .rpc("rpc_check_my_badges")
                .execute()
                .value
            if !persistNewBadges.isEmpty {
                newlyUnlocked = persistNewBadges
            }
        } catch {
            print("Badge check RPC error: \(error)")
        }
    }

    // MARK: - 대표 타이틀 설정
    func setTitle(userId: String, badgeId: String?) async -> Bool {
        do {
            if let badgeId = badgeId {
                // 해당 뱃지를 획득했는지 확인
                let hasBadge = myBadges.contains { $0.badgeId == badgeId }
                guard hasBadge else {
                    print("Badge not unlocked, cannot set as title") // TODO-minam
                    return false
                }
                try await supabase
                    .from("profiles")
                    .update(["title_badge_id": badgeId])
                    .eq("id", value: userId)
                    .execute()
            } else {
                // 타이틀 해제
                struct NullUpdate: Encodable {
                    let title_badge_id: String? = nil
                }
                try await supabase
                    .from("profiles")
                    .update(NullUpdate())
                    .eq("id", value: userId)
                    .execute()
            }
            return true
        } catch {
            print("Set title error: \(error)") // TODO-minam
            return false
        }
    }

    // MARK: - 획득 여부 확인 헬퍼
    func isUnlocked(badgeId: String) -> Bool {
        myBadges.contains { $0.badgeId == badgeId }
    }

    func unlockedBadgeIds() -> Set<String> {
        Set(myBadges.map { $0.badgeId })
    }

    // MARK: - 새로 획득한 뱃지 소비 (토스트 표시 후 리셋)
    func consumeNewlyUnlocked() {
        newlyUnlocked = []
    }
}
