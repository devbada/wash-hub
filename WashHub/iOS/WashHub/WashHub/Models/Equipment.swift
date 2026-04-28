import Foundation

struct Equipment: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let brand: String?
    let description: String?
    let price: Int?
    let imageUrl: String?
    /// 리스트 표시용 200px 썸네일. nil이면 imageUrl로 fallback
    let thumbnailUrl: String?
    let userId: String?
    let rating: Double?
    let reviewCount: Int?
    let status: String?
    let createdAt: String
    let updatedAt: String

    // 제휴 커머스 URL
    let affiliateUrlCoupang: String?
    let affiliateUrlNaver: String?
    let affiliateUrl11st: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, brand, description, price
        case imageUrl = "image_url"
        case thumbnailUrl = "thumbnail_url"
        case userId = "user_id"
        case rating
        case reviewCount = "review_count"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case affiliateUrlCoupang = "affiliate_url_coupang"
        case affiliateUrlNaver = "affiliate_url_naver"
        case affiliateUrl11st = "affiliate_url_11st"
    }

    /// 리스트 표시용 이미지 URL — 썸네일 우선, 없으면 풀이미지로 fallback
    var displayThumbnailUrl: String? {
        if let thumb = thumbnailUrl, !thumb.isEmpty { return thumb }
        return imageUrl
    }

    /// 유효한 제휴 링크 목록
    var affiliateLinks: [AffiliateLink] {
        var links: [AffiliateLink] = []
        if let url = affiliateUrlCoupang, !url.isEmpty {
            links.append(AffiliateLink(provider: .coupang, url: url))
        }
        if let url = affiliateUrlNaver, !url.isEmpty {
            links.append(AffiliateLink(provider: .naver, url: url))
        }
        if let url = affiliateUrl11st, !url.isEmpty {
            links.append(AffiliateLink(provider: .elevenSt, url: url))
        }
        return links
    }
}

// MARK: - 제휴 커머스
enum AffiliateProvider: String, Codable {
    case coupang = "COUPANG"
    case naver = "NAVER"
    case elevenSt = "ELEVEN_ST"

    var displayName: String {
        switch self {
        case .coupang: return "쿠팡"
        case .naver: return "네이버"
        case .elevenSt: return "11번가"
        }
    }

    var iconName: String {
        switch self {
        case .coupang: return "cart.fill"
        case .naver: return "bag.fill"
        case .elevenSt: return "tag.fill"
        }
    }

}

struct AffiliateLink: Identifiable {
    let id = UUID()
    let provider: AffiliateProvider
    let url: String
}

struct AffiliateClick: Codable {
    let equipmentId: String
    let userId: String
    let provider: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case equipmentId = "equipment_id"
        case userId = "user_id"
        case provider, status
    }
}

struct EquipmentReview: Identifiable, Codable {
    let id: String
    let equipmentId: String
    let userId: String
    let rating: Int
    let reviewText: String?
    let status: String
    let createdAt: String
    let updatedAt: String?

    var profiles: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case equipmentId = "equipment_id"
        case userId = "user_id"
        case rating
        case reviewText = "review_text"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
    }
}
