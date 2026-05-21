import SwiftUI

/// 테마 선택 화면 (설정 → 테마 변경)
///
/// 4개 파스텔 테마를 카드로 보여주고, 탭하면 즉시 적용한다.
/// 적용 시 `ThemeManager.current` 가 바뀌고 앱 루트의 `.id` 가 갱신되어
/// 뷰 트리가 새 테마로 리빌드된다.
struct ThemeSelectionView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("기분에 맞게 앱 분위기를 바꿀 수 있어요")
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        VStack(spacing: 12) {
                            ForEach(AppTheme.allCases) { theme in
                                themeCard(theme)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        // 내비게이션 바를 숨겨도 가장자리 스와이프 뒤로가기가 동작하도록
        .enableSwipeBackGesture()
    }

    // MARK: - 헤더
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.theme.textPrimary)
            }
            Text("테마를 골라보세요")
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.theme.surface.ignoresSafeArea(edges: .top))
    }

    // MARK: - 테마 카드
    private func themeCard(_ theme: AppTheme) -> some View {
        let palette = theme.colors
        let isSelected = themeManager.current == theme
        return Button {
            themeManager.select(theme)
        } label: {
            HStack(spacing: 16) {
                miniPreview(palette)

                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.nameKo)
                        .font(.appBodyBold)
                        .foregroundColor(.theme.textPrimary)
                    Text(theme.nameEn)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                    Text(theme.mood)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .theme.secondary : .theme.outline)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.theme.surfaceLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.theme.accent : Color.theme.outlineVariant,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 미니 프리뷰 — 해당 테마의 surface · primary · accent 색을 직접 보여준다.
    /// (적용 전 테마의 색을 보여줘야 하므로 이 컴포넌트만 특정 테마 색을 직접 참조)
    private func miniPreview(_ p: ColorTheme) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(p.surface)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(p.primary)
                    .frame(width: 36, height: 10)
                HStack(spacing: 5) {
                    Circle()
                        .fill(p.accent)
                        .frame(width: 13, height: 13)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(p.surfaceContainer)
                        .frame(width: 22, height: 9)
                }
            }
        }
        .frame(width: 76, height: 66)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.theme.outlineVariant, lineWidth: 1)
        )
    }
}
