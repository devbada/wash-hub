import Foundation

struct Feed: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String?
    let content: String?
    let location: String?
    let washMethod: String?
    let carId: String?
    let status: String
    let likeCount: Int
    let commentCount: Int
    let thumbnailUrl: String?
    let createdAt: String
    let updatedAt: String

    /// JOIN 시 작성자 프로필
    var profiles: Profile?
    /// JOIN 시 차량 정보
    var myCars: FeedCar?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, content, location
        case washMethod = "wash_method"
        case carId = "car_id"
        case status
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case thumbnailUrl = "thumbnail_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
        case myCars = "my_cars"
    }
}

/// 피드에 JOIN되는 차량 요약 정보
struct FeedCar: Codable {
    let id: String
    let carModel: String
    let carColor: String?
    let carYear: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case carModel = "car_model"
        case carColor = "car_color"
        case carYear = "car_year"
    }
}

struct FeedImage: Identifiable, Codable {
    let id: String
    let feedId: String
    let imageType: String   // "BEFORE" / "AFTER"
    let imageUrl: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case feedId = "feed_id"
        case imageType = "image_type"
        case imageUrl = "image_url"
        case displayOrder = "display_order"
    }
}

struct FeedLike: Codable {
    let feedId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case feedId = "feed_id"
        case userId = "user_id"
    }
}

// MARK: - Notification
extension Notification.Name {
    static let feedCreated = Notification.Name("feedCreated")
    /// 좋아요/댓글 등 피드 카운터가 변경됐을 때 브로드캐스트
    /// userInfo["feedId"]: String — 변경된 피드 ID (없으면 전체 리로드)
    static let feedCountChanged = Notification.Name("feedCountChanged")
}
