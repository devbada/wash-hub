import SwiftUI

/// 코치마크 오버레이 — HomeTabView 의 ZStack 최상단에 부착
///
/// - 어둑한 배경(opacity 0.65) + 강조 영역만 컷아웃
/// - 강조 위/아래 자동 배치되는 말풍선
/// - 하단 진행 dot + Skip / Next 버튼
struct CoachmarkOverlay: View {
    @ObservedObject var controller: CoachmarkController

    /// 강조 영역 padding — 너무 타이트하면 답답해 보임
    private static let spotlightPadding: CGFloat = 12

    /// 말풍선 최대 너비 (가로 기준) — 기기 폭이 좁을 때만 작동
    private static let tooltipMaxWidth: CGFloat = 320

    var body: some View {
        ZStack {
            if controller.isActive, let step = controller.currentStep {
                GeometryReader { proxy in
                    let screen = proxy.size
                    let safeBottom = proxy.safeAreaInsets.bottom

                    ZStack {
                        // 1) 어둑한 배경 + 강조 영역 컷아웃
                        dimmedBackground(rect: controller.spotlightRect, in: screen)
                            .ignoresSafeArea()

                        // 2) 말풍선
                        tooltip(step: step, spotlight: controller.spotlightRect, screen: screen)

                        // 3) 하단 컨트롤 — Skip / 진행 dots / Next
                        controlBar
                            .padding(.horizontal, 24)
                            .padding(.bottom, safeBottom + 24)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .transition(.opacity)
                .zIndex(9_999)   // sheet/alert 외 최상단
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controller.currentIndex)
        .animation(.easeInOut(duration: 0.25), value: controller.isActive)
    }

    // MARK: - 배경 dim + 컷아웃

    /// 강조 영역만 투명하게 뚫린 배경
    @ViewBuilder
    private func dimmedBackground(rect: CGRect?, in screen: CGSize) -> some View {
        if let rect = rect {
            // even-odd fill rule 로 강조 영역만 컷아웃
            ZStack {
                Color.black.opacity(0.65)
                    .mask(
                        Rectangle()
                            .overlay(
                                spotlightShape(for: rect)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
            }
            .allowsHitTesting(true)
            .contentShape(Rectangle())
            .onTapGesture {
                // 배경 탭으로는 진행 안 함 (실수 방지) — Next 버튼 강제
            }
        } else {
            // anchor 없는 단계 — 전체 dim
            Color.black.opacity(0.65)
                .contentShape(Rectangle())
                .onTapGesture { }
        }
    }

    /// 강조 영역의 모양 — FAB 처럼 정사각형이면 원형, 그 외엔 둥근 사각형
    @ViewBuilder
    private func spotlightShape(for rect: CGRect) -> some View {
        let inflated = rect.insetBy(
            dx: -Self.spotlightPadding,
            dy: -Self.spotlightPadding
        )
        if abs(rect.width - rect.height) < 8 {
            Circle()
                .frame(width: inflated.width, height: inflated.height)
                .position(x: inflated.midX, y: inflated.midY)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .frame(width: inflated.width, height: inflated.height)
                .position(x: inflated.midX, y: inflated.midY)
        }
    }

    // MARK: - 말풍선

    @ViewBuilder
    private func tooltip(step: CoachmarkStep, spotlight: CGRect?, screen: CGSize) -> some View {
        let bubble = TooltipBubble(step: step)
            .frame(maxWidth: min(Self.tooltipMaxWidth, screen.width - 48))

        let position = tooltipPosition(spotlight: spotlight, screen: screen)
        bubble
            .position(x: position.x, y: position.y)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// 강조 영역의 위/아래 어디에 말풍선을 둘지 — 화면 절반 기준 자동 결정
    private func tooltipPosition(spotlight: CGRect?, screen: CGSize) -> CGPoint {
        guard let rect = spotlight else {
            // 가운데
            return CGPoint(x: screen.width / 2, y: screen.height / 2)
        }
        let bubbleHeightEstimate: CGFloat = 140
        let gap: CGFloat = 24
        let above = rect.minY - gap - bubbleHeightEstimate / 2
        let below = rect.maxY + gap + bubbleHeightEstimate / 2

        // 강조 영역이 화면 하단에 있으면 위쪽에, 상단에 있으면 아래쪽에 배치
        let preferAbove = rect.midY > screen.height / 2
        let y: CGFloat = preferAbove
            ? max(above, bubbleHeightEstimate / 2 + 32)
            : min(below, screen.height - bubbleHeightEstimate / 2 - 80)

        return CGPoint(x: screen.width / 2, y: y)
    }

    // MARK: - 컨트롤 바

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button(action: { controller.skip() }) {
                Text("건너뛰기")
                    .font(.appLabel)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }

            Spacer()

            // 진행 dots
            HStack(spacing: 6) {
                ForEach(controller.steps.indices, id: \.self) { idx in
                    Circle()
                        .fill(idx == controller.currentIndex
                              ? Color(red: 132/255, green: 204/255, blue: 22/255)  // Citrus
                              : Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            Button(action: { controller.next() }) {
                Text(isLastStep ? "시작하기" : "다음")
                    .font(.appBodyBold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 132/255, green: 204/255, blue: 22/255))  // Citrus
                    )
            }
        }
    }

    private var isLastStep: Bool {
        controller.currentIndex + 1 >= controller.steps.count
    }
}

// MARK: - 말풍선 본체

private struct TooltipBubble: View {
    let step: CoachmarkStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)
            Text(step.message)
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.theme.surfaceLowest)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
    }
}
