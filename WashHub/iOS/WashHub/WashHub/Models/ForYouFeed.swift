import Foundation

/// for-you-feed Edge Function 응답.
/// `Feed` (DB row 매핑) 와는 별개의 추천 결과 전용 모델.
struct ForYouFeedResponse: Decodable {
    let items: [ForYouFeedItem]
    let coldStart: Bool
    let metrics: ForYouFeedMetrics

    enum CodingKeys: String, CodingKey {
        case items
        case coldStart = "coldStart"
        case metrics
    }
}

struct ForYouFeedMetrics: Decodable {
    let sourcesCollected: Int
    let afterPreFilter: Int
    let afterScoring: Int
    let afterPostFilter: Int
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case sourcesCollected
        case afterPreFilter
        case afterScoring
        case afterPostFilter
        case durationMs
    }
}

/// 추천 카드 1건. Edge Function 의 FeedItemResponse 와 1:1 매핑.
struct ForYouFeedItem: Identifiable, Decodable, Equatable {
    let feedId: String
    let authorId: String
    let authorNickname: String?
    let authorAvatarUrl: String?
    let isOfficialAuthor: Bool
    let content: String
    let location: String?
    let likeCount: Int
    let commentCount: Int
    let thumbnailUrl: String?
    let createdAt: String
    let score: Double
    let sources: [String]
    let scoreBreakdown: [String: Double]?

    var id: String { feedId }

    enum CodingKeys: String, CodingKey {
        case feedId
        case authorId
        case authorNickname
        case authorAvatarUrl
        case isOfficialAuthor
        case content
        case location
        case likeCount
        case commentCount
        case thumbnailUrl
        case createdAt
        case score
        case sources
        case scoreBreakdown
    }

    /// ISO 8601 createdAt → Date
    var createdAtDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: createdAt) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: createdAt)
    }

    /// 사용자에게 보여줄 작성자 표시명 (탈퇴 회원 처리는 nickname == nil 가정)
    var displayNickname: String {
        authorNickname ?? "탈퇴한 사용자"
    }

    /// 추천 사유 라벨 — 카드 우상단 배지로 활용 가능
    /// 예: ["FOLLOWING","TRENDING"] → "팔로우 · 인기"
    var sourceBadge: String {
        let map: [String: String] = [
            "FOLLOWING": "팔로우",
            "FAVORITE_SHOP": "단골 세차장",
            "SAME_CAR_MODEL": "같은 차종",
            "NEARBY_LOCATION": "내 주변",
            "TRENDING": "인기",
            "DISCOVERY": "추천",
            "COLD_START": "추천"
        ]
        return sources.compactMap { map[$0] }.prefix(2).joined(separator: " · ")
    }

    /// 기존 `Feed` 모델로 변환 — FeedCard 재사용을 위해.
    /// 추천 응답에 없는 필드(washMethod, hashtags, isSponsored 등)는 안전한 기본값.
    func toFeed() -> Feed {
        let profile = Profile(
            id: authorId,
            username: nil,
            nickname: authorNickname,
            avatarUrl: authorAvatarUrl,
            bio: nil,
            carCount: nil,
            washCount: nil,
            followerCount: nil,
            followingCount: nil,
            isActive: true,
            titleBadgeId: nil,
            agreedTermsAt: nil,
            createdAt: nil,
            updatedAt: nil,
            isOfficial: isOfficialAuthor,
            deletedAt: nil
        )
        return Feed(
            id: feedId,
            userId: authorId,
            title: nil,
            content: content,
            location: location,
            washMethod: nil,
            carId: nil,
            status: "ACTIVE",
            likeCount: likeCount,
            commentCount: commentCount,
            thumbnailUrl: thumbnailUrl,
            thumbnailImageType: nil,
            hashtags: [],
            createdAt: createdAt,
            updatedAt: createdAt,
            isEdited: false,
            isSponsored: false,
            sponsorName: nil,
            profiles: profile,
            myCars: nil
        )
    }
}

/// 응답 페이로드 (요청은 Encodable 구조체로 따로 두기 위해 모델 파일에 함께 정의)
struct ForYouFeedRequest: Encodable {
    let limit: Int
    let offset: Int
    let location: ForYouFeedRequestLocation?
    let debug: Bool

    enum CodingKeys: String, CodingKey {
        case limit, offset, location, debug
    }
}

struct ForYouFeedRequestLocation: Encodable {
    let latitude: Double
    let longitude: Double
}
