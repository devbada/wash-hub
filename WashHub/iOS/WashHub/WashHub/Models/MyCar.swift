import Foundation

struct MyCar: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let carModel: String
    let carColor: String?
    let carYear: Int?
    let carNumber: String?
    /// 사용자가 부여한 별명 — 피드 작성 시 해시태그로 자동 추가됨 (예: "내검둥이" → "#내검둥이")
    let nickname: String?
    let imageUrl: String?
    let isPrimary: Bool
    let status: String
    let createdAt: String
    let updatedAt: String

    // P3-012 세차 리듬 — 차량별 주기 설정
    /// 사용자가 명시한 세차 주기 (1~60일). nil 이면 auto_recommended 사용
    let preferredWashIntervalDays: Int?
    /// wash_logs 기반 자동 추천 주기 (DB 트리거가 갱신)
    let autoRecommendedIntervalDays: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carModel = "car_model"
        case carColor = "car_color"
        case carYear = "car_year"
        case carNumber = "car_number"
        case nickname
        case imageUrl = "image_url"
        case isPrimary = "is_primary"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case preferredWashIntervalDays = "preferred_wash_interval_days"
        case autoRecommendedIntervalDays = "auto_recommended_interval_days"
    }

    /// 적용 주기 — preferred 가 있으면 그 값, 없으면 auto_recommended, 둘 다 없으면 14
    var effectiveWashIntervalDays: Int {
        preferredWashIntervalDays ?? autoRecommendedIntervalDays ?? 14
    }

    /// 자동 모드 여부 — preferred 가 nil 일 때
    var isAutoIntervalMode: Bool {
        preferredWashIntervalDays == nil
    }
}

struct WashLog: Identifiable, Codable {
    let id: String
    let userId: String
    let carId: String
    let carWashId: String?
    let feedId: String?
    let washDate: String
    let memo: String?
    let status: String
    let createdAt: String
    let updatedAt: String

    /// JOIN 시 연결된 피드 요약 정보
    var feeds: WashLogFeedSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case carWashId = "car_wash_id"
        case feedId = "feed_id"
        case washDate = "wash_date"
        case memo, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case feeds
    }
}

/// 세차 기록에 JOIN 되는 피드 요약 정보
struct WashLogFeedSummary: Codable {
    let id: String
    let content: String?
    let thumbnailUrl: String?
    let likeCount: Int
    let commentCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case thumbnailUrl = "thumbnail_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
    }
}
