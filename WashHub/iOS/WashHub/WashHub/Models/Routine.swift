import Foundation

struct Routine: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let duration: Int?
    let difficulty: Int?
    let likeCount: Int
    let forkCount: Int
    /// 이 루틴을 따라하기 완료한 횟수 (DB trigger 로 자동 증가)
    let usageCount: Int
    let status: String
    let createdAt: String
    let updatedAt: String

    /// JOIN 시 작성자 프로필
    var profiles: Profile?
    /// JOIN 시 단계 목록
    var routineSteps: [RoutineStep]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, description, duration, difficulty
        case likeCount = "like_count"
        case forkCount = "fork_count"
        case usageCount = "usage_count"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case profiles
        case routineSteps = "routine_steps"
    }

    /// 난이도 텍스트
    var difficultyText: String {
        switch difficulty {
        case 1: return "입문"
        case 2: return "쉬움"
        case 3: return "보통"
        case 4: return "어려움"
        case 5: return "전문가"
        default: return "미지정"
        }
    }

    /// 소요시간 텍스트
    var durationText: String {
        guard let min = duration, min > 0 else { return "미지정" }
        if min < 60 { return "\(min)분" }
        let h = min / 60
        let m = min % 60
        return m > 0 ? "\(h)시간 \(m)분" : "\(h)시간"
    }
}

struct RoutineStep: Identifiable, Codable {
    let id: String
    let routineId: String
    let stepOrder: Int
    let title: String
    let description: String?
    let duration: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case stepOrder = "step_order"
        case title, description, duration
        case createdAt = "created_at"
    }

    /// 소요시간 텍스트
    var durationText: String {
        guard let min = duration, min > 0 else { return "" }
        return "\(min)분"
    }
}

struct RoutineProduct: Identifiable, Codable {
    let id: String
    let routineId: String
    let productName: String
    let equipmentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case productName = "product_name"
        case equipmentId = "equipment_id"
    }
}

struct RoutineExecution: Identifiable, Codable {
    let id: String
    let routineId: String
    let userId: String
    let status: String
    let startedAt: String
    let completedAt: String?
    /// 시작 ~ 완료 사이 실제 소요 초 (FollowRoutineView 의 elapsedSeconds)
    let durationSeconds: Int?
    /// 사용자가 피드로 공유한 경우 그 피드 ID (NULL=공유 안 함)
    let feedId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case userId = "user_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case feedId = "feed_id"
    }
}

struct RoutineExecutionStep: Identifiable, Codable {
    let id: String
    let executionId: String
    let stepId: String
    var completed: Bool
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case executionId = "execution_id"
        case stepId = "step_id"
        case completed
        case completedAt = "completed_at"
    }
}

// MARK: - Notification
extension Notification.Name {
    /// 루틴 따라하기 완료 시 브로드캐스트 — 리스트/디테일 화면에서 usage_count 즉시 갱신
    /// userInfo["routineId"]: String — 완료된 루틴 ID
    static let routineCompleted = Notification.Name("routineCompleted")

    /// 가운데 FAB → 루틴 추가 요청 — RoutineListView 가 자체 추가 sheet 띄움
    static let requestRoutineCreate = Notification.Name("requestRoutineCreate")

    /// 가운데 FAB → 케미컬 추가 요청 — EquipmentListView 가 자체 추가 sheet 띄움
    static let requestEquipmentCreate = Notification.Name("requestEquipmentCreate")

    /// 가운데 FAB → 내차 추가 요청 — MyCarListView 가 자체 추가 sheet 띄움
    static let requestMyCarCreate = Notification.Name("requestMyCarCreate")

    /// 동일 탭 재탭 → 해당 화면이 스크롤을 최상단으로 이동
    /// userInfo["tab"]: Int — 0=피드, 2=루틴, 3=케미컬, 4=내차
    static let requestScrollToTop = Notification.Name("requestScrollToTop")
}

/// 세차지수 모델
struct WashIndex {
    let score: Int           // 0~100
    let message: String
    let recommendation: String
    let details: WashIndexDetails

    struct WashIndexDetails {
        let rainProbability: Int   // %
        let fineDust: Int          // μg/m³
        let humidity: Int          // %
        let temperature: Double    // °C
    }

    /// 점수 기반 등급
    var grade: String {
        switch score {
        case 80...100: return "최고"
        case 60..<80: return "좋음"
        case 40..<60: return "보통"
        case 20..<40: return "나쁨"
        default: return "최악"
        }
    }

    /// 점수 기반 색상 이름
    var colorName: String {
        switch score {
        case 80...100: return "tertiary"   // 그린
        case 60..<80: return "secondary"   // 블루
        case 40..<60: return "kakaoYellow"
        default: return "error"            // 레드
        }
    }

    /// 점수 기반 아이콘
    var iconName: String {
        switch score {
        case 80...100: return "sun.max.fill"
        case 60..<80: return "cloud.sun.fill"
        case 40..<60: return "cloud.fill"
        case 20..<40: return "cloud.drizzle.fill"
        default: return "cloud.heavyrain.fill"
        }
    }
}
