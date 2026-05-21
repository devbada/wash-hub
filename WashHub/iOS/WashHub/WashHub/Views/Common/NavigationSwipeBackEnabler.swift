import SwiftUI
import UIKit

/// 내비게이션 바를 숨긴 푸시 화면에서도 iOS 기본 뒤로가기 스와이프(왼쪽 가장자리 → 오른쪽)가
/// 동작하도록 한다.
///
/// 배경: `.toolbar(.hidden, for: .navigationBar)` 로 내비게이션 바를 숨기면 UIKit 이
/// `interactivePopGestureRecognizer` 를 비활성화해 가장자리 스와이프 뒤로가기가 막힌다.
/// 이 헬퍼는 해당 제스처의 delegate 를 직접 지정해, 스택에 화면이 2개 이상 쌓여 있으면
/// 스와이프를 다시 허용한다.
struct NavigationSwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        ProxyViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 화면이 갱신될 때마다 delegate 재적용 — SwiftUI 가 제스처 delegate 를
        // 되돌려놓는 경우에 대비
        (uiViewController as? ProxyViewController)?.enableSwipeBack()
    }

    /// 자신이 속한 UINavigationController 를 찾아 스와이프 제스처를 활성화하는 프록시 VC
    final class ProxyViewController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableSwipeBack()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableSwipeBack()
        }

        /// 상위 UINavigationController 의 뒤로가기 스와이프 제스처를 다시 켠다
        func enableSwipeBack() {
            guard let nav = navigationController else { return }
            coordinator.navigationController = nav
            nav.interactivePopGestureRecognizer?.delegate = coordinator
            nav.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        /// 화면이 2개 이상 쌓여 있을 때만 스와이프 뒤로가기 허용 (루트에서는 비활성)
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

extension View {
    /// 내비게이션 바를 숨긴 화면에서도 가장자리 스와이프 뒤로가기가 동작하도록 활성화한다.
    func enableSwipeBackGesture() -> some View {
        background(NavigationSwipeBackEnabler())
    }
}
