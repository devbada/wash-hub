import SwiftUI

/// 코치마크 강조 대상 View 의 글로벌 좌표를 수집하는 PreferenceKey
///
/// 사용 예: 탭 버튼/FAB 등 강조하고 싶은 View 에 `.coachmarkAnchor(id:)` 를 부착하고,
/// HomeTabView 같은 부모에서 `.onPreferenceChange(CoachmarkAnchorKey.self)` 으로
/// 한 번에 받아서 `CoachmarkController.shared.registerAnchor` 로 전달한다.
struct CoachmarkAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        // 동일 ID 가 충돌하면 마지막 값(자식이 더 깊을수록 마지막)을 사용
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// 코치마크에서 강조 대상으로 사용할 글로벌 frame 을 수집
    /// - Parameter id: `CoachmarkAnchorID` 의 상수 사용 권장
    func coachmarkAnchor(_ id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: CoachmarkAnchorKey.self,
                        value: [id: proxy.frame(in: .global)]
                    )
            }
        )
    }

    /// 부모에서 한 번에 anchor 들을 controller 로 등록 — HomeTabView 루트에 부착
    func collectCoachmarkAnchors(_ controller: CoachmarkController) -> some View {
        onPreferenceChange(CoachmarkAnchorKey.self) { anchors in
            for (id, frame) in anchors {
                controller.registerAnchor(id, frame: frame)
            }
        }
    }
}
