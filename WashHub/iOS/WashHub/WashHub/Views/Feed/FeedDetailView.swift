import SwiftUI

struct FeedDetailView: View {
    let feedId: String

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @StateObject private var commentService = CommentService()
    @State private var feed: Feed?
    @State private var beforeImages: [FeedImage] = []
    @State private var afterImages: [FeedImage] = []
    @State private var extraImages: [FeedImage] = []
    @State private var isLiked = false
    @State private var newComment = ""
    @State private var showLoginAlert = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            if let feed = feed {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Before/After 이미지 영역
                        BeforeAfterSlider(
                            beforeImages: beforeImages,
                            afterImages: afterImages
                        )

                        // 추가 사진 갤러리
                        if !extraImages.isEmpty {
                            extraPhotosSection
                        }

                        // 슬라이더와 정보 영역 구분 — iPad 터치 충돌 방지
                        Divider()
                            .background(Color.theme.border)

                        // 피드 정보
                        feedInfoSection(feed)

                        Divider()
                            .background(Color.theme.border)

                        // 댓글 영역
                        commentsSection
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                // 댓글 입력 바
                VStack {
                    Spacer()
                    commentInputBar
                }
            } else {
                ProgressView()
                    .tint(.theme.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") {
                authManager.exitGuestMode()
            }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("좋아요와 댓글은 로그인 후 이용할 수 있습니다.")
        }
        .alert("피드 삭제", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task {
                    do {
                        try await feedService.deleteFeed(id: feedId)
                        NotificationCenter.default.post(
                            name: .feedCountChanged,
                            object: nil
                        )
                        presentationMode.wrappedValue.dismiss()
                    } catch {
                        print("Feed delete error: \(error)")
                    }
                }
            }
        } message: {
            Text("이 피드를 삭제하시겠습니까? 삭제된 피드는 복구할 수 없습니다.")
        }
        .sheet(isPresented: $showEditSheet) {
            if let feed = feed {
                EditFeedView(feed: feed, feedService: feedService) { updatedFeed in
                    self.feed = updatedFeed
                    // 피드 목록에도 변경 알림
                    NotificationCenter.default.post(
                        name: .feedCountChanged,
                        object: nil,
                        userInfo: ["feedId": feedId]
                    )
                }
            }
        }
        .task {
            feed = await feedService.loadFeed(id: feedId)
            let images = await feedService.loadFeedImages(feedId: feedId)
            beforeImages = images.filter { $0.imageType == "BEFORE" }
            afterImages = images.filter { $0.imageType == "AFTER" }
            extraImages = images.filter { $0.imageType == "EXTRA" }
            isLiked = await feedService.isLiked(feedId: feedId)
            await commentService.loadComments(feedId: feedId)
        }
    }

    // MARK: - 추가 사진 갤러리
    private var extraPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("추가 사진")
                .font(.appCaptionMedium)
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(extraImages) { image in
                        AsyncImage(url: URL(string: image.imageUrl)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// 현재 사용자가 이 피드의 작성자인지 확인
    private var isMyFeed: Bool {
        guard let userId = authManager.currentUser?.id else { return false }
        return feed?.userId == userId
    }

    // MARK: - 피드 정보
    private func feedInfoSection(_ feed: Feed) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 작성자 정보
            HStack(spacing: 10) {
                // 작성자 프로필 탭 → UserProfileView 이동
                NavigationLink(destination: UserProfileView(userId: feed.userId).environmentObject(authManager)) {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: feed.profiles?.avatarUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Circle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.profiles?.displayName ?? "사용자")
                                .font(.appCaptionMedium)
                                .foregroundColor(.theme.textPrimary)
                            Text(String(feed.createdAt.prefix(10)))
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // 좋아요 버튼 — iPad에서 터치 영역 확보
                Button(action: toggleLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .theme.error : .theme.textSecondary)
                        Text("\(feed.likeCount)")
                            .font(.appSmall)
                            .foregroundColor(.theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }

                // 수정/삭제 메뉴 (본인 글만)
                if isMyFeed {
                    Menu {
                        Button(action: { showEditSheet = true }) {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: {
                            showDeleteConfirm = true
                        }) {
                            Label("삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.theme.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                }
            }

            // 제목
            if let title = feed.title, !title.isEmpty {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)
                    if feed.isEdited {
                        Text("(편집됨)")
                            .font(.system(size: 10))
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }

            // 내용
            if let content = feed.content, !content.isEmpty {
                Text(content)
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
            }

            // 차량 정보
            if let car = feed.myCars {
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12))
                    Text(car.carModel)
                        .font(.appCaptionMedium)
                    if let color = car.carColor {
                        Text("· \(color)")
                            .font(.appCaption)
                    }
                    if let year = car.carYear {
                        Text("· \(year)년")
                            .font(.appCaption)
                    }
                }
                .foregroundColor(.theme.tertiary)
            }

            // 장소 / 세차 방법
            HStack(spacing: 16) {
                if let location = feed.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
                if let method = feed.washMethod, !method.isEmpty {
                    Label(method, systemImage: "drop.fill")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
            }
        }
        .padding(16)
    }

    // MARK: - 댓글 섹션
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("댓글 \(commentService.comments.count)")
                .font(.appCaptionMedium)
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if commentService.comments.isEmpty {
                Text("아직 댓글이 없습니다. 첫 댓글을 남겨보세요!")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(commentService.comments) { comment in
                    CommentRow(
                        comment: comment,
                        isOwner: comment.userId == authManager.currentUser?.id,
                        canEdit: commentService.canEdit(comment: comment),
                        onEdit: { newContent in
                            Task {
                                try? await commentService.updateComment(
                                    commentId: comment.id,
                                    feedId: feedId,
                                    content: newContent
                                )
                            }
                        },
                        onDelete: {
                            Task {
                                try? await commentService.deleteComment(
                                    commentId: comment.id,
                                    feedId: feedId
                                )
                                feed = await feedService.loadFeed(id: feedId)
                                NotificationCenter.default.post(
                                    name: .feedCountChanged,
                                    object: nil,
                                    userInfo: ["feedId": feedId]
                                )
                            }
                        }
                    )
                }
            }

            // 댓글 입력 바 공간 확보
            Spacer().frame(height: 80)
        }
    }

    // MARK: - 댓글 입력
    private var commentInputBar: some View {
        HStack(spacing: 12) {
            TextField("댓글을 입력하세요", text: $newComment)
                .font(.appBody)
                .foregroundColor(.theme.textPrimary)
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit(submitComment)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.theme.surface)
                .cornerRadius(24)

            Button(action: submitComment) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(newComment.isEmpty ? .theme.textDisabled : .theme.secondary)
            }
            .disabled(newComment.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.theme.neutral)
    }

    // MARK: - Actions
    private func toggleLike() {
        guard !authManager.isGuest else {
            showLoginAlert = true
            return
        }
        Task {
            do {
                isLiked = try await feedService.toggleLike(feedId: feedId)
                feed = await feedService.loadFeed(id: feedId)
                // 피드 목록에 카운터 변경 알림
                NotificationCenter.default.post(
                    name: .feedCountChanged,
                    object: nil,
                    userInfo: ["feedId": feedId]
                )
            } catch {
                print("Like toggle error: \(error)")
            }
        }
    }

    private func submitComment() {
        guard !authManager.isGuest else {
            showLoginAlert = true
            return
        }
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newComment = ""
        isCommentFocused = false   // 키보드 내림

        Task {
            do {
                try await commentService.addComment(feedId: feedId, content: trimmed)
                feed = await feedService.loadFeed(id: feedId)
                // 피드 목록에 카운터 변경 알림
                NotificationCenter.default.post(
                    name: .feedCountChanged,
                    object: nil,
                    userInfo: ["feedId": feedId]
                )
            } catch {
                print("Comment submit error: \(error)")
            }
        }
    }
}

