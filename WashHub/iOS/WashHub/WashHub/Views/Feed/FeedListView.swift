import SwiftUI

struct FeedListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @State private var currentOffset = 0
    @State private var showLoginAlert = false
    @State private var loadId = UUID()

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

                    // 컨텐츠
                    ZStack {
                        if feedService.isLoading && feedService.feeds.isEmpty {
                            ProgressView()
                                .tint(.theme.secondary)
                        } else if feedService.feeds.isEmpty {
                            emptyView
                        } else {
                            feedList
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .task(id: loadId) {
            currentOffset = 0
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

    // MARK: - 피드 리스트
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 세차지수 위젯
                WashIndexCard()
                    .padding(.bottom, 4)

                ForEach(feedService.feeds) { feed in
                    NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                        FeedCard(feed: feed)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // 마지막 아이템 도달 시 다음 페이지 로드
                        if feed.id == feedService.feeds.last?.id {
                            currentOffset += 10
                            Task {
                                await feedService.loadFeeds(offset: currentOffset)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            currentOffset = 0
            await feedService.loadFeeds()
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일
            AsyncImage(url: URL(string: feed.thumbnailUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    Rectangle()
                        .fill(Color.theme.surface)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.theme.textDisabled)
                        )
                case .failure:
                    Rectangle()
                        .fill(Color.theme.surface)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.theme.textDisabled)
                        )
                @unknown default:
                    Rectangle().fill(Color.theme.surface)
                }
            }
            .frame(height: 200)
            .clipped()

            // 정보 영역
            VStack(alignment: .leading, spacing: 8) {
                // 작성자
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
