import SwiftUI

/// 화면 하단에서 슬라이드 업 되는 액션 카드
///
/// - 1 primary + 1 cancel (예: "사진 찍기" / "건너뛰기")
/// - 1 primary + 1 secondary + 1 cancel (예: "앨범에서 선택" / "카메라로 촬영" / "취소")
///
/// 사용 시: `BottomSheetOverlay` 안에서 호출하면 dimmed 배경 + 애니메이션이 자동 적용됨.
/// 단독으로 쓸 때는 호출 측에서 ZStack/animation 직접 관리.
///
/// iOS 15 호환 — `presentationDetents` 미사용
struct BottomActionCard: View {
    let title: String
    let message: String
    let primaryLabel: String
    let primaryAction: () -> Void
    /// secondary action — nil 이면 primary + cancel 두 개 버튼만 노출
    var secondaryLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    let cancelLabel: String
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            if !message.isEmpty {
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                Button(action: primaryAction) {
                    Text(primaryLabel).primaryButtonStyle()
                }
                if let secondaryLabel = secondaryLabel, let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryLabel).primaryButtonStyle()
                    }
                }
                Button(action: cancelAction) {
                    Text(cancelLabel).secondaryButtonStyle()
                }
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.surfaceLowest)
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -6)
    }
}

/// 하단 시트 오버레이 — dimmed 배경 + 슬라이드 인 애니메이션 + 배경 탭으로 dismiss
///
/// 사용:
/// ```
/// .overlay(alignment: .bottom) {
///     BottomSheetOverlay(isPresented: $show, onBackgroundTap: { ... }) {
///         BottomActionCard(...)
///     }
/// }
/// ```
struct BottomSheetOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    /// 배경 탭 시 동작 (기본: isPresented=false)
    var onBackgroundTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        if let handler = onBackgroundTap {
                            handler()
                        } else {
                            isPresented = false
                        }
                    }

                content()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
    }
}
