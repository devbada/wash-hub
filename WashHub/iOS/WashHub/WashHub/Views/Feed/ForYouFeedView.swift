import SwiftUI

/// "For You" 추천 피드 화면.
///
/// 시각/인터랙션은 FeedListView 와 동일 — 같은 `FeedCard` 컴포넌트를 그대로 사용한다.
/// 차이점은 **데이터 소스**뿐: `for-you-feed` Edge Function 의 추천 결과를 `Feed` 로 변환해 표시한다.
/// (좋아요 동기화는 기존 `FeedService.syncLikedFeedIds` 를 재사용)
struct ForYouFeedView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @StateObject private var recommendationService = ForYouFeedService()
    @StateObject private var feedService = FeedService()   // 좋아요 동기화/토글용
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var blockService = BlockService.shared

    @State private var showLoginAlert = false
    /// 더블탭 좋아요 시각 피드백 — 현재 큰 하트가 보이는 피드 ID
    @State private var heartAnimationFeedId: String?

    /// 차단 사용자 제외 + Feed 형태로 변환
    private var feeds: [Feed] {
        recommendationService.items
            .filter { !blockService.isBlocked($0.authorId) }
            .map { $0.toFeed() }
    }

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if recommendationService.coldStart {
                    coldStartBanner
                }

                if let errorMessage = recommendationService.errorMessage, recommendationService.items.isEmpty {
                    errorState(message: errorMessage)
                } else if recommendationService.isLoading && recommendationService.items.isEmpty {
                    loadingState
                } else if feeds.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
        }
        .navigationTitle("추천 피드")
        .navigationBarTitleDisplayMode(.inline)
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") { authManager.exitGuestMode() }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("좋아요는 로그인 후 이용할 수 있습니다.")
        }
        .task {
            await initialLoad()
        }
        .refreshable {
            await reload()
        }
    }

    // MARK: - Header (sparkles + 결과 카운트)
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.theme.secondary)
            Text("나에게 맞춘 추천")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)
            Spacer()
            if let metrics = recommendationService.lastMetrics {
                Text("\(metrics.afterPostFilter)건")
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Cold start banner
    private var coldStartBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.theme.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("아직 추천이 더 정확하지 않아요")
                    .font(.appCaptionBold)
                    .foregroundColor(.theme.textPrimary)
                Text("내차 등록 · 세차 기록을 쌓으면 더 적합한 피드를 보여드려요.")
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.theme.surfaceLow)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Feed list (FeedListView 와 동일 패턴)
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(feeds) { feed in
                    ZStack {
                        FeedCard(
                            feed: feed,
                            isLikedByMe: feedService.likedFeedIds.contains(feed.id)
                        )
                        .contentShape(Rectangle())
                        // 더블탭 → 좋아요 토글 (인스타 스타일)
                        .onTapGesture(count: 2) {
                            handleDoubleTapLike(feed: feed)
                        }
                        // 단탭 → 상세 화면 (path-based push — FeedListView 와 동일)
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
                        // 무한 스크롤 — 마지막 카드 근처에서 다음 페이지 트리거
                        if let index = feeds.firstIndex(where: { $0.id == feed.id }),
                           index >= feeds.count - 3,
                           !recommendationService.isLoading,
                           recommendationService.hasMorePages {
                            Task { await recommendationService.loadNextPage(location: currentLocationPayload()) }
                        }
                    }
                }

                if recommendationService.isLoading && !recommendationService.items.isEmpty {
                    ProgressView()
                        .tint(.theme.secondary)
                        .padding(.vertical, 16)
                }

                // 마지막 카드가 탭바에 가려지지 않도록 가상 빈 아이템
                BottomTabBarSpacer()
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.theme.secondary)
            Text("추천을 준비하고 있어요…")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
                .padding(.top, 12)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.theme.textDisabled)
            Text("아직 추천할 피드가 없어요")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)
            Text("팔로우/즐겨찾기를 늘리면 더 풍부한 추천을 받을 수 있어요.")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.theme.error)
            Text(message)
                .font(.appBody)
                .foregroundColor(.theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await reload() }
            } label: {
                Text("다시 시도")
                    .font(.appLabel)
                    .foregroundColor(.theme.onPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theme.primary)
                    .cornerRadius(12)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func initialLoad() async {
        if locationManager.isAuthorized, locationManager.userLocation == nil {
            locationManager.requestLocation()
        }
        await recommendationService.loadFirstPage(location: currentLocationPayload())
        await syncLikesForCurrentItems()
    }

    private func reload() async {
        await recommendationService.loadFirstPage(location: currentLocationPayload(), forceRefresh: true)
        await syncLikesForCurrentItems()
    }

    private func currentLocationPayload() -> ForYouFeedRequestLocation? {
        guard let coord = locationManager.userLocation else { return nil }
        return ForYouFeedRequestLocation(
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }

    /// 추천 결과의 feed id 들에 대해 본인 좋아요 상태 일괄 동기화
    private func syncLikesForCurrentItems() async {
        let ids = recommendationService.items.map { $0.feedId }
        guard !ids.isEmpty else { return }
        await feedService.syncLikedFeedIds(for: ids)
    }

    /// FeedListView 와 동일한 더블탭 좋아요 처리
    private func handleDoubleTapLike(feed: Feed) {
        if authManager.isGuest {
            showLoginAlert = true
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            heartAnimationFeedId = feed.id
        }
        let animationFeedId = feed.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if heartAnimationFeedId == animationFeedId {
                withAnimation(.easeOut(duration: 0.25)) {
                    heartAnimationFeedId = nil
                }
            }
        }

        // 이미 좋아요 한 피드는 서버 호출 안 함 (해제 방지)
        guard !feedService.likedFeedIds.contains(feed.id) else { return }

        Task {
            do {
                _ = try await feedService.toggleLike(feedId: feed.id)
                // TODO-minam: 추천 응답의 likeCount 는 즉시 갱신 불가 — 다음 새로고침 시 반영.
                //             FeedService.refreshFeed 는 일반 피드 캐시만 갱신하므로 여기서 호출 X.
            } catch {
                print("⚠️ ForYouFeed double-tap like error: \(error)")
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ForYouFeedView()
            .environmentObject(AuthManager())
            .environmentObject(NavigationCoordinator())
    }
}
#endif
