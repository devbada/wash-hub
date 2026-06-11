import SwiftUI

/// v2 신규 홈 화면 — 탭 0
///
/// 구성: 좌상단 ☰ 상단바 + 세차지수 카드 + 바로가기 4-grid + 피드 미리보기.
/// 데이터 바인딩이 필요한 부분(피드 실데이터 등)은 P2-012 후속 태스크로 분리.
struct HomeView: View {
    let userName: String
    let onMenu: () -> Void
    let onNotifications: () -> Void
    let onMyPage: () -> Void
    let onSelectTab: (Int) -> Void
    let onRoutines: () -> Void
    let onOpenFeed: () -> Void

    @EnvironmentObject var authManager: AuthManager
    /// 피드 미리보기용 — 실제 피드 2개 로드
    @StateObject private var feedService = FeedService()
    /// 알림 점 표시 — 미확인 알림 수
    @ObservedObject private var notificationService = NotificationService.shared
    /// 앱 포그라운드 복귀 감지 — 알림 수 재조회용
    @Environment(\.scenePhase) private var scenePhase

    /// "세차 잘하는 법" 카드 부제 — 진입 시 랜덤 노출
    @State private var washTipHint: String = HomeView.washTipHints.randomElement() ?? "초보용 4가지 코스"

    /// "세차 잘하는 법" 카드에 돌아가며 노출할 문구 후보
    private static let washTipHints: [String] = [
        "고수는 어떻게 세차할까?",
        "다른 사람들의 세차법은 무엇일까?",
        "초보라면 여기를 눌러봐요",
        "다른 분들 세차법이 궁금하다면",
        "오늘은 어떻게 세차해볼까?",
        "세차 순서가 헷갈린다면"
    ]

    /// 아바타 이니셜 — 사용자명 첫 글자
    private var initial: String {
        String(userName.prefix(1))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    WashIndexCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    quickAccessSection
                        .padding(.top, 20)

                    feedPeekSection
                        .padding(.top, 28)

                    Color.clear.frame(height: 100)   // 하단 탭바 여백
                }
            }
            .padding(.top, 60)   // 상단바 높이

            topBar
        }
        .task {
            washTipHint = HomeView.washTipHints.randomElement() ?? washTipHint
            // 홈 진입/재진입 시 강제 새로고침 — 다른 화면에서 바뀐 좋아요/댓글 수 반영
            await feedService.loadFeeds(forceRefresh: true, maxCount: 2)
            // 홈 진입/재진입 시 미확인 알림 수 갱신 — 알림 점 표시용
            if !authManager.isGuest {
                await notificationService.fetchUnreadCount()
            }
        }
        // 앱이 포그라운드로 돌아오면 알림 수 재조회 (백그라운드 중 도착한 알림 반영)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !authManager.isGuest {
                Task { await notificationService.fetchUnreadCount() }
            }
        }
        // 다른 화면에서 좋아요/댓글 수가 바뀌면 피드 미리보기 즉시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .feedCountChanged)) { _ in
            Task { await feedService.loadFeeds(forceRefresh: true, maxCount: 2) }
        }
    }

    // MARK: - 상단바 (☰ + 워드마크 + 알림 + 프로필)

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("WashHub")
                .font(.headline(22))
                .foregroundColor(.theme.textPrimary)

            Spacer()

            Button(action: onNotifications) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(.theme.textPrimary)
                        .frame(width: 40, height: 40)
                    // 미확인 알림이 있을 때만 — 오렌지 점
                    if notificationService.unreadCount > 0 {
                        Circle()
                            .fill(Color.rhythmAccent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.theme.surface, lineWidth: 2))
                            .offset(x: -8, y: 8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onMyPage) {
                ProfileAvatar(
                    avatarUrl: authManager.currentUser?.avatarUrl,
                    isOfficial: false,
                    size: 36
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(Color.theme.surface.opacity(0.95))
    }

    // MARK: - 바로가기 4-grid

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("바로가기")
                .font(.appLabelSmall)
                .fontWeight(.heavy)
                .kerning(1.3)
                .foregroundColor(.theme.textSecondary)
                .padding(.horizontal, 20)

            let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                // TODO-minam: 실제 기기에서 흰 카드끼리 구분되는지 확인해 주세요.
                quickCard(icon: "map.fill", title: "근처 세차장", hint: "지도에서 찾기",
                          bg: Color.theme.surfaceLowest, fg: Color.theme.textPrimary,
                          iconTint: Color.theme.accent) { onSelectTab(1) }
                quickCard(icon: "drop.fill", title: "세차용품", hint: "샴푸 · 왁스 · 코팅",
                          bg: Color.theme.surfaceLowest, fg: Color.theme.textPrimary) { onSelectTab(3) }
                quickCard(icon: "list.bullet.clipboard.fill", title: "세차 잘하는 법", hint: washTipHint,
                          bg: Color.theme.surfaceLowest, fg: Color.theme.textPrimary) { onRoutines() }
                quickCard(icon: "chart.bar.fill", title: "내 세차 기록", hint: "통계 보기",
                          bg: Color.theme.primary, fg: Color.theme.onPrimary) { onSelectTab(4) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func quickCard(icon: String, title: String, hint: String,
                           bg: Color, fg: Color, iconTint: Color? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(iconTint ?? fg)
                Spacer(minLength: 12)
                Text(title)
                    .font(.appCaptionBold)
                    .foregroundColor(fg)
                Text(hint)
                    .font(.appSmall)
                    .foregroundColor(fg.opacity(0.7))
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(16)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(HomePressStyle())
    }

    // MARK: - 피드 미리보기

    private var feedPeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("세차 후기 살펴보기")
                    .font(.appHeadline2)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Button(action: onOpenFeed) {
                    Text("전체 보기")
                        .font(.appSmallBold)
                        .foregroundColor(.theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                let peek = Array(feedService.feeds.prefix(2))
                if peek.isEmpty {
                    Text("아직 올라온 피드가 없어요")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(peek) { feed in
                        feedPeekRow(feed)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 실제 피드 1건 미리보기 행
    private func feedPeekRow(_ feed: Feed) -> some View {
        Button(action: onOpenFeed) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: feed.thumbnailUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.theme.surfaceLow)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(feed.profiles?.nickname ?? "세차러")
                            .font(.appSmallBold)
                            .foregroundColor(.theme.textPrimary)
                        if let tag = feed.hashtags.first {
                            Text(tag)
                                .font(.appLabelSmall)
                                .fontWeight(.heavy)
                                .foregroundColor(.theme.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.theme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(feed.content?.isEmpty == false ? feed.content! : "세차 기록을 남겼어요")
                        .font(.appSmall)
                        .foregroundColor(.theme.onSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.theme.error)
                    Text("\(feed.likeCount)")
                        .font(.appSmallBold)
                        .foregroundColor(.theme.textPrimary)
                }
            }
            .padding(16)
            .background(Color.theme.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(HomePressStyle())
    }
}

// MARK: - 프레스 애니메이션

private struct HomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    HomeView(
        userName: "재가입농장",
        onMenu: {}, onNotifications: {}, onMyPage: {},
        onSelectTab: { _ in }, onRoutines: {}, onOpenFeed: {}
    )
}
