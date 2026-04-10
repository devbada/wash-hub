import Foundation

struct Comment: Identifiable, Codable {
    let id: String
    let feedId: String
    let userId: String
    let parentCommentId: String?
    let content: String
    let status: String
    let createdAt: String
    let updatedAt: String

    /// JOIN 시 작성자 프로필
    var profiles: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case feedId = "feed_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case content, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }
}
