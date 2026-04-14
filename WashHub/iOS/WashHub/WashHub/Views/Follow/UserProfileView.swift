import SwiftUI
import Supabase

// MARK: - 다른 사용자 프로필 화면
struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var followService = FollowService()
    @StateObject private var badgeService = BadgeService()

    let userId: String
    @State private var profile: Profile?
    @State private var userFeeds: [Feed] = []
    @State private var isFollowing = false
    @State private var isLoadingFollow = false
    @State private var showFollowList = false
    @State private var followListTab: FollowListView.FollowTab = .followers
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false
    @ObservedObject private var blockService = BlockService.shared

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if let profile = profile {
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader(profile)
                        statsSection(profile)
                        badgeSection
                        feedSection
                    }
                    .padding(16)
                }
            } else {
                ProgressView()
                    .tint(.theme.secondary)
            }
        }
        .navigationTitle(profile?.displayName ?? "프로필")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showFollowList) {
            FollowListView(
                userId: userId,
                userName: profile?.displayName ?? "사용자",
                selectedTab: followListTab
            )
            .environmentObject(authManager)
        }
        .toolbar {
            // 타인 프로필에서 신고/차단 메뉴
            if userId != authManager.currentUser?.id && !authManager.isGuest {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showReportSheet = true }) {
                            Label("사용자 신고", systemImage: "exclamationmark.triangle")
                        }
                        Button(role: .destructive, action: { showBlockConfirm = true }) {
                            Label("사용자 차단", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.theme.textSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(
                targetType: .user,
                targetId: userId,
                onReported: nil
            )
        }
        .alert("사용자 차단", isPresented: $showBlockConfirm) {
            Button("취소", role: .cancel) {}
            Button("차단", role: .destructive) {
                Task {
                    try? await blockService.blockUser(blockedId: userId)
                }
            }
        } message: {
            Text("\(profile?.displayName ?? "이 사용자")를 차단하시겠습니까?\n차단하면 해당 사용자의 피드와 댓글이 표시되지 않습니다.")
        }
        .task {
            await loadAll()
        }
    }

    // MARK: - 프로필 헤더
    private func profileHeader(_ profile: Profile) -> some View {
        VStack(spacing: 16) {
            // 프로필 이미지
            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.theme.textDisabled)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            // 닉네임 + 타이틀 뱃지
            VStack(spacing: 6) {
                Text(profile.displayName)
                    .font(.appHeadline2)
                    .foregroundColor(.theme.textPrimary)

                // 대표 타이틀 뱃지
                if let titleBadgeId = profile.titleBadgeId,
                   let badge = badgeService.allBadges.first(where: { $0.id == titleBadgeId }) {
                    HStack(spacing: 4) {
                        Image(systemName: badge.iconName)
                            .font(.system(size: 10))
                        Text(badge.name)
                            .font(.appSmall)
                    }
                    .foregroundColor(.theme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.theme.secondary.opacity(0.15))
                    )
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // 팔로우 버튼 (자기 프로필이 아닐 때)
            if userId != authManager.currentUser?.id {
                FollowButton(
                    isFollowing: isFollowing,
                    isLoading: isLoadingFollow,
                    action: {
                        Task { await toggleFollow() }
                    }
                )
            }
        }
    }

    // MARK: - 통계 섹션
    private func statsSection(_ profile: Profile) -> some View {
        HStack(spacing: 0) {
            statItem(count: profile.followerCount ?? 0, label: "팔로워") {
                followListTab = .followers
                showFollowList = true
            }
            Divider()
                .frame(height: 30)
                .background(Color.theme.surfaceContainer)
            statItem(count: profile.followingCount ?? 0, label: "팔로잉") {
                followListTab = .followings
                showFollowList = true
            }
            Divider()
                .frame(height: 30)
                .background(Color.theme.surfaceContainer)
            statItem(count: profile.washCount ?? 0, label: "세차") { }
            Divider()
                .frame(height: 30)
                .background(Color.theme.surfaceContainer)
            statItem(count: profile.carCount ?? 0, label: "차량") { }
        }
        .padding(.vertical, 12)
        .cardStyle()
    }

    private func statItem(count: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                Text(label)
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 뱃지 섹션
    private var badgeSection: some View {
        Group {
            if !badgeService.myBadges.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("뱃지")
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(badgeService.myBadges.prefix(6), id: \.badgeId) { ub in
                            if let badge = badgeService.allBadges.first(where: { $0.id == ub.badgeId }) {
                                BadgeGridItem(badge: badge, isUnlocked: true)
                            }
                        }
                    }
                }
                .padding(16)
                .cardStyle()
            }
        }
    }

    // MARK: - 피드 섹션
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활동")
                .font(.appBodyMedium)
                .foregroundColor(.theme.textPrimary)

            if userFeeds.isEmpty {
                Text("아직 활동이 없습니다")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(userFeeds) { feed in
                    NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                        UserFeedRow(feed: feed)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - 데이터 로드
    private func loadAll() async {
        // 프로필 로드
        do {
            let persistProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            profile = persistProfile
        } catch {
            print("User profile load error: \(error)")
        }

        // 팔로우 상태 확인
        if let myId = authManager.currentUser?.id {
            isFollowing = await followService.isFollowing(followerId: myId, followingId: userId)
        }

        // 뱃지 로드
        await badgeService.loadAllBadges()
        await badgeService.loadUserBadges(userId: userId)

        // 피드 로드
        userFeeds = await followService.loadUserFeed(userId: userId)
    }

    // MARK: - 팔로우 토글
    private func toggleFollow() async {
        guard let myId = authManager.currentUser?.id else { return }
        isLoadingFollow = true
        let success = await followService.toggleFollow(myId: myId, targetId: userId)
        if success {
            isFollowing.toggle()
            // 프로필 갱신 (카운터 반영)
            await loadAll()
            await authManager.loadProfile(userId: myId)
        }
        isLoadingFollow = false
    }
}

// MARK: - 사용자 피드 행
struct UserFeedRow: View {
    let feed: Feed

    var body: some View {
        HStack(spacing: 12) {
            // 피드 썸네일
            if let thumbnailUrl = feed.thumbnailUrl, !thumbnailUrl.isEmpty {
                AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.theme.surfaceContainer
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.title ?? "피드")
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                if let content = feed.content, !content.isEmpty {
                    Text(content)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(2)
                }

                Text(String(feed.createdAt.prefix(10)))
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(.vertical, 4)
    }
}
