import Foundation

struct CarWash: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let phone: String?
    let description: String?
    let hours: String?
    let washType: String?
    let imageUrl: String?
    let userId: String?
    let rating: Double?
    let reviewCount: Int?
    let status: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, phone, description, hours
        case washType = "wash_type"
        case imageUrl = "image_url"
        case userId = "user_id"
        case rating
        case reviewCount = "review_count"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
