import SwiftUI
import Supabase

struct MyPageView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @State private var myFeeds: [Feed] = []
    @State private var likedFeeds: [Feed] = []
    @State private var selectedTab = 0 // 0: 내 피드, 1: 좋아요
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false
    @State private var showWithdrawConfirm = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 헤더
                    profileHeader

                    // 탭 전환: 내 피드 / 좋아요
                    feedTabs

                    // 설정
                    settingsSection
                }
                .padding(16)
            }
        }
        .navigationTitle("마이페이지")
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authManager)
        }
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .feedCreated)) { _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        if let userId = authManager.currentUser?.id {
            myFeeds = await feedService.loadMyFeeds(userId: userId)
            likedFeeds = await loadLikedFeeds(userId: userId)
        }
        isLoading = false
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
                .select("*, profiles!user_id(id, nickname, avatar_url), my_cars(id, car_model, car_color, car_year)")
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
                    Text(authManager.currentUser?.displayName ?? "사용자")
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)

                    if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 16) {
                        Label("차량 \(authManager.currentUser?.carCount ?? 0)", systemImage: "car")
                        Label("세차 \(authManager.currentUser?.washCount ?? 0)", systemImage: "drop.fill")
                    }
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
                }

                Spacer()
            }

            // 프로필 수정 버튼
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

            // 피드 리스트
            let feeds = selectedTab == 0 ? myFeeds : likedFeeds
            if feeds.isEmpty {
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
                                    Text(feed.title ?? "제목 없음")
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
                }
            }
        }
    }

    // MARK: - 설정
    private var settingsSection: some View {
        VStack(spacing: 8) {
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
                    Task { try? await authManager.withdraw() }
                }
            } message: {
                Text("정말 탈퇴하시겠습니까?\n모든 데이터가 삭제됩니다.")
            }
        }
    }
}

// MARK: - 프로필 수정
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var nickname = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // 아바타
                        AsyncImage(url: URL(string: authManager.currentUser?.avatarUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Circle().fill(Color.theme.surface)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.theme.textDisabled)
                                    )
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

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
            .onAppear {
                nickname = authManager.currentUser?.nickname ?? ""
                bio = authManager.currentUser?.bio ?? ""
            }
        }
    }

    private func saveProfile() {
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                try await supabase
                    .from("profiles")
                    .update(["nickname": nickname, "bio": bio])
                    .eq("id", value: session.user.id.uuidString)
                    .execute()

                await authManager.loadProfile(userId: session.user.id.uuidString)
                showSuccess = true
            } catch {
                print("Profile update error: \(error)")
            }
            isLoading = false
        }
    }
}
