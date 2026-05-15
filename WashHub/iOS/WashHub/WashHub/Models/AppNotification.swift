import Foundation

// MARK: - 알림 모델
struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let senderId: String?
    let type: NotificationType
    let title: String
    let message: String
    var isRead: Bool
    let actionUrl: String?
    let referenceId: String?
    let readAt: String?
    let createdAt: String
    let expiresAt: String?

    // JOIN: sender 프로필
    let senderProfile: SenderProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case senderId = "sender_id"
        case type, title, message
        case isRead = "is_read"
        case actionUrl = "action_url"
        case referenceId = "reference_id"
        case readAt = "read_at"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case senderProfile = "sender"
    }
}

// MARK: - 알림 타입
enum NotificationType: String, Codable {
    case LIKE
    case COMMENT
    case FOLLOW
    case SYSTEM
    case WASH_REMINDER

    var displayName: String {
        switch self {
        case .LIKE: return "좋아요"
        case .COMMENT: return "댓글"
        case .FOLLOW: return "팔로우"
        case .SYSTEM: return "시스템"
        case .WASH_REMINDER: return "세차 리마인더"
        }
    }

    var iconName: String {
        switch self {
        case .LIKE: return "heart.fill"
        case .COMMENT: return "bubble.right.fill"
        case .FOLLOW: return "person.badge.plus"
        case .SYSTEM: return "bell.fill"
        case .WASH_REMINDER: return "drop.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .LIKE: return "pink"
        case .COMMENT: return "secondary"
        case .FOLLOW: return "tertiary"
        case .SYSTEM: return "textSecondary"
        case .WASH_REMINDER: return "secondary"
        }
    }
}

// MARK: - 발신자 프로필 (JOIN용 경량 모델)
struct SenderProfile: Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    /// 알림 발신자가 이후 탈퇴한 경우 placeholder 표시
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case avatarUrl = "avatar_url"
        case deletedAt = "deleted_at"
    }

    var isDeleted: Bool { deletedAt != nil }

    var displayName: String {
        if isDeleted { return "[탈퇴한 사용자]" }
        return nickname ?? "사용자"
    }
}