// MARK: - 댓글 Row
struct CommentRow: View {
    let comment: Comment
    var isOwner: Bool = false
    var canEdit: Bool = false
    var onEdit: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var editText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.profiles?.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.theme.surface)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.profiles?.displayName ?? "사용자")
                        .font(.appCaptionMedium)
                        .foregroundColor(.theme.textPrimary)
                    Text(timeAgo(from: comment.createdAt))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)

                    Spacer()

                    // 수정/삭제 메뉴 (본인 댓글만)
                    if isOwner {
                        Menu {
                            if canEdit {
                                Button(action: {
                                    editText = comment.content
                                    isEditing = true
                                }) {
                                    Label("수정", systemImage: "pencil")
                                }
                            }
                            Button(role: .destructive, action: {
                                showDeleteConfirm = true
                            }) {
                                Label("삭제", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.theme.textDisabled)
                                .frame(width: 28, height: 28)
                        }
                    }
                }

                if isEditing {
                    // 수정 모드
                    HStack(spacing: 8) {
                        TextField("댓글 수정", text: $editText)
                            .font(.appCaption)
                            .foregroundColor(.theme.textPrimary)
                            .padding(8)
                            .background(Color.theme.surface)
                            .cornerRadius(8)

                        Button(action: {
                            guard !editText.isEmpty else { return }
                            onEdit?(editText)
                            isEditing = false
                        }) {
                            Text("완료")
                                .font(.appSmall)
                                .foregroundColor(.theme.secondary)
                        }

                        Button(action: { isEditing = false }) {
                            Text("취소")
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(comment.content)
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                        if comment.isEdited {
                            Text("(편집됨)")
                                .font(.system(size: 10))
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .alert("댓글 삭제", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { onDelete?() }
        } message: {
            Text("이 댓글을 삭제하시겠습니까?")
        }
    }

    // 상대 시간 표시
    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            date = fallback.date(from: dateString)
        }
        guard let created = date else { return String(dateString.prefix(10)) }

        let interval = Date().timeIntervalSince(created)
        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }
        return String(dateString.prefix(10))
    }
}

