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
    /// 썸네일이 어느 사진에서 만들어졌는지 — "BEFORE" / "AFTER" / "EXTRA". legacy 피드는 nil → 배지 미표시
    let thumbnailImageType: String?
    /// HashtagGenerator 가 추출한 해시태그 (예: ["#K8", "#셀프세차"])
    let hashtags: [String]
    let createdAt: String
    let updatedAt: String
    let isEdited: Bool

    // PPL / 협찬
    let isSponsored: Bool
    let sponsorName: String?

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
        case thumbnailImageType = "thumbnail_image_type"
        case hashtags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isEdited = "is_edited"
        case isSponsored = "is_sponsored"
        case sponsorName = "sponsor_name"
        case profiles
        case myCars = "my_cars"
    }

    /// 리스트 카드 배지 라벨 — "Before" / "After" / nil(미표시)
    /// EXTRA 는 사진 종류로 표기할 만한 의미가 약하므로 배지 미표시
    var thumbnailBadgeLabel: String? {
        switch thumbnailImageType {
        case "BEFORE": return "Before"
        case "AFTER":  return "After"
        default:       return nil
        }
    }
}

/// 피드에 JOIN되는 차량 요약 정보
struct FeedCar: Codable {
    let id: String
    let carModel: String
    let carColor: String?
    let carYear: Int?
    /// 차량 별명 — 해시태그 자동 태깅용
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case id
        case carModel = "car_model"
        case carColor = "car_color"
        case carYear = "car_year"
        case nickname
    }
}

struct FeedImage: Identifiable, Codable {
    let id: String
    let feedId: String
    let imageType: String   // "BEFORE" / "AFTER"
    let imageUrl: String
    let displayOrder: Int
    /// 원본 이미지 가로/세로 픽셀. legacy 데이터는 nil → 4:5 portrait fallback
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case feedId = "feed_id"
        case imageType = "image_type"
        case imageUrl = "image_url"
        case displayOrder = "display_order"
        case width
        case height
    }

    /// 가로/세로 비율 (nil = 정보 없음)
    var aspectRatio: CGFloat? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }

    /// 가로 사진 여부 (정보 없으면 false)
    var isLandscape: Bool {
        guard let ratio = aspectRatio else { return false }
        return ratio > 1.0
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
