import Foundation

// MARK: - 뱃지 정의
struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let badgeType: String
    let unlockCondition: BadgeCondition?
    let sortOrder: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconName = "icon_name"
        case badgeType = "badge_type"
        case unlockCondition = "unlock_condition"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct BadgeCondition: Codable {
    let type: String
    let value: Int
}

// MARK: - 사용자 뱃지 (획득 기록)
struct UserBadge: Identifiable, Codable {
    let id: String
    let userId: String
    let badgeId: String
    let unlockedAt: String
    let createdAt: String

    // 조인 데이터
    let badges: Badge?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case badgeId = "badge_id"
        case unlockedAt = "unlocked_at"
        case createdAt = "created_at"
        case badges
    }
}

// MARK: - RPC 응답 (새로 획득한 뱃지)
struct NewlyUnlockedBadge: Codable {
    let badgeId: String
    let badgeName: String
    let badgeType: String
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case badgeId = "badge_id"
        case badgeName = "badge_name"
        case badgeType = "badge_type"
        case iconName = "icon_name"
    }
}

// MARK: - 뱃지 타입 enum
enum BadgeType: String, CaseIterable {
    case newcomer = "NEWCOMER"
    case activist = "ACTIVIST"
    case critic = "CRITIC"
    case recommender = "RECOMMENDER"
    case helper = "HELPER"
    case celebrity = "CELEBRITY"
    case collector = "COLLECTOR"
    case master = "MASTER"

    var displayName: String {
        switch self {
        case .newcomer: return "새로운 시작"
        case .activist: return "열정적인 활동가"
        case .critic: return "비평가"
        case .recommender: return "추천왕"
        case .helper: return "도우미"
        case .celebrity: return "유명인"
        case .collector: return "수집가"
        case .master: return "마스터"
        }
    }

    /// 뱃지 배경 그라데이션 컬러 (언락 시 사용)
    var gradientColors: (start: String, end: String) {
        switch self {
        case .newcomer: return ("#4FC3F7", "#29B6F6")
        case .activist: return ("#FF7043", "#F4511E")
        case .critic: return ("#FFD54F", "#FFC107")
        case .recommender: return ("#81C784", "#66BB6A")
        case .helper: return ("#BA68C8", "#AB47BC")
        case .celebrity: return ("#F06292", "#EC407A")
        case .collector: return ("#4DD0E1", "#26C6DA")
        case .master: return ("#FFD700", "#FFA000")
        }
    }
}
