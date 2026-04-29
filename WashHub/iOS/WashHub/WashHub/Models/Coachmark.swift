import Foundation
import CoreGraphics

/// 코치마크 한 단계의 정보
///
/// - `anchorId == nil` 이면 전체 화면 dimmed 상태로 중앙에 말풍선만 표시 (welcome / outro)
/// - 그 외에는 `CoachmarkController.anchors[anchorId]` 의 frame 을 spotlight 으로 사용
struct CoachmarkStep: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let anchorId: String?
    let placement: CoachmarkTooltipPlacement

    init(
        id: String,
        title: String,
        message: String,
        anchorId: String? = nil,
        placement: CoachmarkTooltipPlacement = .auto
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.anchorId = anchorId
        self.placement = placement
    }
}

/// 말풍선 배치 — anchor 가 없으면 .center, auto 면 anchor 위치에 따라 자동
enum CoachmarkTooltipPlacement {
    case auto
    case topOf
    case bottomOf
    case center
}

/// HomeTabView 에 노출되는 코치마크 정의 — v1
///
/// 향후 단계가 추가되면 `CoachmarkVersion.homeV2` 등으로 새 버전 키를 만들고
/// UserDefaults 키를 갱신하여 한 번 더 노출시킨다.
enum CoachmarkVersion {
    static let homeV1 = "coachmark.home.v1.shown"
}

enum HomeCoachmark {
    /// 신규/둘러보기 사용자 첫 진입 시 보여지는 7단계 시나리오
    static let v1Steps: [CoachmarkStep] = [
        CoachmarkStep(
            id: "welcome",
            title: "비가 와도 세차",
            message: "WashHub 에 오신 것을 환영합니다.\n앞으로 30초 안에 핵심 기능을 안내해 드릴게요.",
            anchorId: nil,
            placement: .center
        ),
        CoachmarkStep(
            id: "tab.feed",
            title: "Before / After 피드",
            message: "세차 전후 사진을 비교하며 후기를 공유해보세요.",
            anchorId: CoachmarkAnchorID.tabFeed,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.routine",
            title: "내 세차 루틴",
            message: "단계별 루틴을 따라하며 깔끔하게 기록할 수 있어요.",
            anchorId: CoachmarkAnchorID.tabRoutine,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "fab.create",
            title: "피드 작성",
            message: "여기를 눌러 새 피드를 작성하거나 사진을 업로드 해보세요.",
            anchorId: CoachmarkAnchorID.fabCreate,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.equipment",
            title: "케미컬 / 장비",
            message: "내가 쓰는 케미컬과 장비 후기를 한곳에서 모아봐요.",
            anchorId: CoachmarkAnchorID.tabEquipment,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.mycar",
            title: "내 차 / 세차 기록",
            message: "내 차를 등록하면 세차 기록이 자동으로 쌓이고\n앱 아이콘이 세차 주기에 따라 바뀌어요.",
            anchorId: CoachmarkAnchorID.tabMyCar,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "outro",
            title: "준비 완료!",
            message: "이제 첫 세차 후기를 남겨볼까요?\n언제든 마이페이지 → 도움말에서 다시 볼 수 있어요.",
            anchorId: nil,
            placement: .center
        )
    ]
}

/// Anchor ID 상수 — 컴파일 타임에 오타 방지
enum CoachmarkAnchorID {
    static let tabFeed      = "tab.feed"
    static let tabRoutine   = "tab.routine"
    static let tabEquipment = "tab.equipment"
    static let tabMyCar     = "tab.mycar"
    static let fabCreate    = "fab.create"
}
