import Foundation

struct MyCar: Identifiable, Codable {
    let id: String
    let userId: String
    let carModel: String
    let carColor: String?
    let carYear: Int?
    let carNumber: String?
    let imageUrl: String?
    let isPrimary: Bool
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carModel = "car_model"
        case carColor = "car_color"
        case carYear = "car_year"
        case carNumber = "car_number"
        case imageUrl = "image_url"
        case isPrimary = "is_primary"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WashLog: Identifiable, Codable {
    let id: String
    let userId: String
    let carId: String
    let carWashId: String?
    let washDate: String
    let memo: String?
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case carWashId = "car_wash_id"
        case washDate = "wash_date"
        case memo, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
