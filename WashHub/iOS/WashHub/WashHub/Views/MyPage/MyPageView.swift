import SwiftUI
import Supabase

struct MyPageView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedService = FeedService()
    @StateObject private var badgeService = BadgeService()
    @State private var myFeeds: [Feed] = []
    @State private var likedFeeds: [Feed] = []
    @State private var selectedTab = 0 // 0: 내 피드, 1: 좋아요
    @State private var showEditProfile = false
    @State private var showBadgeCollection = false
    @State private var showFollowList = false
    @State private var followListTab: FollowListView.FollowTab = .followers
    @State private var showFollowingFeed = false
    @State private var showBlockedUsers = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showLogoutConfirm = false
    @State private var showWithdrawConfirm = false
    @State private var isWithdrawing = false
    @State private var withdrawError: String?
    @State private var isLoading = true
    @State private var showBadgeToast = false
    @State private var toastBadgeName: String = ""
    @State private var toastBadgeIcon: String = ""

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 헤더
                    profileHeader

                    // 내 세차 리듬 (P3-012) — 차량 주기 + 노선도 + 다음 세차일
                    if !authManager.isGuest {
                        WashRhythmCard()
                    }

                    // 뱃지 섹션
                    badgeSection

                    // 탭 전환: 내 피드 / 좋아요
                    feedTabs

                    // 설정
                    settingsSection
                }
                .padding(16)
            }
        }
        .navigationTitle("마이페이지")
        .sheet(isPresented: $showEditProfile, onDismiss: {
            // 프로필 편집 후 최신 프로필 반영 보장
            Task {
                if let userId = authManager.currentUser?.id {
                    await authManager.loadProfile(userId: userId)
                }
            }
        }) {
            EditProfileView()
                .environmentObject(authManager)
        }
        // NavigationStack 기반 프로그래밍 이동 — isPresented 바인딩만으로 push
        .navigationDestination(isPresented: $showBadgeCollection) {
            BadgeCollectionView().environmentObject(authManager)
        }
        .navigationDestination(isPresented: $showFollowList) {
            FollowListView(
                userId: authManager.currentUser?.id ?? "",
                userName: authManager.currentUser?.displayName ?? "사용자",
                selectedTab: followListTab
            ).environmentObject(authManager)
        }
        .navigationDestination(isPresented: $showFollowingFeed) {
            FollowingFeedView().environmentObject(authManager)
        }
        .navigationDestination(isPresented: $showBlockedUsers) {
            BlockedUsersListView()
        }
        .overlay(alignment: .top) {
            if showBadgeToast {
                badgeToastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "이용약관", url: LegalURLs.termsOfService)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(title: "개인정보처리방침", url: LegalURLs.privacyPolicy)
        }
        .task {
            await loadData()
            await checkBadges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedCreated)) { _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        if let userId = authManager.currentUser?.id {
            myFeeds = await feedService.loadMyFeeds(userId: userId)
            likedFeeds = await loadLikedFeeds(userId: userId)
            await badgeService.loadAllBadges()
            await badgeService.loadMyBadges(userId: userId)
        }
        isLoading = false
    }

    /// 도움말 다시 보기 — 마이페이지를 닫고 HomeTabView 가 활성화된 후 코치마크 강제 시작
    private func replayCoachmark() {
        dismiss()
        Task { @MainActor in
            // 마이페이지 pop 애니메이션 + HomeTabView anchor 좌표 갱신 시간 확보
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s
            CoachmarkController.shared.forceStart(steps: HomeCoachmark.v1Steps)
        }
    }

    private func checkBadges() async {
        await badgeService.checkAndUnlockBadges()
        if let first = badgeService.newlyUnlocked.first {
            toastBadgeName = first.badgeName
            toastBadgeIcon = first.iconName
            withAnimation(.spring()) {
                showBadgeToast = true
            }
            // 뱃지 목록 리프레시
            if let userId = authManager.currentUser?.id {
                await badgeService.loadMyBadges(userId: userId)
            }
            // 3초 후 토스트 자동 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showBadgeToast = false }
                badgeService.consumeNewlyUnlocked()
            }
        }
    }

    private func loadLikedFeeds(userId: String) async -> [Feed] {
        do {
            // feed_likes에서 내가 좋아요한 feed_id 조회 후 피드 로드
            struct LikeRow: Codable {
                let feedId: String
                enum CodingKeys: String, CodingKey {
                    case feedId = "feed_id"
                }
            }
            let persistLikes: [LikeRow] = try await supabase
                .from("feed_likes")
                .select("feed_id")
                .eq("user_id", value: userId)
                .execute()
                .value

            let feedIds = persistLikes.map { $0.feedId }
            guard !feedIds.isEmpty else { return [] }

            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official), my_cars(id, car_model, car_color, car_year, nickname)")
                .in("id", values: feedIds)
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value
            return persistFeeds
        } catch {
            print("Liked feeds load error: \(error)")
            return []
        }
    }

    // MARK: - 프로필 헤더
    private var profileHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: authManager.currentUser?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.theme.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(authManager.currentUser?.displayName ?? "사용자")
                            .font(.appHeadline2)
                            .foregroundColor(.theme.textPrimary)

                        // 대표 타이틀 뱃지
                        if let titleBadge = titleBadge {
                            HStack(spacing: 3) {
                                Image(systemName: titleBadge.iconName)
                                    .font(.system(size: 10))
                                Text(titleBadge.name)
                                    .font(.appSmall)
                            }
                            .foregroundColor(.theme.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.theme.secondary.opacity(0.12))
                            )
                        }
                    }

                    if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            followListTab = .followers
                            showFollowList = true
                        }) {
                            Label("팔로워 \(authManager.currentUser?.followerCount ?? 0)", systemImage: "person.2")
                        }
                        Button(action: {
                            followListTab = .followings
                            showFollowList = true
                        }) {
                            Label("팔로잉 \(authManager.currentUser?.followingCount ?? 0)", systemImage: "person.badge.plus")
                        }
                    }
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)

                    HStack(spacing: 16) {
                        Label("차량 \(authManager.currentUser?.carCount ?? 0)", systemImage: "car")
                        Label("세차 \(authManager.currentUser?.washCount ?? 0)", systemImage: "drop.fill")
                        Label("뱃지 \(badgeService.myBadges.count)", systemImage: "trophy")
                    }
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
                }

                Spacer()
            }

            // 프로필 수정 + 팔로잉 피드 버튼
            HStack(spacing: 8) {
                Button(action: { showEditProfile = true }) {
                    Text("프로필 수정")
                        .font(.appCaptionMedium)
                        .foregroundColor(.theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.theme.surface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.border, lineWidth: 1))
                }

                Button(action: { showFollowingFeed = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.person.crop")
                            .font(.system(size: 12))
                        Text("팔로잉 피드")
                    }
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.theme.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.border, lineWidth: 1))
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - 피드 탭
    private var feedTabs: some View {
        VStack(spacing: 12) {
            // 탭 헤더
            HStack(spacing: 0) {
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 6) {
                        Text("내 피드 \(myFeeds.count)")
                            .font(.appCaptionMedium)
                            .foregroundColor(selectedTab == 0 ? .theme.secondary : .theme.textDisabled)
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.theme.secondary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)

                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 6) {
                        Text("좋아요 \(likedFeeds.count)")
                            .font(.appCaptionMedium)
                            .foregroundColor(selectedTab == 1 ? .theme.secondary : .theme.textDisabled)
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.theme.secondary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // 피드 리스트 — 마이페이지에서는 최신 5개만 미리보기, 그 이상은 '모두 보기' 진입
            let allFeeds = selectedTab == 0 ? myFeeds : likedFeeds
            let previewLimit = 5
            let feeds = Array(allFeeds.prefix(previewLimit))
            if allFeeds.isEmpty {
                Text(selectedTab == 0 ? "작성한 피드가 없습니다" : "좋아요한 피드가 없습니다")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(feeds) { feed in
                        NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: feed.thumbnailUrl ?? "")) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        RoundedRectangle(cornerRadius: 6).fill(Color.theme.surface)
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 4) {
                                    // 본문 발췌 (제목은 deprecated — 사진 중심 UI)
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
                        .buttonStyle(.plain)
                    }

                    // 미리보기 한도(5개) 초과 시 — 전체 보기 진입
                    if allFeeds.count > previewLimit, let myId = authManager.currentUser?.id {
                        NavigationLink(destination: MyFeedListPageView(
                            mode: selectedTab == 0 ? .myFeeds : .likedFeeds,
                            userId: myId
                        )) {
                            HStack {
                                Spacer()
                                Text("\(allFeeds.count)개 모두 보기")
                                    .font(.appCaptionMedium)
                                    .foregroundColor(.theme.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.theme.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.theme.secondary.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 타이틀 뱃지 계산
    private var titleBadge: Badge? {
        guard let titleId = authManager.currentUser?.titleBadgeId else { return nil }
        return badgeService.allBadges.first(where: { $0.id == titleId })
    }

    // MARK: - 뱃지 섹션
    private var badgeSection: some View {
        VStack(spacing: 12) {
            // 헤더
            HStack {
                Text("내 뱃지")
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Button(action: { showBadgeCollection = true }) {
                    HStack(spacing: 4) {
                        Text("전체보기")
                            .font(.appCaption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.theme.textSecondary)
                }
            }

            // 미니 뱃지 그리드 (획득한 것만, 최대 6개)
            let unlockedBadges = badgeService.myBadges.compactMap { $0.badges }
            if unlockedBadges.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .foregroundColor(.theme.textDisabled)
                    Text("아직 획득한 뱃지가 없습니다")
                        .font(.appCaption)
                        .foregroundColor(.theme.textDisabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(unlockedBadges.prefix(6)), id: \.id) { badge in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: badgeGradient(badge),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text(badge.name)
                                .font(.system(size: 9))
                                .foregroundColor(.theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func badgeGradient(_ badge: Badge) -> [Color] {
        guard let type = BadgeType(rawValue: badge.badgeType) else {
            return [.theme.secondary, .theme.secondaryDim]
        }
        let (start, end) = type.gradientColors
        return [Color(hex: start), Color(hex: end)]
    }

    // MARK: - 뱃지 획득 토스트
    private var badgeToastView: some View {
        HStack(spacing: 10) {
            Image(systemName: toastBadgeIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.theme.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("뱃지 획득!")
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.textPrimary)
                Text("「\(toastBadgeName)」 뱃지를 획득했습니다")
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)
            }
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
                .onTapGesture {
                    withAnimation { showBadgeToast = false }
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.surfaceLowest)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 설정
    private var settingsSection: some View {
        VStack(spacing: 8) {
            // 도움말 다시 보기 — 첫 사용자 코치마크 강제 재실행
            Button(action: replayCoachmark) {
                HStack {
                    Text("도움말 다시 보기")
                        .font(.appBody)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }

            // 차단 관리
            Button(action: { showBlockedUsers = true }) {
                HStack {
                    Text("차단 관리")
                        .font(.appBody)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }

            // 이용약관
            Button(action: { showTerms = true }) {
                HStack {
                    Text("이용약관")
                        .font(.appBody)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }

            // 개인정보처리방침
            Button(action: { showPrivacy = true }) {
                HStack {
                    Text("개인정보처리방침")
                        .font(.appBody)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }

            Button(action: { showLogoutConfirm = true }) {
                HStack {
                    Text("로그아웃")
                        .font(.appBody)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }
            .alert("로그아웃", isPresented: $showLogoutConfirm) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    Task { try? await authManager.signOut() }
                }
            } message: {
                Text("로그아웃하시겠습니까?")
            }

            Button(action: { showWithdrawConfirm = true }) {
                HStack {
                    Text("회원탈퇴")
                        .font(.appBody)
                        .foregroundColor(.theme.error)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.textDisabled)
                }
                .padding(16)
                .cardStyle()
            }
            .alert("회원탈퇴", isPresented: $showWithdrawConfirm) {
                Button("취소", role: .cancel) {}
                Button("탈퇴", role: .destructive) {
                    isWithdrawing = true
                    Task {
                        do {
                            try await authManager.withdraw()
                        } catch {
                            withdrawError = "탈퇴 처리 중 오류: \(error.localizedDescription)"
                            print("Withdraw error: \(error)")
                        }
                        isWithdrawing = false
                    }
                }
            } message: {
                Text("정말 탈퇴하시겠습니까?\n계정이 비활성화되며 재가입 시 새로운 계정으로 시작됩니다.")
            }
            .alert("탈퇴 실패", isPresented: .init(
                get: { withdrawError != nil },
                set: { if !$0 { withdrawError = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(withdrawError ?? "")
            }
            .overlay {
                if isWithdrawing {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("탈퇴 처리 중...")
                            .font(.appCaption)
                            .foregroundColor(.white)
                    }
                }
            }

            // 앱 버전 표시
            HStack {
                Text("앱 버전")
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
                Spacer()
                Text(appVersionText)
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
            }
            .padding(16)
            .cardStyle()
        }
    }

    // MARK: - 앱 버전 (Bundle)
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - 프로필 수정
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var nickname = ""
    @State private var originalNickname = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showImageSourcePicker = false
    @State private var selectedAvatar: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // 아바타 (탭으로 변경)
                        Button(action: { showImageSourcePicker = true }) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let selectedAvatar = selectedAvatar {
                                        Image(uiImage: selectedAvatar)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        AsyncImage(url: URL(string: authManager.currentUser?.avatarUrl ?? "")) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            default:
                                                Circle().fill(Color.theme.surfaceHigh)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 36))
                                                            .foregroundColor(.theme.textDisabled)
                                                    )
                                            }
                                        }
                                    }
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.theme.secondary.opacity(0.4), lineWidth: 2)
                                )

                                // 카메라 뱃지
                                Circle()
                                    .fill(Color.theme.secondary)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(Circle().stroke(Color.theme.surface, lineWidth: 2))
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .buttonStyle(.plain)

                        // 이미지 업로드 안내
                        Text("탭하여 사진 선택 · 자동으로 1024px / 2MB 이하로 최적화")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                            .multilineTextAlignment(.center)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("닉네임")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("닉네임을 입력하세요", text: $nickname)
                                .washHubTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("한줄 소개 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("나를 소개하세요", text: $bio)
                                .washHubTextField()
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: saveProfile) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else {
                                Text("저장").primaryButtonStyle()
                            }
                        }
                        .disabled(nickname.isEmpty || isLoading)
                        .opacity(nickname.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.theme.textSecondary)
                }
            }
            .alert("저장 완료", isPresented: $showSuccess) {
                Button("확인") { dismiss() }
            } message: {
                Text("프로필이 업데이트되었습니다.")
            }
            // BottomSheet 가 form 위에 보이도록 overlay 로 부착
            .overlay(
                ImageSourcePicker(
                    isPresented: $showImageSourcePicker,
                    skipFaceMosaic: true,  // 프로필 사진은 얼굴 모자이크 제외
                    onImageReady: { image in
                        selectedAvatar = image
                    }
                )
                .allowsHitTesting(showImageSourcePicker)
            )
            .onAppear {
                nickname = authManager.currentUser?.nickname ?? ""
                originalNickname = nickname
                bio = authManager.currentUser?.bio ?? ""
            }
        }
    }

    private func saveProfile() {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        // 유효성: 닉네임 길이 2~20
        guard trimmedNickname.count >= 2, trimmedNickname.count <= 20 else {
            // TODO-minam: 공통 유효성 메시지 토스트로 전환
            errorMessage = "닉네임은 2~20자로 입력해주세요."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 1. 닉네임 중복 검사 (변경된 경우에만)
                if trimmedNickname != originalNickname {
                    let isDuplicate = try await authManager.checkNicknameDuplicate(trimmedNickname)
                    if isDuplicate {
                        errorMessage = "이미 사용 중인 닉네임입니다."
                        isLoading = false
                        return
                    }
                }

                let session = try await supabase.auth.session
                // RLS 정책의 auth.uid()::text 가 소문자이므로 path 도 소문자로 통일
                let userId = session.user.id.uuidString.lowercased()

                // 2. 아바타 업로드 (선택된 경우)
                // profiles 버킷 재사용 — 본인 폴더(`{userId}/`) 하위에만 업로드 허용 (RLS)
                // iPhone 원본 사진은 쉽게 10-20MB 이므로 긴 변 1024px / 2MB 이하로 리사이즈
                var avatarUrl: String?
                if let image = selectedAvatar {
                    guard let imageData = image.jpegDataUnder(maxDimension: 1024, maxBytes: 2 * 1024 * 1024) else {
                        // TODO-minam: 인코딩 실패 시 사용자 알림
                        errorMessage = "이미지 처리에 실패했습니다. 다른 사진으로 시도해주세요."
                        isLoading = false
                        return
                    }
                    // 서버 버킷 제한(5MB) 안전 검증 — 정책이 바뀌어도 클라이언트에서 한 번 더 차단
                    let serverLimit = 5 * 1024 * 1024
                    if imageData.count > serverLimit {
                        errorMessage = "이미지 용량이 너무 큽니다. 더 작은 사진을 선택해주세요."
                        isLoading = false
                        return
                    }

                    let path = "\(userId)/\(UUID().uuidString).jpg"
                    try await supabase.storage
                        .from("profiles")
                        .upload(
                            path,
                            data: imageData,
                            options: .init(contentType: "image/jpeg", upsert: true)
                        )
                    avatarUrl = try supabase.storage
                        .from("profiles")
                        .getPublicURL(path: path)
                        .absoluteString
                }

                // 3. 프로필 업데이트
                var updateData: [String: String] = [
                    "nickname": trimmedNickname,
                    "bio": bio
                ]
                if let avatarUrl = avatarUrl {
                    updateData["avatar_url"] = avatarUrl
                }

                try await supabase
                    .from("profiles")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()

                await authManager.loadProfile(userId: userId)
                showSuccess = true
            } catch {
                // TODO-minam: 에러 코드별 세분화된 메시지 처리
                errorMessage = "프로필 저장에 실패했습니다. 잠시 후 다시 시도해주세요."
                print("Profile update error: \(error)")
            }
            isLoading = false
        }
    }
}