// MARK: - 피드 수정
struct EditFeedView: View {
    @Environment(\.dismiss) var dismiss
    let feed: Feed
    @ObservedObject var feedService: FeedService
    var onUpdated: (Feed) -> Void

    @State private var title: String
    @State private var content: String
    @State private var location: String
    @State private var washMethod: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(feed: Feed, feedService: FeedService, onUpdated: @escaping (Feed) -> Void) {
        self.feed = feed
        self.feedService = feedService
        self.onUpdated = onUpdated
        _title = State(initialValue: feed.title ?? "")
        _content = State(initialValue: feed.content ?? "")
        _location = State(initialValue: feed.location ?? "")
        _washMethod = State(initialValue: feed.washMethod ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 제목
                        VStack(alignment: .leading, spacing: 8) {
                            Text("제목")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("세차 제목을 입력하세요", text: $title)
                                .washHubTextField()
                        }

                        // 내용
                        VStack(alignment: .leading, spacing: 8) {
                            Text("내용")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextEditor(text: $content)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color.theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.border, lineWidth: 1)
                                )
                                .onAppear {
                                    UITextView.appearance().backgroundColor = .clear
                                }
                        }

                        // 장소
                        VStack(alignment: .leading, spacing: 8) {
                            Text("세차 장소 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("장소를 입력하세요", text: $location)
                                .washHubTextField()
                        }

                        // 세차 방법
                        VStack(alignment: .leading, spacing: 8) {
                            Text("세차 방법 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("예: 셀프 손세차, 자동세차 등", text: $washMethod)
                                .washHubTextField()
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appSmall)
                                .foregroundColor(.theme.error)
                        }

                        // 저장 버튼
                        Button(action: save) {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("저장").primaryButtonStyle()
                            }
                        }
                        .disabled(title.isEmpty || isLoading)
                        .opacity(title.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
            .navigationTitle("피드 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
        }
    }

    private func save() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await feedService.updateFeed(
                    id: feed.id,
                    title: title.isEmpty ? nil : title,
                    content: content.isEmpty ? nil : content,
                    location: location.isEmpty ? nil : location,
                    washMethod: washMethod.isEmpty ? nil : washMethod
                )
                // 수정된 피드를 다시 로드
                if let updatedFeed = await feedService.loadFeed(id: feed.id) {
                    onUpdated(updatedFeed)
                }
                dismiss()
            } catch {
                errorMessage = "수정에 실패했습니다: \(error.localizedDescription)"
                print("Feed update error: \(error)")
            }
            isLoading = false
        }
    }
}
