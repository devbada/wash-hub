import SwiftUI

/// 사용자 프로필 아바타 공용 컴포넌트
///
/// - **공식계정(isOfficial == true)**: avatar_url 무관하게 항상 WashHub 로고 (`WashStageJustWashed`) 표시
/// - **일반 사용자**: avatar_url 이 유효하면 AsyncImage, 그 외에는 SF Symbol fallback
///
/// Storage 에 공식계정 로고를 별도 업로드하지 않아도 클라이언트 측에서 자동 표시되어
/// 운영 변경/이미지 유실에 영향받지 않는다.
///
/// 사용 예:
/// ```swift
/// ProfileAvatar(
///     avatarUrl: profile?.avatarUrl,
///     isOfficial: profile?.isOfficialAccount ?? false,
///     size: 36
/// )
/// ```
struct ProfileAvatar: View {
    let avatarUrl: String?
    let isOfficial: Bool
    var size: CGFloat = 36

    var body: some View {
        Group {
            if isOfficial {
                officialLogo
            } else if let urlString = avatarUrl,
                      let url = URL(string: urlString),
                      let scheme = url.scheme,
                      scheme.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        placeholder
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    /// 공식계정 — WashHub 로고 (스플래시와 동일 ImageSet 재사용)
    private var officialLogo: some View {
        Image("WashStageJustWashed")
            .resizable()
            .scaledToFill()
            .background(Color.white)
    }

    /// avatar_url 없거나 로드 실패 — SF Symbol fallback
    private var placeholder: some View {
        ZStack {
            Color.theme.surfaceHigh
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(.theme.textDisabled)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ProfileAvatar(avatarUrl: nil, isOfficial: true, size: 48)
        ProfileAvatar(avatarUrl: "https://example.com/avatar.jpg", isOfficial: false, size: 48)
        ProfileAvatar(avatarUrl: nil, isOfficial: false, size: 48)
    }
    .padding(40)
    .background(Color.theme.surface)
}
