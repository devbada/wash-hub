import SwiftUI
import Supabase

struct CreateFeedView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()

    /// 본문 사전 채움 — 루틴 따라하기 완료 후 진입 시 자동으로 본문 채워둠
    var prefilledContent: String? = nil
    /// 추천 해시태그 사전 추가 — 루틴 이름 등 외부 컨텍스트에서 주입
    var prefilledHashtags: [String] = []
    /// "방금 찍은 사진은 앨범에 있어요" 같은 안내 문구 표시 여부
    var showPhotoFromAlbumHint: Bool = false
    /// 피드 작성 성공 후 호출되는 콜백 — 작성된 feed.id 를 받아 외부에서 후처리 가능 (예: routine_executions.feed_id 업데이트)
    var onFeedCreated: ((String) -> Void)? = nil

    @State private var content = ""
    @State private var location = ""
    @State private var washMethod = ""
    @State private var beforeImages: [UIImage] = []
    @State private var afterImages: [UIImage] = []
    @State private var extraImages: [UIImage] = []
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    // 협찬/PPL
    @State private var isSponsored = false
    @State private var sponsorName = ""

    // 내차 선택
    @State private var myCars: [MyCar] = []
    @State private var selectedCarId: String?

    // 이미지 피커 상태
    @State private var activePickerType: ImagePickerType?
    @State private var showImageSourcePicker = false

    // 리스트 카드 썸네일 소스 — 사용자가 Before / After 중 어느 것을 카드 노출용으로 쓸지 선택
    @State private var thumbnailSource: ThumbnailSource = .after

    // 해시태그 — 추천 + 사용자 선택. 본문/차량/세차방식 변경 시 추천 자동 갱신
    @State private var suggestedHashtags: [String] = []
    @State private var selectedHashtags: Set<String> = []
    // 사용자가 직접 입력한 커스텀 해시태그 (추천에 없는 것)
    @State private var customHashtags: [String] = []
    // 항상 보이는 입력 TextField 의 텍스트
    @State private var customTagInput: String = ""
    // 본문 입력 debounce — 타이핑 중 매 키스트로크마다 chip 재계산하면 SwiftUI re-render 비용으로 입력 끊김
    @State private var hashtagDebounceTask: Task<Void, Never>?

    enum ImagePickerType: Identifiable {
        case before, after, extra
        var id: String { "\(self)" }
    }

    /// 리스트 썸네일로 사용할 사진의 종류 (Before / After)
    enum ThumbnailSource: String, CaseIterable, Identifiable {
        case before, after
        var id: String { rawValue }
        var label: String {
            switch self {
            case .before: return "Before"
            case .after:  return "After"
            }
        }
    }

    private var canSubmit: Bool {
        !beforeImages.isEmpty && !afterImages.isEmpty && !isLoading
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 내용
                        VStack(alignment: .leading, spacing: 8) {
                            Text("내용")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextEditor(text: $content)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 100)
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

                        // 추천 해시태그 — 본문/차량/세차방식에서 자동 추출, 탭하여 선택/해제 + 직접 추가
                        hashtagSuggestionSection

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

                        // 내차 선택
                        if !myCars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("세차한 차량 (선택)")
                                    .font(.appLabel)
                                    .foregroundColor(.theme.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(myCars) { car in
                                            Button(action: {
                                                hideKeyboard()
                                                selectedCarId = selectedCarId == car.id ? nil : car.id
                                            }) {
                                                HStack(spacing: 8) {
                                                    if let imageUrl = car.imageUrl,
                                                       let url = URL(string: imageUrl) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                            default:
                                                                Image(systemName: "car.fill")
                                                                    .foregroundColor(.theme.textDisabled)
                                                            }
                                                        }
                                                        .frame(width: 32, height: 32)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    } else {
                                                        Image(systemName: "car.fill")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(selectedCarId == car.id ? .white : .theme.textSecondary)
                                                    }

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(car.carModel)
                                                            .font(.appSmall)
                                                            .foregroundColor(selectedCarId == car.id ? .white : .theme.textPrimary)
                                                        if let color = car.carColor {
                                                            Text(color)
                                                                .font(.system(size: 10))
                                                                .foregroundColor(selectedCarId == car.id ? .white.opacity(0.85) : .theme.textDisabled)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    selectedCarId == car.id
                                                        ? Color.theme.secondary
                                                        : Color.theme.surface
                                                )
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            selectedCarId == car.id
                                                                ? Color.theme.secondary
                                                                : Color.theme.border,
                                                            lineWidth: 1
                                                        )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Before / After 사진 — 각각 1장만 (썸네일 선택 일관성)
                        HStack(alignment: .top, spacing: 12) {
                            compactImageSection(
                                title: "Before",
                                images: $beforeImages,
                                maxCount: 1,
                                onAdd: { hideKeyboard(); activePickerType = .before }
                            )

                            compactImageSection(
                                title: "After",
                                images: $afterImages,
                                maxCount: 1,
                                onAdd: { hideKeyboard(); activePickerType = .after }
                            )
                        }

                        // 사진 앨범 안내 — 외부에서 사진 찍어둔 경우 (루틴 따라하기 후 등)
                        // Before/After 영역 바로 아래에 작게 표시 — 사용자가 + 버튼 보고 망설일 때 도움
                        if showPhotoFromAlbumHint {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 11))
                                    .foregroundColor(.theme.secondary)
                                    .padding(.top, 1)
                                Text("방금 촬영한 사진은 사진 앨범에 있어요. + 버튼으로 선택해주세요.")
                                    .font(.appSmall)
                                    .foregroundColor(.theme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // 비율 안내 — 같은 비율(가로/세로 일치)이면 슬라이더 비교가 더 깔끔
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.theme.textDisabled)
                                .padding(.top, 1)
                            Text("같은 비율의 사진을 올리면 Before/After 비교가 더 자연스러워요")
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 리스트 썸네일 소스 선택 — Before/After 중 어떤 사진을 카드에 노출할지
                        thumbnailSourcePicker

                        // 추가 사진 (선택)
                        wideImageSection(
                            title: "추가 사진 (선택)",
                            subtitle: "과정, 장비, 디테일 등",
                            images: $extraImages,
                            maxCount: 10,
                            onAdd: { hideKeyboard(); activePickerType = .extra }
                        )

                        // 협찬/PPL 설정
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $isSponsored) {
                                HStack(spacing: 6) {
                                    Image(systemName: "megaphone.fill")
                                        .foregroundColor(Color(red: 255/255, green: 176/255, blue: 59/255))
                                        .font(.system(size: 14))
                                    Text("협찬/광고 피드")
                                        .font(.appBody)
                                        .foregroundColor(.theme.textPrimary)
                                }
                            }
                            .tint(.theme.secondary)

                            if isSponsored {
                                TextField("협찬 브랜드명 (예: 소낙스코리아)", text: $sponsorName)
                                    .washHubTextField()
                            }
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appSmall)
                                .foregroundColor(.theme.error)
                        }

                        // 작성 완료 버튼 — Hero CTA
                        Button(action: submitFeed) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 132/255, green: 204/255, blue: 22/255),
                                                Color(red: 101/255, green: 163/255, blue: 13/255)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.45), radius: 20, x: 0, y: 10)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("작성 완료")
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .ctaButtonStyle()
                            }
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1.0 : 0.45)
                        .scaleEffect(canSubmit ? 1.0 : 0.98)
                        .animation(.easeInOut(duration: 0.2), value: canSubmit)
                        .padding(.top, 4)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("피드 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .alert("작성 완료", isPresented: $showSuccess) {
                Button("확인") { dismiss() }
            } message: {
                Text("피드가 성공적으로 등록되었습니다!")
            }
            .task {
                await loadMyCars()
                applyPrefillIfNeeded()
                refreshHashtagSuggestions()
            }
            .onChange(of: activePickerType) { newValue in
                if newValue != nil {
                    showImageSourcePicker = true
                }
            }
            // 본문/세차방식 — 타이핑 중 키스트로크마다 호출되므로 디바운스(400ms)로 입력 끊김 방지
            .onChange(of: content) { _ in scheduleHashtagRefresh() }
            .onChange(of: washMethod) { _ in scheduleHashtagRefresh() }
            // 차량 선택은 탭 한 번에 끝나므로 즉시 갱신해도 부담 없음
            .onChange(of: selectedCarId) { _ in refreshHashtagSuggestions() }
            .background(
                ImageSourcePicker(
                    isPresented: $showImageSourcePicker,
                    onImageReady: { image in
                        guard let type = activePickerType else { return }
                        switch type {
                        case .before:
                            // Before/After 는 1장 제한 — 옵션 B(명시적 삭제 후 추가)
                            if beforeImages.isEmpty { beforeImages.append(image) }
                        case .after:
                            if afterImages.isEmpty { afterImages.append(image) }
                        case .extra:
                            if extraImages.count < 10 { extraImages.append(image) }
                        }
                        activePickerType = nil
                    }
                )
            )
        }
    }

    // MARK: - Before/After 컴팩트 이미지 섹션 (반반)
    private func compactImageSection(
        title: String,
        images: Binding<[UIImage]>,
        maxCount: Int,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.appLabel)
                    .foregroundColor(.theme.textSecondary)
                Spacer()
                Text("\(images.wrappedValue.count)/\(maxCount)")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            // 이미지 그리드
            let cols = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(images.wrappedValue.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: images.wrappedValue[index])
                            .resizable()
                            .scaledToFill()
                            .frame(height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button(action: { images.wrappedValue.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: 2, y: -2)
                    }
                }

                if images.wrappedValue.count < maxCount {
                    Button(action: onAdd) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.theme.surface)
                            .frame(height: 60)
                            .overlay(
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
            }
        }
        .padding(12)
        .background(Color.theme.surface.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.border, lineWidth: 1)
        )
    }

    // MARK: - 추가 사진 와이드 섹션
    private func wideImageSection(
        title: String,
        subtitle: String,
        images: Binding<[UIImage]>,
        maxCount: Int,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.appLabel)
                    .foregroundColor(.theme.textSecondary)
                Text(subtitle)
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
                Spacer()
                Text("\(images.wrappedValue.count)/\(maxCount)")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images.wrappedValue.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: images.wrappedValue[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: { images.wrappedValue.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: 4, y: -4)
                        }
                    }

                    if images.wrappedValue.count < maxCount {
                        Button(action: onAdd) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.theme.surface)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.theme.textDisabled)
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 추천 해시태그 chip (Carbon&Citrus 토큰 — 선택 시 primary 액센트)
    /// 표시되는 모든 태그 = 추천 태그 ∪ 커스텀 태그 (순서: 추천 먼저, 커스텀 뒤)
    private var allDisplayTags: [String] {
        suggestedHashtags + customHashtags.filter { !suggestedHashtags.contains($0) }
    }

    private var hashtagSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.system(size: 12))
                    .foregroundColor(.theme.textSecondary)
                Text("해시태그")
                    .font(.appLabel)
                    .foregroundColor(.theme.textSecondary)
                Spacer()
                Text(allDisplayTags.isEmpty ? "본문 입력 시 자동 추천" : "탭하여 선택/해제")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            // chip + 직접 추가 — 가로 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allDisplayTags, id: \.self) { tag in
                        let isOn = selectedHashtags.contains(tag)
                        Button(action: {
                            hideKeyboard()
                            if isOn {
                                selectedHashtags.remove(tag)
                            } else {
                                selectedHashtags.insert(tag)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isOn ? .white : .theme.textSecondary)
                                // 커스텀 태그는 X 버튼으로 영구 삭제 가능
                                if customHashtags.contains(tag) {
                                    Button(action: { removeCustomTag(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(isOn ? .white.opacity(0.7) : .theme.textDisabled)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isOn ? Color.theme.primary : Color.theme.surfaceHigh)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    // 항상 보이는 입력 TextField — chip 처럼 보이지만 즉시 입력 가능
                    HStack(spacing: 3) {
                        Image(systemName: "number")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.theme.textDisabled)
                        TextField("태그 추가", text: $customTagInput)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.theme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.done)
                            .onSubmit { commitCustomTag() }
                            .frame(minWidth: 70)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.outline.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 외부 사전 채움 적용 (루틴 따라하기 완료 후 진입 등)
    /// task 시점에 한 번 호출. content 가 비어있을 때만 prefilled 적용 (덮어쓰기 방지)
    private func applyPrefillIfNeeded() {
        if content.isEmpty, let prefill = prefilledContent, !prefill.isEmpty {
            content = prefill
        }
        // 추천 해시태그에 외부 컨텍스트 힌트 추가 (루틴 이름 등)
        for tag in prefilledHashtags where !customHashtags.contains(tag) && !suggestedHashtags.contains(tag) {
            customHashtags.append(tag)
            selectedHashtags.insert(tag)
        }
    }

    // MARK: - 디바운스 스케줄러 — 타이핑 멈춘 후 400ms 뒤에 추천 갱신
    /// 매 키스트로크마다 호출되어도 안전 — 마지막 호출 후 400ms 가 지나야 실제 갱신 발생
    private func scheduleHashtagRefresh() {
        hashtagDebounceTask?.cancel()
        hashtagDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            refreshHashtagSuggestions()
        }
    }

    // MARK: - 추천 해시태그 갱신 — 본문/차량/세차방식이 바뀔 때마다 호출
    private func refreshHashtagSuggestions() {
        let car = myCars.first(where: { $0.id == selectedCarId }).map { car -> FeedCar in
            FeedCar(id: car.id, carModel: car.carModel, carColor: car.carColor, carYear: car.carYear, nickname: car.nickname)
        }
        let new = HashtagGenerator.generate(
            content: content.isEmpty ? nil : content,
            washMethod: washMethod.isEmpty ? nil : washMethod,
            car: car
        )
        // 새로 추가된 추천은 기본 선택, 사라진 추천은 selectedHashtags에서 제거 (커스텀은 유지)
        let newSet = Set(new)
        let customSet = Set(customHashtags)
        selectedHashtags = selectedHashtags.intersection(newSet.union(customSet))
        for tag in new where !selectedHashtags.contains(tag) {
            selectedHashtags.insert(tag)
        }
        suggestedHashtags = new
    }

    // MARK: - 직접 추가 처리
    private func commitCustomTag() {
        defer { customTagInput = "" }
        let trimmed = customTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 자동으로 # 접두사 보정 + 공백/특수문자 제거
        let normalized = "#" + trimmed
            .replacingOccurrences(of: "#", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard normalized.count >= 2, normalized.count <= 30 else { return }
        if !customHashtags.contains(normalized) && !suggestedHashtags.contains(normalized) {
            customHashtags.append(normalized)
        }
        selectedHashtags.insert(normalized)
    }

    private func removeCustomTag(_ tag: String) {
        customHashtags.removeAll { $0 == tag }
        selectedHashtags.remove(tag)
    }

    // MARK: - 썸네일 소스 선택 (Before / After 중 리스트 카드에 노출할 사진)
    private var thumbnailSourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("리스트 썸네일로 사용")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)

            Picker("리스트 썸네일", selection: $thumbnailSource) {
                ForEach(ThumbnailSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 내차 목록 로드
    private func loadMyCars() async {
        do {
            let session = try await supabase.auth.session
            let persistCars: [MyCar] = try await supabase
                .from("my_cars")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "ACTIVE")
                .order("is_primary", ascending: false)
                .execute()
                .value
            myCars = persistCars

            // 대표 차량 자동 선택
            if let primaryCar = persistCars.first(where: { $0.isPrimary }) {
                selectedCarId = primaryCar.id
            }
        } catch {
            print("MyCars load error: \(error)")
        }
    }

    // MARK: - 키보드 숨기기
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - 피드 제출
    private func submitFeed() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 피드 사진은 Before/After 비교용이라 해상도를 상대적으로 높게 유지 (긴 변 1920px, 3MB)
                // 원본 UIImage 사이즈를 함께 보존 → 상세 화면 컨테이너 비율 동적 결정에 활용
                let beforeUploads = beforeImages.compactMap { img -> FeedService.UploadImage? in
                    guard let data = img.jpegDataUnder(maxDimension: 1920, maxBytes: 3 * 1024 * 1024) else { return nil }
                    return FeedService.UploadImage(data: data, width: Int(img.size.width), height: Int(img.size.height))
                }
                let afterUploads = afterImages.compactMap { img -> FeedService.UploadImage? in
                    guard let data = img.jpegDataUnder(maxDimension: 1920, maxBytes: 3 * 1024 * 1024) else { return nil }
                    return FeedService.UploadImage(data: data, width: Int(img.size.width), height: Int(img.size.height))
                }
                let extraUploads = extraImages.compactMap { img -> FeedService.UploadImage? in
                    guard let data = img.jpegDataUnder(maxDimension: 1920, maxBytes: 3 * 1024 * 1024) else { return nil }
                    return FeedService.UploadImage(data: data, width: Int(img.size.width), height: Int(img.size.height))
                }

                let createdFeedId = try await feedService.createFeed(
                    content: content.isEmpty ? nil : content,
                    location: location.isEmpty ? nil : location,
                    washMethod: washMethod.isEmpty ? nil : washMethod,
                    carId: selectedCarId,
                    beforeImages: beforeUploads,
                    afterImages: afterUploads,
                    extraImages: extraUploads,
                    thumbnailFromBefore: thumbnailSource == .before,
                    hashtags: Array(selectedHashtags),
                    isSponsored: isSponsored,
                    sponsorName: isSponsored && !sponsorName.isEmpty ? sponsorName : nil
                )

                NotificationCenter.default.post(name: .feedCreated, object: nil)
                // 외부에서 후처리 필요 시 호출 (예: routine_executions.feed_id 업데이트)
                onFeedCreated?(createdFeedId)
                showSuccess = true
            } catch {
                errorMessage = "피드 작성에 실패했습니다: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - UIKit ImagePicker (iOS 15 호환 — 앨범 + 카메라 지원)
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 이미지 소스 선택 ActionSheet 뷰
/// 앨범/카메라 선택 → 이미지 선택 → 모더레이션(NSFW 차단 + 얼굴 모자이크 편집)
struct ImageSourcePicker: View {
    @Binding var isPresented: Bool
    var skipFaceMosaic: Bool = false  // 프로필 사진 등 얼굴 모자이크 제외
    var onImageReady: (UIImage) -> Void

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showBlockedAlert = false
    @State private var showProcessing = false
    @State private var moderationMessage = ""
    // 얼굴 모자이크 편집
    @State private var showFaceEditor = false
    @State private var faceEditorImage: UIImage?
    @State private var detectedFaces: [DetectedFace] = []

    var body: some View {
        ZStack {
            Color.clear
                .confirmationDialog("사진 추가", isPresented: $isPresented, titleVisibility: .visible) {
                    Button("앨범에서 선택") {
                        showPhotoPicker = true
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("카메라로 촬영") {
                            showCamera = true
                        }
                    }
                    Button("취소", role: .cancel) {}
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImagePicker(sourceType: .photoLibrary) { image in
                        processImage(image)
                    }
                }
                .sheet(isPresented: $showCamera) {
                    ImagePicker(sourceType: .camera) { image in
                        processImage(image)
                    }
                }
                .alert("업로드 불가", isPresented: $showBlockedAlert) {
                    Button("확인", role: .cancel) {}
                } message: {
                    Text("부적절한 이미지로 판단되어 업로드할 수 없습니다.")
                }
        }
        .overlay {
            if showProcessing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.theme.secondary)
                            .scaleEffect(1.2)
                        Text(moderationMessage)
                            .font(.appCaption)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.theme.neutral.cornerRadius(16))
                }
            }
        }
        .fullScreenCover(isPresented: $showFaceEditor) {
            if let image = faceEditorImage {
                FaceMosaicEditorView(
                    originalImage: image,
                    detectedFaces: $detectedFaces,
                    onConfirm: { finalImage in
                        showFaceEditor = false
                        faceEditorImage = nil
                        onImageReady(finalImage)
                    },
                    onCancel: {
                        showFaceEditor = false
                        faceEditorImage = nil
                    }
                )
            }
        }
    }

    private func processImage(_ image: UIImage) {
        showProcessing = true
        moderationMessage = "이미지 검사 중..."

        Task {
            // Step 1: NSFW 체크
            let nsfwResult = await NSFWDetector.shared.classify(image: image)
            guard nsfwResult.isSafe else {
                await MainActor.run {
                    showProcessing = false
                    showBlockedAlert = true
                }
                return
            }

            // Step 2: 얼굴 모자이크 처리
            if skipFaceMosaic {
                await MainActor.run {
                    showProcessing = false
                    onImageReady(image)
                }
                return
            }

            // 얼굴 감지
            moderationMessage = "얼굴 감지 중..."
            let faces = await FaceMosaicService.shared.detectFacesForEditor(in: image)

            await MainActor.run {
                showProcessing = false
                if faces.isEmpty {
                    // 얼굴 없음 → 바로 통과
                    onImageReady(image)
                } else {
                    // 얼굴 있음 → 편집 화면으로 이동
                    faceEditorImage = image
                    detectedFaces = faces
                    showFaceEditor = true
                }
            }
        }
    }
}
