import SwiftUI

/// 피드 탭 NavigationStack 의 value-based destination 타입.
/// destination-based `NavigationLink(destination:)` 은 `NavigationStack(path:)` 와 자동 연동이
/// 보장되지 않아 `path` mutation 으로 pop 이 안 되는 케이스가 있어, 모든 push 를 value-based 로 처리.
enum FeedNavTarget: Hashable {
    case myPage
    case feedDetail(String)   // feed id
}

struct FeedListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @StateObject private var feedService = FeedService()
    @ObservedObject private var blockService = BlockService.shared
    @State private var showLoginAlert = false
    @State private var loadId = UUID()
    /// 더블탭 좋아요 시각 피드백 — 현재 큰 하트가 보이는 피드 ID
    @State private var heartAnimationFeedId: String?
    /// 스크롤 idle 감지용 — 일정 시간 추가 스크롤 없으면 탭바 자동 표시
    @State private var scrollIdleTask: Task<Void, Never>?
    /// 현재 스크롤 contentOffset.y — 같은 탭 재탭 시 조건부 scrollTo 판단용
    @State private var currentScrollY: CGFloat = 0
    /// scrollTo 발동 임계값 — 이미 최상단 근처면 sticky toggle 부수 효과 회피
    private let scrollToTopThreshold: CGFloat = 200
    @ObservedObject private var notificationService = NotificationService.shared

    /// 차단 사용자 필터링된 피드 목록
    private var filteredFeeds: [Feed] {
        feedService.feeds.filter { !blockService.isBlocked($0.userId) }
    }

    /// 둘러보기(게스트) 모드는 최신 5개만 미리 보여주고 가입 유도
    private var guestPeekLimit: Int? {
        authManager.isGuest ? 5 : nil
    }

    var body: some View {
        NavigationStack(path: $navCoordinator.feedPath) {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 커스텀 헤더 (navigationBar 대체) — 스크롤 다운 시 자동 숨김
                    HStack(alignment: .center) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("WashHub")
                                .font(.headline(24))
                                .foregroundColor(.theme.secondary)
                            BetaBadge()
                        }

                        Spacer()

                        NavigationLink(destination: SearchView().environmentObject(authManager)) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.theme.textSecondary)
                        }
                        .padding(.trailing, 4)

                        Button(action: { loadId = UUID() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(feedService.isLoading ? .theme.textDisabled : .theme.textSecondary)
                        }
                        .disabled(feedService.isLoading)
                        .padding(.trailing, 4)

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
                            // value-based — NavigationCoordinator.feedPath 로 pop 가능
                            NavigationLink(value: FeedNavTarget.myPage) {
                                profileAvatarView
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    // 헤더와 첫 콘텐츠(세차지수 카드) 사이를 의도된 spacing 으로 안정화.
                    // NavigationStack 의 reserved 영역이 첫 진입/재탭 시 가변적으로 잡히지만,
                    // 명시적 padding 으로 시각 차이를 최소화 + 의도된 디자인처럼 인지되도록.
                    .padding(.bottom, 16)
                    // 헤더 자체에 background 적용 — 위쪽(status bar 영역) 까지 확장해 헤더가
                    // 단일 surface 영역으로 자연스럽게 인지되도록 (공백을 헤더 일부로 흡수)
                    .background(
                        Color.theme.surface
                            .ignoresSafeArea(edges: .top)
                    )

                    // 컨텐츠 — 세차지수 위젯은 피드 유무와 무관하게 항상 상단 노출
                    ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 스크롤 최상단 앵커 — 탭 더블탭 시 이 지점으로 이동
                            Color.clear.frame(height: 0).id("top")

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
                                    ZStack {
                                        FeedCard(
                                            feed: feed,
                                            isLikedByMe: feedService.likedFeedIds.contains(feed.id)
                                        )
                                        .contentShape(Rectangle())
                                        // 더블탭 → 좋아요 토글 (인스타 스타일)
                                        // count: 2 를 먼저 정의해야 SwiftUI 가 단탭 vs 더블탭 분리
                                        .onTapGesture(count: 2) {
                                            handleDoubleTapLike(feed: feed)
                                        }
                                        // 단탭 → 피드 상세 (value-based — feedPath 로 pop 가능)
                                        .onTapGesture(count: 1) {
                                            navCoordinator.feedPath.append(FeedNavTarget.feedDetail(feed.id))
                                        }

                                        // 더블탭 시각 피드백 — 큰 빨간 하트
                                        if heartAnimationFeedId == feed.id {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 90, weight: .bold))
                                                .foregroundColor(.white)
                                                .shadow(color: .theme.error.opacity(0.6), radius: 12)
                                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                                                .allowsHitTesting(false)
                                        }
                                    }
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

                            // 마지막 카드가 탭바에 가려지지 않도록 가상 빈 아이템 추가
                            BottomTabBarSpacer()
                        }
                        .padding(.bottom, 16)
                    }
                    .refreshable {
                        loadId = UUID()
                        // .refreshable spinner가 자연스럽게 닫히도록 약간 대기
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                    // NavigationStack 안의 ScrollView 가 자동으로 추가하는 top contentInset
                    // (navigation bar 자리만큼) 을 명시적 0 으로 override. iOS 17+ API.
                    // 이게 진짜 "헤더 아래 공백" 의 원인이었던 듯.
                    .contentMargins(.top, 0, for: .scrollContent)
                    // 가상 아이템 방식(BottomTabBarSpacer) 이전 padding/safeAreaInset 시도의
                    // 흔적인 `.frame(maxHeight: .infinity)` 제거 — NavigationStack 의 reserved
                    // 영역과 충돌해 상단에 공백 잡히는 원인 중 하나였음.
                    // ScrollView 는 부모 VStack 의 잔여 공간을 자동으로 차지함.
                    // 동일 탭(피드) 재탭 → 조건부로 스크롤 최상단.
                    // 사용자가 충분히 아래로 스크롤한 상태(임계값 이상)일 때만 scrollTo 호출.
                    // 이미 최상단 근처면 호출 안 함 — sticky toggle 부수 효과(콘텐츠 끌어올림) 회피.
                    .onChange(of: navCoordinator.scrollToTopTokens[0]) { _, _ in
                        guard currentScrollY > scrollToTopThreshold else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("top", anchor: .top)
                        }
                    }
                    // 스크롤 방향 감지 → 하단 탭바/FAB 자동 숨김/표시
                    // - 일정 위치(80pt) 이상에서 아래로 스크롤하면 숨김
                    // - 위로 스크롤하면 즉시 표시
                    // - 작은 변화(< 4pt) 는 무시 (탭/햅틱 등 의도치 않은 변동 차단)
                    // - 스크롤 멈춘 후 1.5초 동안 추가 스크롤 없으면 탭바 자동 복귀
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldValue, newValue in
                        // 조건부 scrollTo 판단용 — 현재 위치 추적
                        currentScrollY = newValue
                        let delta = newValue - oldValue
                        if abs(delta) < 4 { return }
                        let scrollingDown = delta > 0
                        if scrollingDown && newValue > 80 {
                            if !AppUIState.shared.scrollHidesBottom {
                                AppUIState.shared.scrollHidesBottom = true
                            }
                        } else if !scrollingDown {
                            if AppUIState.shared.scrollHidesBottom {
                                AppUIState.shared.scrollHidesBottom = false
                            }
                        }

                        // idle 타이머 — 스크롤 변화가 멈추면 1.5초 후 탭바 자동 표시
                        scrollIdleTask?.cancel()
                        scrollIdleTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            if !Task.isCancelled, AppUIState.shared.scrollHidesBottom {
                                AppUIState.shared.scrollHidesBottom = false
                            }
                        }
                    }
                    .onDisappear {
                        // 다른 화면(피드 상세 등) 진입 시 자동 숨김 해제 — 돌아왔을 때 일관된 시작점
                        scrollIdleTask?.cancel()
                        AppUIState.shared.scrollHidesBottom = false
                    }
                    } // ScrollViewReader 닫기
                }
            }
            // value-based 진입 — feedPath 로 push/pop (탭 재탭 시 pop-to-root 가능)
            .navigationDestination(for: FeedNavTarget.self) { target in
                switch target {
                case .myPage:
                    MyPageView()
                case .feedDetail(let feedId):
                    FeedDetailView(feedId: feedId)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            await feedService.loadFeeds(maxCount: guestPeekLimit)
            if !authManager.isGuest {
                await notificationService.fetchUnreadCount()
            }
        }
        .onChange(of: loadId) { _, _ in
            // loadId 변경 시 새로고침 (pull-to-refresh, 버튼, 알림 등)
            Task {
                await blockService.loadBlockedIds()
                await feedService.loadFeeds(forceRefresh: true, maxCount: guestPeekLimit)
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

    // MARK: - 더블탭 좋아요 (추가 전용)
    /// 인스타 스타일 — 카드 더블탭 시 좋아요 추가 + 큰 하트 애니메이션
    /// - 이미 좋아요 한 피드는 시각 피드백만 표시(귀여움 유지) + 서버 호출/해제 없음
    /// - 좋아요 해제는 피드 상세에서만 가능
    /// - 게스트는 로그인 alert
    private func handleDoubleTapLike(feed: Feed) {
        if authManager.isGuest {
            showLoginAlert = true
            return
        }

        // 시각 피드백은 항상 표시 (이미 좋아요 한 상태에서도 큰 하트 등장)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            heartAnimationFeedId = feed.id
        }
        let animationFeedId = feed.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            // 도중에 다른 카드 더블탭으로 바뀐 경우 무시
            if heartAnimationFeedId == animationFeedId {
                withAnimation(.easeOut(duration: 0.25)) {
                    heartAnimationFeedId = nil
                }
            }
        }

        // 이미 좋아요 한 피드는 서버 호출 안 함 (해제 방지)
        guard !feedService.likedFeedIds.contains(feed.id) else { return }

        // 좋아요 추가
        Task {
            do {
                _ = try await feedService.toggleLike(feedId: feed.id)
                // 카운터 동기화 — 잠깐 대기 후 단일 피드 갱신
                try? await Task.sleep(nanoseconds: 400_000_000)
                await feedService.refreshFeed(id: feed.id)
            } catch {
                print("Double-tap like error: \(error)")
            }
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
    /// 현재 사용자가 이 피드를 좋아요 했는지 — 빨간 하트로 표시할 때 true
    var isLikedByMe: Bool = false

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
                    ProfileAvatar(
                        avatarUrl: feed.profiles?.avatarUrl,
                        isOfficial: feed.profiles?.isOfficialAccount ?? false,
                        size: 28
                    )

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

                // 좋아요 / 댓글 — 내가 좋아요 한 피드는 빨간 하트로 강조
                HStack(spacing: 16) {
                    Label("\(feed.likeCount)", systemImage: isLikedByMe ? "heart.fill" : "heart")
                        .font(.appSmall)
                        .foregroundColor(isLikedByMe ? .theme.error : .theme.textSecondary)

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
