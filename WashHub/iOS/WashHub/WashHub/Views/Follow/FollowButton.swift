import SwiftUI

struct FollowButton: View {
    let isFollowing: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(isFollowing ? .theme.textSecondary : .white)
                    .frame(width: 80, height: 32)
            } else {
                Text(isFollowing ? "팔로우 해제" : "팔로우")
                    .font(.appSmall)
                    .foregroundColor(isFollowing ? .theme.textSecondary : .theme.onAccent)
                    .frame(width: 80, height: 32)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFollowing ? Color.theme.surfaceHigh : Color.theme.accent)
        )
    }
}
