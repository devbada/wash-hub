import SwiftUI

// MARK: - 차단 사용자 목록 관리
struct BlockedUsersListView: View {
    @ObservedObject private var blockService = BlockService.shared
    @State private var showUnblockConfirm = false
    @State private var targetUser: BlockedUser?

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if blockService.isLoading {
                ProgressView()
                    .tint(.theme.secondary)
            } else if blockService.blockedUsers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(blockService.blockedUsers) { user in
                            blockedUserRow(user)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("차단 관리")
        .navigationBarTitleDisplayMode(.inline)
        .alert("차단 해제", isPresented: $showUnblockConfirm) {
            Button("취소", role: .cancel) {
                targetUser = nil
            }
            Button("해제", role: .destructive) {
                guard let user = targetUser else { return }
                Task {
                    try? await blockService.unblockUser(blockedId: user.blockedId)
                }
                targetUser = nil
            }
        } message: {
            if let user = targetUser {
                Text("\(user.profiles?.displayName ?? "이 사용자")의 차단을 해제하시겠습니까?\n해제 후 해당 사용자의 콘텐츠가 다시 보입니다.")
            }
        }
        .task {
            await blockService.loadBlockedUsers()
        }
    }

    // MARK: - 빈 상태
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.theme.textDisabled)
            Text("차단한 사용자가 없습니다")
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
        }
    }

    // MARK: - 차단 사용자 행
    private func blockedUserRow(_ user: BlockedUser) -> some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            AsyncImage(url: URL(string: user.profiles?.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.theme.surfaceHigh)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.theme.textDisabled)
                        )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            // 사용자 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(user.profiles?.displayName ?? "사용자")
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)

                if let reason = user.reason, !reason.isEmpty {
                    Text("사유: \(reason)")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                        .lineLimit(1)
                }

                Text("차단일: \(String(user.createdAt.prefix(10)))")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            Spacer()

            // 차단 해제 버튼
            Button(action: {
                targetUser = user
                showUnblockConfirm = true
            }) {
                Text("해제")
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.error)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.theme.error.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .cardStyle()
    }
}
