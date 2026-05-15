import SwiftUI

// MARK: - 팔로워/팔로잉 목록 화면
struct FollowListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var followService = FollowService()

    let userId: String
    let userName: String
    @State var selectedTab: FollowTab = .followers

    enum FollowTab: String, CaseIterable {
        case followers = "팔로워"
        case followings = "팔로잉"
    }

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // 탭 선택
                tabSelector

                // 목록
                if followService.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.theme.secondary)
                    Spacer()
                } else {
                    listContent
                }
            }
        }
        .navigationTitle(userName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    // MARK: - 탭 선택기
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(FollowTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    Task { await loadData() }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.appBodyMedium)
                            .foregroundColor(selectedTab == tab ? .theme.textPrimary : .theme.textDisabled)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.theme.secondary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 목록 컨텐츠
    private var listContent: some View {
        let users = selectedTab == .followers ? followService.followers : followService.followings

        return Group {
            if users.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users) { user in
                            FollowUserRow(
                                user: user,
                                isFollowing: followService.followingIds.contains(user.id),
                                isMyself: user.id == authManager.currentUser?.id,
                                onToggleFollow: {
                                    Task {
                                        guard let myId = authManager.currentUser?.id else { return }
                                        let success = await followService.toggleFollow(myId: myId, targetId: user.id)
                                        if success {
                                            // followingIds 및 목록 갱신
                                            await loadData()
                                            await authManager.loadProfile(userId: myId)
                                        }
                                    }
                                }
                            )
                        }

                        // 더 보기 (pageSize 단위로 로드됐으면 다음 페이지 있을 수 있음)
                        if users.count >= 20 && users.count % 20 == 0 && !followService.isLoading {
                            ProgressView()
                                .tint(.theme.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await loadMore() }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 빈 상태
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: selectedTab == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.theme.textDisabled)
            Text(selectedTab == .followers ? "아직 팔로워가 없습니다" : "아직 팔로잉한 사용자가 없습니다")
                .font(.appBody)
                .foregroundColor(.theme.textDisabled)
            Spacer()
        }
    }

    // MARK: - 데이터 로드
    private func loadData() async {
        guard let myId = authManager.currentUser?.id else { return }
        await followService.loadFollowingIds(userId: myId)

        switch selectedTab {
        case .followers:
            await followService.loadFollowers(userId: userId)
        case .followings:
            await followService.loadFollowings(userId: userId)
        }
    }

    private func loadMore() async {
        let offset = selectedTab == .followers ? followService.followers.count : followService.followings.count
        switch selectedTab {
        case .followers:
            await followService.loadFollowers(userId: userId, offset: offset)
        case .followings:
            await followService.loadFollowings(userId: userId, offset: offset)
        }
    }
}

// MARK: - 팔로우 사용자 행
struct FollowUserRow: View {
    let user: FollowUser
    let isFollowing: Bool
    let isMyself: Bool
    let onToggleFollow: () -> Void
    @State private var isLoadingFollow = false

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.theme.textDisabled)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            // 사용자 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 팔로우 버튼 (자기 자신이면 숨김, 탈퇴자에게는 비활성)
            if !isMyself && !user.isDeleted {
                FollowButton(
                    isFollowing: isFollowing,
                    isLoading: isLoadingFollow,
                    action: {
                        isLoadingFollow = true
                        onToggleFollow()
                        // 짧은 지연 후 로딩 해제
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isLoadingFollow = false
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
