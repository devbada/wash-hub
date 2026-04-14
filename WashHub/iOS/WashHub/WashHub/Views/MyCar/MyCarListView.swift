import SwiftUI
import Supabase

struct MyCarListView: View {
    @State private var myCars: [MyCar] = []
    @State private var isLoading = true
    @State private var showAddCar = false
    @State private var showStats = false

    var body: some View {
        NavigationView {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: WashStatsView()) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.theme.secondary)
                    }
                }
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
        .navigationViewStyle(.stack)
        .task { await loadCars() }
    }

    private var carList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(myCars) { car in
                    NavigationLink(destination: WashLogListView(car: car)) {
                        MyCarCard(car: car)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
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
                        Text("\(year)년").font(.appSmall).foregroundColor(.theme.textSecondary)
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

// MARK: - 차량 등록
struct AddMyCarView: View {
    @Environment(\.dismiss) var dismiss
    @State private var carModel = ""
    @State private var carColor = ""
    @State private var carYear = ""
    @State private var isPrimary = false
    @State private var isLoading = false
    @State private var carImage: UIImage?
    @State private var showImageSourcePicker = false
    var onComplete: () async -> Void

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
                        TextField("색상 (선택)", text: $carColor).washHubTextField()
                        TextField("연식 (선택)", text: $carYear).washHubTextField()
                            .keyboardType(.numberPad)
                        Toggle("대표 차량으로 설정", isOn: $isPrimary)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                            .tint(.theme.secondary)
                            .padding(.horizontal, 4)

                        Button(action: addCar) {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("등록").primaryButtonStyle()
                            }
                        }
                        .disabled(carModel.isEmpty || isLoading)
                        .opacity(carModel.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture { hideKeyboard() }
            }
            .navigationTitle("차량 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .background(
                ImageSourcePicker(
                    isPresented: $showImageSourcePicker,
                    onImageReady: { image in
                        carImage = image
                    }
                )
            )
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
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
                    let path = "\(session.user.id.uuidString)/\(carId).jpg"
                    try await supabase.storage
                        .from("my-cars")
                        .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg", upsert: true))
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
                    .select("*, feeds(id, title, thumbnail_url, like_count, comment_count)")
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

                // 피드 제목 + 좋아요/댓글 카운트
                if let feed = log.feeds {
                    if let title = feed.title, !title.isEmpty {
                        Text(title)
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
