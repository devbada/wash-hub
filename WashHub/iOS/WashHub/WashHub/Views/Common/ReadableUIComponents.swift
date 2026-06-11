import SwiftUI

// TODO-minam: Dynamic Type를 Extra Extra Large로 올려 헤더와 목록의 줄바꿈을 확인해 주세요.

/// 메인 탭에서 사용하는 공통 헤더.
struct WashHubHeader<LeadingContent: View, TrailingContent: View>: View {
    let title: String
    private let leadingContent: LeadingContent
    private let trailingContent: TrailingContent

    init(
        title: String,
        @ViewBuilder leading: () -> LeadingContent,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.title = title
        self.leadingContent = leading()
        self.trailingContent = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leadingContent
                .frame(minWidth: 44, minHeight: 44)

            Text(title)
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            trailingContent
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.theme.surface)
    }
}

/// 설정, 메뉴, 단순 정보를 표시하는 공통 행.
struct WashHubListRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var showsDisclosureIndicator: Bool = true
    var tint: Color = Color.theme.textPrimary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)

            Text(title)
                .font(.appBody)
                .foregroundColor(.theme.textPrimary)

            Spacer(minLength: 12)

            if let detail {
                Text(detail)
                    .font(.appCaption)
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(1)
            }

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.theme.textDisabled)
            }
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// 화면당 하나만 사용하는 핵심 정보 카드.
struct WashHubHeroCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .foregroundColor(.theme.onPrimary)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
