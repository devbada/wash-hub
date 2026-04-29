import SwiftUI

/// WashHub 공식 계정 배지 — `Profile.isOfficial == true` 인 사용자 옆에 노출
///
/// 사용 예: 작성자 닉네임 옆에 작게 표시
/// ```
/// HStack(spacing: 4) {
///     Text(profile.displayName)
///     OfficialBadge()
/// }
/// ```
struct OfficialBadge: View {
    /// 사이즈 (기본 12pt — 본문 inline 용)
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(.theme.secondary)
            .accessibilityLabel("공식 계정")
    }
}

#if DEBUG
struct OfficialBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("WashHub").font(.appBodyMedium)
                OfficialBadge()
            }
            HStack(spacing: 4) {
                Text("WashHub").font(.appHeadline2)
                OfficialBadge(size: 18)
            }
        }
        .padding()
    }
}
#endif
