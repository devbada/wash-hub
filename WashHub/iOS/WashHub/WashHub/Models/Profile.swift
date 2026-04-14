import Foundation

struct Profile: Identifiable, Codable {
    let id: String
    let username: String?
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let carCount: Int?
    let washCount: Int?
    let followerCount: Int?
    let followingCount: Int?
    let isActive: Bool?
    let titleBadgeId: String?
    let agreedTermsAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case nickname
        case avatarUrl = "avatar_url"
        case bio
        case carCount = "car_count"
        case washCount = "wash_count"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case isActive = "is_active"
        case titleBadgeId = "title_badge_id"
        case agreedTermsAt = "agreed_terms_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 표시용 닉네임 (닉네임 미설정 시 "사용자")
    var displayName: String {
        nickname ?? "사용자"
    }
}
