import Foundation

struct Equipment: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let brand: String?
    let description: String?
    let price: Int?
    let imageUrl: String?
    let userId: String?
    let rating: Double?
    let reviewCount: Int?
    let status: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, brand, description, price
        case imageUrl = "image_url"
        case userId = "user_id"
        case rating
        case reviewCount = "review_count"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
