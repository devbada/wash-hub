import SwiftUI

/// 내 피드 / 좋아요한 피드 풀스크린 페이지네이션 화면
///
/// - 모드: `.myFeeds` 또는 `.likedFeeds`
/// - 무한 스크롤 + pull-to-refresh
/// - 마이페이지의 미리보기에서 "모두 보기" 진입 시 사용
struct MyFeedListPageView: View {
    enum Mode {
        case myFeeds
        case likedFeeds

        var title: String {
            switch self {
            case .myFeeds:    return "내 피드"
            case .likedFeeds: return "좋아요한 피드"
            }
        }

        var emptyMessage: String {
            switch self {
            case .myFeeds:    return "작성한 피드가 없습니다"
            case .likedFeeds: return "좋아요한 피드가 없습니다"
            }
        }
    }

    let mode: Mode
    let userId: String

    @StateObject private var feedService = FeedService()
    @State private var feeds: [Feed] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var loadId = UUID()

    /// 한 번에 가져올 개수
    private let pageSize = 20

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if isLoading && feeds.isEmpty {
                ProgressView().tint(.theme.secondary)
            } else if feeds.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(feeds) { feed in
                            NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                                feedRow(feed)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                // 무한 스크롤 — 마지막 3개 근처에서 다음 페이지
                                if let idx = feeds.firstIndex(where: { $0.id == feed.id }),
                                   idx >= feeds.count - 3,
                                   !isLoading,
                                   hasMore {
                                    Task { await loadNextPage() }
                                }
                            }
                        }

                        // 마지막 페이지 도달 시 안내
                        if !hasMore && !feeds.isEmpty {
                            Text("· 모든 피드를 불러왔습니다 ·")
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                                .padding(.vertical, 16)
                        } else if isLoading {
                            ProgressView()
                                .tint(.theme.secondary)
                                .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .refreshable {
                    loadId = UUID()
                    await loadFirstPage()
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadId) {
            await loadFirstPage()
        }
    }

    // MARK: - 빈 상태

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: mode == .myFeeds ? "photo.stack" : "heart")
                .font(.system(size: 48))
                .foregroundColor(.theme.textDisabled)
            Text(mode.emptyMessage)
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
    }

    // MARK: - 행 컴포넌트 (마이페이지 미리보기와 동일 디자인)

    private func feedRow(_ feed: Feed) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: feed.thumbnailUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 6).fill(Color.theme.surface)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.content?.prefix(40).description ?? "세차 피드")
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let car = feed.myCars {
                        Text(car.carModel)
                            .font(.appSmall)
                            .foregroundColor(.theme.tertiary)
                    }
                    Text(String(feed.createdAt.prefix(10)))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Label("\(feed.likeCount)", systemImage: "heart.fill")
                Label("\(feed.commentCount)", systemImage: "bubble.right.fill")
            }
            .font(.system(size: 10))
            .foregroundColor(.theme.textDisabled)
        }
        .padding(10)
        .cardStyle()
    }

    // MARK: - 로딩

    private func loadFirstPage() async {
        isLoading = true
        let firstPage = await fetch(offset: 0)
        feeds = firstPage
        hasMore = firstPage.count >= pageSize
        isLoading = false
    }

    private func loadNextPage() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        let nextPage = await fetch(offset: feeds.count)
        // 중복 제거 (race condition 안전)
        let existingIds = Set(feeds.map { $0.id })
        let newFeeds = nextPage.filter { !existingIds.contains($0.id) }
        feeds.append(contentsOf: newFeeds)
        if nextPage.count < pageSize {
            hasMore = false
        }
        isLoading = false
    }

    private func fetch(offset: Int) async -> [Feed] {
        switch mode {
        case .myFeeds:
            return await feedService.loadMyFeedsPage(userId: userId, offset: offset, pageSize: pageSize)
        case .likedFeeds:
            return await feedService.loadLikedFeedsPage(userId: userId, offset: offset, pageSize: pageSize)
        }
    }
}
