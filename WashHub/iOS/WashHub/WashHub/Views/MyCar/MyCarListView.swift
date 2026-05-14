import SwiftUI
import Supabase

/// 내차 탭 NavigationStack 의 value-based destination 타입.
/// (FeedListView 의 FeedNavTarget 과 동일 패턴 — CONVENTIONS.md 6.1 참조)
enum MyCarNavTarget: Hashable {
    case stats                    // 세차 통계
    case washLogs(String)         // car id → WashLogListView
}

struct MyCarListView: View {
    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @State private var myCars: [MyCar] = []
    @State private var isLoading = true
    @State private var showAddCar = false
    @State private var showStats = false
    /// 현재 스크롤 위치 — 같은 탭 재탭 시 조건부 scrollTo 판단용 (CONVENTIONS.md 6.1)
    @State private var currentScrollY: CGFloat = 0
    private let scrollToTopThreshold: CGFloat = 200

    var body: some View {
        NavigationStack(path: $navCoordinator.myCarPath) {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.theme.secondary)
                } else if myCars.isEmpty {
                    emptyView
                } else {
                    carList
                }
            }
            .navigationTitle("내차")
            .navigationBarTitleDisplayMode(.inline)
            // value-based 진입 — myCarPath 로 push/pop
            .navigationDestination(for: MyCarNavTarget.self) { target in
                switch target {
                case .stats:
                    WashStatsView()
                case .washLogs(let carId):
                    if let car = myCars.first(where: { $0.id == carId }) {
                        WashLogListView(car: car)
                    }
                }
            }
            .toolbar {
                // 좌측: 세차 통계 진입
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(value: MyCarNavTarget.stats) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.theme.secondary)
                    }
                }
                // 우측: 차량 추가
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCar = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.theme.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddCar) {
                AddMyCarView { await loadCars() }
            }
        }
        .task { await loadCars() }
    }

    @State private var editingCar: MyCar?
    @State private var deletingCar: MyCar?
    @State private var showDeleteConfirm = false

    private var carList: some View {
        ScrollViewReader { scrollProxy in
        ScrollView {
            LazyVStack(spacing: 12) {
                Color.clear.frame(height: 0).id("top")
                ForEach(myCars) { car in
                    // value-based — myCarPath 로 pop 가능
                    NavigationLink(value: MyCarNavTarget.washLogs(car.id)) {
                        MyCarCard(car: car)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingCar = car
                        } label: {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingCar = car
                            showDeleteConfirm = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }

                // 마지막 카드가 탭바 overlay 뒤에 가리지 않도록 가상 빈 아이템
                BottomTabBarSpacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .sheet(item: $editingCar) { car in
            AddMyCarView(editCar: car) { await loadCars() }
        }
        .alert("차량 삭제", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) { deletingCar = nil }
            Button("삭제", role: .destructive) {
                guard let car = deletingCar else { return }
                Task {
                    await deleteCar(car)
                    deletingCar = nil
                }
            }
        } message: {
            Text("\(deletingCar?.carModel ?? "이 차량")을 삭제하시겠습니까?\n관련 세차 기록도 함께 삭제됩니다.")
        }
        // 동일 탭(내차=4) 재탭 → 조건부 스크롤 최상단
        // 200pt 이상 스크롤 다운 했을 때만 scrollTo (sticky toggle 부수 효과 회피)
        .onChange(of: navCoordinator.scrollToTopTokens[4]) { _, _ in
            guard currentScrollY > scrollToTopThreshold else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy.scrollTo("top", anchor: .top)
            }
        }
        // 스크롤 위치 추적 — 조건부 scrollTo 판단용
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            currentScrollY = newValue
        }
        } // ScrollViewReader 닫기
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car")
                .font(.system(size: 60))
                .foregroundColor(.theme.textDisabled)
            Text("등록된 차량이 없습니다")
                .font(.appHeadline3)
                .foregroundColor(.theme.textSecondary)
            Button(action: { showAddCar = true }) {
                Text("내 차 등록하기")
                    .secondaryButtonStyle()
            }
            .padding(.horizontal, 60)
        }
    }

    private func deleteCar(_ car: MyCar) async {
        do {
            // wash_log_equipments → wash_logs 순서로 삭제 (FK 의존성)
            let persistLogs: [WashLog] = try await supabase
                .from("wash_logs")
                .select("id")
                .eq("car_id", value: car.id)
                .execute()
                .value
            if !persistLogs.isEmpty {
                let logIds = persistLogs.map { $0.id }
                try await supabase.from("wash_log_equipments").delete().in("wash_log_id", values: logIds).execute()
                try await supabase.from("wash_logs").delete().eq("car_id", value: car.id).execute()
            }

            // feeds.car_id 참조 해제
            try await supabase.from("feeds").update(["car_id": nil as String?]).eq("car_id", value: car.id).execute()

            // Storage 이미지 삭제
            if let imageUrl = car.imageUrl, imageUrl.contains("my-cars") {
                let session = try await supabase.auth.session
                // RLS 정책의 auth.uid()::text 가 소문자이므로 path 도 소문자로 통일
                let path = "\(session.user.id.uuidString.lowercased())/\(car.id).jpg"
                _ = try? await supabase.storage.from("my-cars").remove(paths: [path])
            }

            // 차량 삭제
            try await supabase.from("my_cars").delete().eq("id", value: car.id).execute()
            // wash_log가 함께 삭제되었으므로 아이콘 캐시도 무효화 → 다음 업데이트 시 재조회
            DynamicIconService.shared.invalidateWashLogCache()
            await DynamicIconService.shared.updateIconIfNeeded()
            await loadCars()
        } catch {
            print("Delete car error: \(error)")
        }
    }

    private func loadCars() async {
        isLoading = true
        do {
            let persistCars: [MyCar] = try await supabase
                .from("my_cars")
                .select()
                .eq("status", value: "ACTIVE")
                .order("is_primary", ascending: false)
                .execute()
                .value
            myCars = persistCars
        } catch {
            print("My cars load error: \(error)")
        }
        isLoading = false
    }
}

