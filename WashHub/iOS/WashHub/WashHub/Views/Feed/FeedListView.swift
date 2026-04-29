import SwiftUI

struct FeedListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @ObservedObject private var blockService = BlockService.shared
    @State private var showLoginAlert = false
    @State private var loadId = UUID()
    @State private var navigatedFeedId: String?
    @ObservedObject private var notificationService = NotificationService.shared

    /// 차단 사용자 필터링된 피드 목록
    private var filteredFeeds: [Feed] {
        feedService.feeds.filter { !blockService.isBlocked($0.userId) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 커스텀 헤더 (navigationBar 대체)
                    HStack(alignment: .center) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("WashHub")
                                .font(.headline(24))
                                .foregroundColor(.theme.secondary)
                            BetaBadge()
                        }

                        Spacer()

                        // 검색 버튼
                        NavigationLink(destination: SearchView().environmentObject(authManager)) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.theme.textSecondary)
                        }
                        .padding(.trailing, 4)

                        // 새로고침 버튼
                        Button(action: {
                            loadId = UUID()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(feedService.isLoading ? .theme.textDisabled : .theme.textSecondary)
                        }
                        .disabled(feedService.isLoading)
                        .padding(.trailing, 4)

                        // 알림 벨 아이콘
                        if !authManager.isGuest {
                            NavigationLink(destination: NotificationListView().environmentObject(authManager)) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.theme.textSecondary)

                                    if notificationService.unreadCount > 0 {
                                        Text(notificationService.unreadCount > 99 ? "99+" : "\(notificationService.unreadCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -6)
                                    }
                                }
                            }
                            .padding(.trailing, 8)
                        }

                        if authManager.isGuest {
                            Button(action: { showLoginAlert = true }) {
                                profileAvatarView
                            }
                        } else {
                            NavigationLink(destination: MyPageView()) {
                                profileAvatarView
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // 컨텐츠 — 세차지수 위젯은 피드 유무와 무관하게 항상 상단 노출
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 세차지수 위젯 (피드가 없어도 표시)
                            WashIndexCard()
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            if feedService.isLoading && feedService.feeds.isEmpty {
                                ProgressView()
                                    .tint(.theme.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if filteredFeeds.isEmpty {
                                emptyView
                                    .padding(.top, 20)
                            } else {
                                ForEach(filteredFeeds) { feed in
                                    Button {
                                        navigatedFeedId = feed.id
                                    } label: {
                                        FeedCard(feed: feed)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                    .onAppear {
                                        // 무한 스크롤: 마지막 아이템 근처에서 다음 페이지 로드
                                        let items = filteredFeeds
                                        if let index = items.firstIndex(where: { $0.id == feed.id }),
                                           index >= items.count - 3,
                                           !feedService.isLoading,
                                           feedService.hasMorePages {
                                            let nextOffset = feedService.feeds.count
                                            Task {
                                                await feedService.loadFeeds(offset: nextOffset)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .refreshable {
                        loadId = UUID()
                        // .refreshable spinner가 자연스럽게 닫히도록 약간 대기
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // 프로그래밍 방식 네비게이션 — iPad에서 인라인 NavigationLink 터치 이슈 우회
            .navigationDestination(isPresented: Binding(
                get: { navigatedFeedId != nil },
                set: { if !$0 { navigatedFeedId = nil } }
            )) {
                if let feedId = navigatedFeedId {
                    FeedDetailView(feedId: feedId)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") {
                authManager.exitGuestMode()
            }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("마이페이지는 로그인 후 이용할 수 있습니다.")
        }
        .task {
            // 최초 로드
            await blockService.loadBlockedIds()
            await feedService.loadFeeds()
            if !authManager.isGuest {
                await notificationService.fetchUnreadCount()
            }
        }
        .onChange(of: loadId) { _, _ in
            // loadId 변경 시 새로고침 (pull-to-refresh, 버튼, 알림 등)
            Task {
                await blockService.loadBlockedIds()
                await feedService.loadFeeds(forceRefresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedCreated)) { _ in
            loadId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedCountChanged)) { notification in
            // 좋아요/댓글 카운터 변경: 해당 피드만 부분 갱신, feedId 없으면 전체 리로드
            if let feedId = notification.userInfo?["feedId"] as? String {
                Task {
                    await feedService.refreshFeed(id: feedId)
                }
            } else {
                loadId = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .blockStatusChanged)) { _ in
            // 차단/해제 시 피드 전체 리로드 — AsyncImage 캐시 갱신
            loadId = UUID()
        }
    }

    // MARK: - 프로필 아바타 (우측 상단)
    private var profileAvatarView: some View {
        let avatarUrl = authManager.currentUser?.avatarUrl ?? ""
        return Group {
            if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        Circle().fill(Color.theme.surfaceHigh)
                            .overlay(ProgressView().scaleEffect(0.6))
                    default:
                        fallbackAvatar
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.theme.secondary.opacity(0.35), lineWidth: 1.5)
                )
            } else {
                fallbackAvatar
            }
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.theme.surfaceHigh)
                .frame(width: 36, height: 36)
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.theme.textSecondary)
        }
        .overlay(
            Circle()
                .stroke(Color.theme.border, lineWidth: 1)
        )
    }

    // MARK: - 빈 화면
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.circle")
                .font(.system(size: 60))
                .foregroundColor(.theme.textDisabled)

            Text("아직 피드가 없습니다")
                .font(.appHeadline3)
                .foregroundColor(.theme.textSecondary)

            Text("첫 번째 세차 기록을 공유해보세요!")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
    }
}

// MARK: - 피드 카드
struct FeedCard: View {
    let feed: Feed

    /// 썸네일이 유효한 URL 인지 판단
    private var hasValidThumbnail: Bool {
        guard let raw = feed.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme,
              scheme.hasPrefix("http") else {
            return false
        }
        return true
    }

    /// 썸네일 뷰 — 유효한 URL 이 있을 때만 AsyncImage 를 사용하고, 그 외에는 정적 placeholder
    @ViewBuilder
    private var thumbnailView: some View {
        if hasValidThumbnail, let url = URL(string: feed.thumbnailUrl!) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    Rectangle()
                        .fill(Color.theme.surface)
                        .overlay(
                            ProgressView()
                                .tint(.theme.textDisabled)
                        )
                case .failure(let error):
                    // 로드 실패 시 디버그 출력 후 첫 번째 feed_image로 fallback
                    let _ = print("Thumbnail load failed: \(error), url: \(url)")
                    thumbnailPlaceholder
                @unknown default:
                    thumbnailPlaceholder
                }
            }
        } else {
            let _ = print("No valid thumbnail for feed \(feed.id): thumbnailUrl=\(feed.thumbnailUrl ?? "nil")")
            thumbnailPlaceholder
        }
    }

    /// thumbnail_url 이 없을 때 사용하는 정적 placeholder
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.theme.surface)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.theme.textDisabled)
                    Text("이미지 없음")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일 — thumbnail_url 이 nil/empty 또는 잘못된 URL 이면 placeholder 표시
            thumbnailView
                .frame(height: 200)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    // 썸네일이 Before/After 중 어떤 것인지 배지로 노출 (legacy 피드는 미표시)
                    if let badge = feed.thumbnailBadgeLabel {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(6)
                            .padding(8)
                    }
                }

            // 정보 영역
            VStack(alignment: .leading, spacing: 8) {
                // 작성자 — avatar_url 이 유효하지 않으면 placeholder
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: feed.profiles?.avatarUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(Color.theme.surface)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                    Text(feed.profiles?.displayName ?? "사용자")
                        .font(.appCaptionMedium)
                        .foregroundColor(.theme.textPrimary)

                    // 협찬 뱃지
                    if feed.isSponsored {
                        HStack(spacing: 3) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 9))
                            Text(feed.sponsorName ?? "협찬")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color(red: 255/255, green: 176/255, blue: 59/255))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 255/255, green: 176/255, blue: 59/255).opacity(0.15))
                        .cornerRadius(4)
                    }

                    Spacer()

                    Text(String(feed.createdAt.prefix(10)))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }

                // 본문 발췌 (사진 중심 — 본문은 짧은 미리보기로만 표시)
                if let content = feed.content, !content.isEmpty {
                    Text(content)
                        .font(.appBody)
                        .foregroundColor(.theme.textPrimary)
                        .lineLimit(2)
                }

                // 해시태그 (있을 때만, 한 줄 max)
                if !feed.hashtags.isEmpty {
                    Text(feed.hashtags.joined(separator: " "))
                        .font(.appSmall)
                        .foregroundColor(.theme.secondary)
                        .lineLimit(1)
                }

                // 차량 정보
                if let car = feed.myCars {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 10))
                        Text(car.carModel)
                            .font(.appSmall)
                        if let color = car.carColor {
                            Text("· \(color)")
                                .font(.appSmall)
                        }
                    }
                    .foregroundColor(.theme.tertiary)
                }

                // 좋아요 / 댓글
                HStack(spacing: 16) {
                    Label("\(feed.likeCount)", systemImage: "heart.fill")
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)

                    Label("\(feed.commentCount)", systemImage: "bubble.right.fill")
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .padding(12)
        }
        .cardStyle()
    }
}
