import SwiftUI

// MARK: - 팔로잉 피드 화면
struct FollowingFeedView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var followService = FollowService()
    @State private var feeds: [Feed] = []
    @State private var isLoading = true
    @State private var hasMore = true

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if isLoading && feeds.isEmpty {
                ProgressView()
                    .tint(.theme.secondary)
            } else if feeds.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .navigationTitle("팔로잉 피드")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadFeeds()
        }
        .refreshable {
            await loadFeeds()
        }
    }

    // MARK: - 빈 상태
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.theme.textDisabled)

            Text("팔로잉 피드가 비어있습니다")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            Text("다른 사용자를 팔로우하면\n여기에 활동이 표시됩니다")
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 피드 목록
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(feeds) { feed in
                    NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                        FollowingFeedCard(feed: feed)
                    }
                    .buttonStyle(.plain)
                }

                // 무한 스크롤
                if hasMore {
                    ProgressView()
                        .tint(.theme.secondary)
                        .padding()
                        .onAppear {
                            Task { await loadMore() }
                        }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 데이터 로드
    private func loadFeeds() async {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true
        feeds = await followService.loadFollowingFeed(userId: userId)
        hasMore = feeds.count >= 10
        isLoading = false
    }

    private func loadMore() async {
        guard let userId = authManager.currentUser?.id else { return }
        let newFeeds = await followService.loadFollowingFeed(userId: userId, offset: feeds.count)
        feeds.append(contentsOf: newFeeds)
        hasMore = newFeeds.count >= 10
    }
}

// MARK: - 팔로잉 피드 카드
struct FollowingFeedCard: View {
    let feed: Feed

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 작성자 정보
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: feed.profiles?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.theme.textDisabled)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.profiles?.displayName ?? "사용자")
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)
                    if !feed.createdAt.isEmpty {
                        Text(relativeTime(from: feed.createdAt))
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                    }
                }

                Spacer()
            }

            // 피드 내용
            if let content = feed.content, !content.isEmpty {
                Text(content)
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(3)
            }

            // 이미지 (썸네일)
            if let thumbnailUrl = feed.thumbnailUrl, !thumbnailUrl.isEmpty {
                AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.theme.surfaceContainer)
                            .frame(height: 200)
                    }
                }
            }

            // 좋아요/댓글 수
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 14))
                    Text("\(feed.likeCount)")
                        .font(.appSmall)
                }
                .foregroundColor(.theme.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14))
                    Text("\(feed.commentCount)")
                        .font(.appSmall)
                }
                .foregroundColor(.theme.textSecondary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // 상대 시간 계산
    private func relativeTime(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            // fallback: 기본 포맷
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return String(dateString.prefix(10))
            }
            return relativeTimeString(from: date)
        }
        return relativeTimeString(from: date)
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M월 d일"
        return dateFormatter.string(from: date)
    }
}
