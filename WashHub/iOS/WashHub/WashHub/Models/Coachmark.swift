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
    /// v2 IA 개편(P2-012)으로 탭 구조가 바뀌어 키를 bump — 기존 사용자에게 1회 재노출
    static let homeV1 = "coachmark.home.v2.shown"
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
            id: "tab.home",
            title: "홈",
            message: "오늘의 세차 지수와 바로가기, 피드 미리보기를\n홈에서 한눈에 볼 수 있어요.",
            anchorId: CoachmarkAnchorID.tabHome,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.carwash",
            title: "세차장",
            message: "근처 세차장을 지도에서 바로 찾아볼 수 있어요.",
            anchorId: CoachmarkAnchorID.tabCarWash,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "fab.create",
            title: "기록 남기기",
            message: "여기를 눌러 세차 사진과 후기를 남겨보세요.",
            anchorId: CoachmarkAnchorID.fabCreate,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.equipment",
            title: "세차용품",
            message: "샴푸·왁스 같은 세차용품과 루틴 가이드를 모아봤어요.",
            anchorId: CoachmarkAnchorID.tabEquipment,
            placement: .topOf
        ),
        CoachmarkStep(
            id: "tab.mycar",
            title: "내차",
            message: "내 차를 등록하면 세차 기록과 통계가 자동으로 쌓이고\n앱 아이콘도 세차 주기에 따라 바뀌어요.",
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
    static let tabHome      = "tab.home"
    static let tabCarWash   = "tab.carwash"
    static let tabEquipment = "tab.equipment"
    static let tabMyCar     = "tab.mycar"
    static let fabCreate    = "fab.create"
}
