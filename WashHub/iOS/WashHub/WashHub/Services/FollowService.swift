import Foundation
import Combine
import Supabase

@MainActor
final class FollowService: ObservableObject {
    @Published var followers: [FollowUser] = []
    @Published var followings: [FollowUser] = []
    @Published var followingIds: Set<String> = []  // 내가 팔로우 중인 사용자 ID 셋
    @Published var isLoading = false

    private let pageSize = 20

    // MARK: - 팔로우
    func follow(followerId: String, followingId: String) async -> Bool {
        do {
            let payload = Follow(followerId: followerId, followingId: followingId, createdAt: nil)
            try await supabase
                .from("follows")
                .insert(payload)
                .execute()

            followingIds.insert(followingId)
            print("Follow success: \(followerId) → \(followingId)")
            return true
        } catch {
            print("Follow error: \(error)")
            return false
        }
    }

    // MARK: - 언팔로우
    func unfollow(followerId: String, followingId: String) async -> Bool {
        do {
            try await supabase
                .from("follows")
                .delete()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()

            followingIds.remove(followingId)
            print("Unfollow success: \(followerId) → \(followingId)")
            return true
        } catch {
            print("Unfollow error: \(error)")
            return false
        }
    }

    // MARK: - 팔로우 여부 확인
    func isFollowing(followerId: String, followingId: String) async -> Bool {
        do {
            let persistFollows: [Follow] = try await supabase
                .from("follows")
                .select()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()
                .value

            return !persistFollows.isEmpty
        } catch {
            print("isFollowing check error: \(error)")
            return false
        }
    }

    // MARK: - 내가 팔로우 중인 사용자 ID 목록 로드
    func loadFollowingIds(userId: String) async {
        do {
            let persistFollows: [Follow] = try await supabase
                .from("follows")
                .select("follower_id, following_id")
                .eq("follower_id", value: userId)
                .execute()
                .value

            followingIds = Set(persistFollows.map { $0.followingId })
        } catch {
            print("loadFollowingIds error: \(error)")
        }
    }

    // MARK: - 팔로워 목록 (나를 팔로우하는 사람들)
    func loadFollowers(userId: String, offset: Int = 0) async {
        isLoading = true
        do {
            let persistRows: [FollowerRow] = try await supabase
                .from("follows")
                .select("follower_id, following_id, created_at, follower:profiles!follows_follower_id_fkey(id, nickname, avatar_url, bio, follower_count, following_count, title_badge_id)")
                .eq("following_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            let users = persistRows.map { $0.follower }
            if offset == 0 {
                followers = users
            } else {
                followers.append(contentsOf: users)
            }
        } catch {
            print("loadFollowers error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 팔로잉 목록 (내가 팔로우하는 사람들)
    func loadFollowings(userId: String, offset: Int = 0) async {
        isLoading = true
        do {
            let persistRows: [FollowingRow] = try await supabase
                .from("follows")
                .select("follower_id, following_id, created_at, following:profiles!follows_following_id_fkey(id, nickname, avatar_url, bio, follower_count, following_count, title_badge_id)")
                .eq("follower_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            let users = persistRows.map { $0.following }
            if offset == 0 {
                followings = users
            } else {
                followings.append(contentsOf: users)
            }
        } catch {
            print("loadFollowings error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 팔로잉 피드 (팔로우한 사람들의 피드)
    func loadFollowingFeed(userId: String, offset: Int = 0) async -> [Feed] {
        do {
            // 1) 내가 팔로우한 사용자 ID 목록
            let persistFollows: [Follow] = try await supabase
                .from("follows")
                .select("follower_id, following_id")
                .eq("follower_id", value: userId)
                .execute()
                .value

            let followingIds = persistFollows.map { $0.followingId }

            guard !followingIds.isEmpty else { return [] }

            // 2) 팔로우한 사용자들의 피드 조회
            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select("*, profiles!user_id(id, nickname, avatar_url), my_cars(id, car_model, car_color, car_year)")
                .eq("status", value: "ACTIVE")
                .in("user_id", values: followingIds)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + 9)
                .execute()
                .value

            return persistFeeds
        } catch {
            print("loadFollowingFeed error: \(error)")
            return []
        }
    }

    // MARK: - 특정 사용자의 피드 (프로필 뷰용)
    func loadUserFeed(userId: String, offset: Int = 0) async -> [Feed] {
        do {
            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select("*, profiles!user_id(id, nickname, avatar_url), my_cars(id, car_model, car_color, car_year)")
                .eq("status", value: "ACTIVE")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + 9)
                .execute()
                .value

            return persistFeeds
        } catch {
            print("loadUserFeed error: \(error)")
            return []
        }
    }

    // MARK: - 팔로우 토글 (편의 메서드)
    func toggleFollow(myId: String, targetId: String) async -> Bool {
        if followingIds.contains(targetId) {
            return await unfollow(followerId: myId, followingId: targetId)
        } else {
            return await follow(followerId: myId, followingId: targetId)
        }
    }
}
