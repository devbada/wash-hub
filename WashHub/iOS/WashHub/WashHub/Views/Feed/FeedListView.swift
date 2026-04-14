import SwiftUI

struct FeedListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @ObservedObject private var blockService = BlockService.shared
    @State private var currentOffset = 0
    @State private var showLoginAlert = false
    @State private var loadId = UUID()
    @State private var navigatedFeedId: String?

    /// 차단 사용자 필터링된 피드 목록
    private var filteredFeeds: [Feed] {
        feedService.feeds.filter { !blockService.isBlocked($0.userId) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 커스텀 헤더 (navigationBar 대체)
                    HStack(alignment: .center) {
                        Text("WashHub")
                            .font(.headline(24))
                            .foregroundColor(.theme.secondary)

                        Spacer()

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
                                        if feed.id == filteredFeeds.last?.id {
                                            currentOffset += 10
                                            Task {
                                                await feedService.loadFeeds(offset: currentOffset)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .refreshable {
                        currentOffset = 0
                        await feedService.loadFeeds()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // 프로그래밍 방식 네비게이션 — iPad에서 인라인 NavigationLink 터치 이슈 우회
            .background(
                NavigationLink(
                    destination: Group {
                        if let feedId = navigatedFeedId {
                            FeedDetailView(feedId: feedId)
                        }
                    },
                    isActive: Binding(
                        get: { navigatedFeedId != nil },
                        set: { if !$0 { navigatedFeedId = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") {
                authManager.exitGuestMode()
            }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("마이페이지는 로그인 후 이용할 수 있습니다.")
        }
        .task(id: loadId) {
            currentOffset = 0
            await blockService.loadBlockedIds()
            await feedService.loadFeeds()
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

                    Spacer()

                    Text(String(feed.createdAt.prefix(10)))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }

                // 제목
                if let title = feed.title, !title.isEmpty {
                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)
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