struct MyCarCard: View {
    let car: MyCar

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: car.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surface)
                        .overlay(
                            Image(systemName: "car.fill")
                                .foregroundColor(.theme.textDisabled)
                        )
                }
            }
            .frame(width: 80, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(car.carModel)
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)
                    if car.isPrimary {
                        Text("대표")
                            .font(.appSmall)
                            .foregroundColor(.theme.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.theme.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    if let color = car.carColor {
                        Text(color).font(.appSmall).foregroundColor(.theme.textSecondary)
                    }
                    if let year = car.carYear {
                        // String(year) — Int interpolation 시 천 단위 콤마 자동 추가 회피
                        Text("\(String(year))년").font(.appSmall).foregroundColor(.theme.textSecondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.theme.textDisabled)
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - 차량 등록/수정
struct AddMyCarView: View {
    @Environment(\.dismiss) var dismiss
    @State private var carModel = ""
    @State private var carColor = ""
    @State private var carYear = ""
    @State private var nickname = ""
    @State private var isPrimary = false
    @State private var isLoading = false
    @State private var carImage: UIImage?
    @State private var showImageSourcePicker = false
    var editCar: MyCar? = nil
    var onComplete: () async -> Void

    private var isEditMode: Bool { editCar != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 차량 대표 사진
                        VStack(spacing: 8) {
                            Text("차량 사진 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: {
                                hideKeyboard()
                                showImageSourcePicker = true
                            }) {
                                if let carImage = carImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: carImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                        Button(action: { self.carImage = nil }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .offset(x: -8, y: 8)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.theme.surface)
                                        .frame(height: 180)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.theme.textDisabled)
                                                Text("차량 사진을 등록하세요")
                                                    .font(.appSmall)
                                                    .foregroundColor(.theme.textDisabled)
                                            }
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.theme.border, lineWidth: 1)
                                        )
                                }
                            }
                        }

                        TextField("차량 모델명", text: $carModel).washHubTextField()
                        TextField("별명 (선택, 예: 내검둥이)", text: $nickname).washHubTextField()
                        TextField("색상 (선택)", text: $carColor).washHubTextField()
                        TextField("연식 (선택)", text: $carYear).washHubTextField()
                            .keyboardType(.numberPad)
                        Toggle("대표 차량으로 설정", isOn: $isPrimary)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                            .tint(.theme.secondary)
                            .padding(.horizontal, 4)

                        Button(action: isEditMode ? updateCar : addCar) {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text(isEditMode ? "수정" : "등록").primaryButtonStyle()
                            }
                        }
                        .disabled(carModel.isEmpty || isLoading)
                        .opacity(carModel.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture { hideKeyboard() }
            }
            .navigationTitle(isEditMode ? "차량 수정" : "차량 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .onAppear {
                if let car = editCar {
                    carModel = car.carModel
                    carColor = car.carColor ?? ""
                    carYear = car.carYear.map { "\($0)" } ?? ""
                    nickname = car.nickname ?? ""
                    isPrimary = car.isPrimary
                }
            }
            // BottomSheet 가 form 위에 보이도록 overlay 로 부착 (allowsHitTesting 으로 닫혀있을 땐 비활성화)
            .overlay(
                ImageSourcePicker(
                    isPresented: $showImageSourcePicker,
                    onImageReady: { image in
                        carImage = image
                    }
                )
                .allowsHitTesting(showImageSourcePicker)
            )
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func updateCar() {
        guard let car = editCar else { return }
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                var imageUrl: String? = car.imageUrl

                // 새 이미지가 선택된 경우 업로드
                if let image = carImage,
                   let imageData = image.jpegDataUnder(maxDimension: 1600, maxBytes: 2_500_000) {
                    // RLS 정책의 auth.uid()::text 가 소문자이므로 path 도 소문자로 통일
                    let path = "\(session.user.id.uuidString.lowercased())/\(car.id).jpg"
                    try await supabase.storage
                        .from("my-cars")
                        .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
                    imageUrl = try supabase.storage
                        .from("my-cars")
                        .getPublicURL(path: path).absoluteString
                }

                var data: [String: String] = [
                    "car_model": carModel,
                    "is_primary": isPrimary ? "true" : "false",
                    // 별명은 빈 문자열도 허용 (사용자가 별명 지웠을 수도 있음)
                    "nickname": nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
                if !carColor.isEmpty { data["car_color"] = carColor }
                if let year = Int(carYear) { data["car_year"] = "\(year)" }
                if let imageUrl = imageUrl { data["image_url"] = imageUrl }

                try await supabase.from("my_cars").update(data).eq("id", value: car.id).execute()
                await onComplete()
                dismiss()
            } catch {
                print("Update car error: \(error)")
            }
            isLoading = false
        }
    }

    private func addCar() {
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                let carId = UUID().uuidString
                var imageUrl: String?

                // 차량 사진 업로드 — 긴 변 1600px / 2.5MB 이하로 최적화
                if let image = carImage,
                   let imageData = image.jpegDataUnder(maxDimension: 1600, maxBytes: 2_500_000) {
                    // RLS 정책의 auth.uid()::text 가 소문자이므로 path 도 소문자로 통일
                    let path = "\(session.user.id.uuidString.lowercased())/\(carId).jpg"
                    try await supabase.storage
                        .from("my-cars")
                        .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
                    imageUrl = try supabase.storage
                        .from("my-cars")
                        .getPublicURL(path: path).absoluteString
                }

                var data: [String: String] = [
                    "id": carId,
                    "user_id": session.user.id.uuidString,
                    "car_model": carModel,
                    "status": "ACTIVE"
                ]
                if !carColor.isEmpty { data["car_color"] = carColor }
                if let year = Int(carYear) { data["car_year"] = "\(year)" }
                let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNickname.isEmpty { data["nickname"] = trimmedNickname }
                data["is_primary"] = isPrimary ? "true" : "false"
                if let imageUrl = imageUrl { data["image_url"] = imageUrl }

                try await supabase.from("my_cars").insert(data).execute()
                await onComplete()
                dismiss()
            } catch {
                print("Add car error: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - 세차 기록
struct WashLogListView: View {
    let car: MyCar
    @State private var washLogs: [WashLog] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.theme.secondary)
            } else if washLogs.isEmpty {
                Text("세차 기록이 없습니다")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(washLogs) { log in
                            WashLogRow(log: log)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(car.carModel)
        .task {
            do {
                let persistLogs: [WashLog] = try await supabase
                    .from("wash_logs")
                    .select("*, feeds(id, content, thumbnail_url, like_count, comment_count)")
                    .eq("car_id", value: car.id)
                    .eq("status", value: "ACTIVE")
                    .order("wash_date", ascending: false)
                    .execute()
                    .value
                washLogs = persistLogs
            } catch {
                print("Wash logs error: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - 세차 기록 행
struct WashLogRow: View {
    let log: WashLog

    /// 썸네일 URL 유효성 판단
    private var thumbnailURL: URL? {
        guard let raw = log.feeds?.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme,
              scheme.hasPrefix("http") else {
            return nil
        }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일 이미지 (피드가 연결되어 있고 이미지가 있을 때)
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        Rectangle()
                            .fill(Color.theme.surfaceHigh)
                            .overlay(
                                ProgressView()
                                    .tint(.theme.textDisabled)
                            )
                    default:
                        Rectangle()
                            .fill(Color.theme.surfaceHigh)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            // 정보 영역
            VStack(alignment: .leading, spacing: 8) {
                // 날짜 + 피드 바로가기
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.theme.secondary)
                    Text(log.washDate)
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)

                    Spacer()

                    // 피드 연결 뱃지
                    if log.feeds != nil {
                        NavigationLink(destination: FeedDetailView(feedId: log.feeds!.id)) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.image")
                                    .font(.system(size: 11))
                                Text("피드 보기")
                                    .font(.appSmall)
                            }
                            .foregroundColor(.theme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.theme.secondary.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 메모
                if let memo = log.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(2)
                }

                // 피드 본문 발췌 + 좋아요/댓글 카운트
                if let feed = log.feeds {
                    if let content = feed.content, !content.isEmpty {
                        Text(content)
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label("\(feed.likeCount)", systemImage: "heart.fill")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                        Label("\(feed.commentCount)", systemImage: "bubble.right.fill")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }
            .padding(12)
        }
        .cardStyle()
    }
}
