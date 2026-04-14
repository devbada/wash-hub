import Foundation

// MARK: - 신고 대상 타입
enum ReportTargetType: String, Codable, CaseIterable {
    case user = "USER"
    case feed = "FEED"
    case comment = "COMMENT"
    case review = "REVIEW"
}

// MARK: - 신고 사유
enum ReportReason: String, Codable, CaseIterable {
    case spam = "SPAM"
    case harassment = "HARASSMENT"
    case obscene = "OBSCENE"
    case misleading = "MISLEADING"
    case copyright = "COPYRIGHT"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .spam:        return "스팸/광고"
        case .harassment:  return "괴롭힘/혐오"
        case .obscene:     return "음란/선정적"
        case .misleading:  return "허위/사기"
        case .copyright:   return "저작권 침해"
        case .other:       return "기타"
        }
    }
}

// MARK: - 신고
struct Report: Identifiable, Codable {
    let id: String
    let reporterId: String
    let targetType: String
    let targetId: String
    let reason: String
    let description: String?
    let status: String
    let createdAt: String
    let resolvedAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case reason, description, status
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
        case updatedAt = "updated_at"
    }

    /// 상태 한글 표시
    var statusDisplay: String {
        switch status {
        case "PENDING":  return "검토 대기"
        case "RESOLVED": return "처리 완료"
        case "REJECTED": return "반려"
        default:         return status
        }
    }

    /// 사유 한글 표시
    var reasonDisplay: String {
        ReportReason(rawValue: reason)?.displayName ?? reason
    }
}
