import SwiftUI
import Supabase

/// 내차 탭 NavigationStack 의 value-based destination 타입.
/// (FeedListView 의 FeedNavTarget 과 동일 패턴 — CONVENTIONS.md 6.1 참조)
enum MyCarNavTarget: Hashable {
    case stats                    // 세차 통계
    case washLogs(String)         // car id → WashLogListView
    case vehicleDetail(String)    // car id → VehicleDetailView (v2)
    case feedDetail(String)       // feed id → FeedDetailView (세차 기록의 '피드 보기')
}

struct MyCarListView: View {
    /// 좌상단 햄버거 → 드로어 열기
    var onMenu: () -> Void = {}

    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @StateObject private var rhythmService = WashRhythmService()
    @State private var myCars: [MyCar] = []
    /// v2 — 세차 통계 카드 / 최근 세차 카드용 세차 기록
    @State private var washLogs: [WashLog] = []
    @State private var isLoading = true
    @State private var showAddCar = false
    @State private var showStats = false
    /// 녹색 "다음 세차" 카드 → 세차 리듬 상세 시트
    @State private var showRhythmDetail = false
    /// 현재 스크롤 위치 — 같은 탭 재탭 시 조건부 scrollTo 판단용 (CONVENTIONS.md 6.1)
    @State private var currentScrollY: CGFloat = 0
    private let scrollToTopThreshold: CGFloat = 200

    var body: some View {
        NavigationStack(path: $navCoordinator.myCarPath) {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.theme.secondary)
                        Spacer()
                    } else if myCars.isEmpty {
                        Spacer()
                        emptyView
                        Spacer()
                    } else {
                        carList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // value-based 진입 — myCarPath 로 push/pop
            .navigationDestination(for: MyCarNavTarget.self) { target in
                switch target {
                case .stats:
                    WashStatsView()
                case .washLogs(let carId):
                    if let car = myCars.first(where: { $0.id == carId }) {
                        WashLogListView(car: car)
                    }
                case .vehicleDetail(let carId):
                    if let car = myCars.first(where: { $0.id == carId }) {
                        VehicleDetailView(
                            car: car,
                            onEdit: { editingCar = car },
                            onDelete: { Task { await deleteCar(car) } }
                        )
                    }
                case .feedDetail(let feedId):
                    FeedDetailView(feedId: feedId)
                }
            }
            .sheet(isPresented: $showAddCar) {
                AddMyCarView { await reloadAll() }
            }
        }
        .task { await reloadAll() }
    }

    // MARK: - 커스텀 헤더 (☰ + 내차 + 추가)
    private var header: some View {
        HStack(spacing: 10) {
            Button(action: { onMenu() }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.theme.textPrimary)
            }
            Text("내차")
                .font(.appHeadline1)
                .foregroundColor(.theme.textPrimary)
            Spacer()
            Button(action: { showAddCar = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.theme.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.theme.surface)
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
                    NavigationLink(value: MyCarNavTarget.vehicleDetail(car.id)) {
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

                // v2 — 내 세차 리듬 (다크 카드, 통계 요약) → 전체 통계 화면
                rhythmStatsCard

                // v2 — 다음 세차 추천 (녹색 카드) → 세차 리듬 상세
                nextWashCard

                // v2 — 최근 세차 카드
                recentWashSection

                // 마지막 카드가 탭바 overlay 뒤에 가리지 않도록 가상 빈 아이템
                BottomTabBarSpacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .sheet(item: $editingCar) { car in
            AddMyCarView(editCar: car) { await reloadAll() }
        }
        .sheet(isPresented: $showRhythmDetail) {
            if let car = primaryCar {
                WashRhythmDetailView(initialCarId: car.id, allCars: myCars)
            }
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
            await reloadAll()
        } catch {
            print("Delete car error: \(error)")
        }
    }

    // MARK: - v2 통계/리듬/최근 세차

    private var primaryCar: MyCar? { myCars.first }

    private var currentYearText: String {
        String(Calendar.current.component(.year, from: Date()))
    }
    private var currentYearMonth: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }
    private var totalWashCount: Int { washLogs.count }
    private var thisMonthWashCount: Int {
        washLogs.filter { $0.washDate.hasPrefix(currentYearMonth) }.count
    }
    private var thisYearWashCount: Int {
        washLogs.filter { $0.washDate.hasPrefix(currentYearText) }.count
    }

    /// 내 세차 리듬 — 다크 카드(통계 요약). 탭하면 전체 통계 화면으로 진입.
    private var rhythmStatsCard: some View {
        NavigationLink(value: MyCarNavTarget.stats) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(currentYearText)년 · 잘하고 있어요")
                            .font(.appLabelSmall)
                            .fontWeight(.heavy)
                            .foregroundColor(.theme.tertiary)
                        Text("내 세차 리듬")
                            .font(.appHeadline3)
                            .foregroundColor(.theme.onPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.theme.onPrimary)
                }
                HStack(spacing: 10) {
                    statCell(value: "\(totalWashCount)", label: "총 세차회")
                    statCell(value: averageIntervalText, label: "평균 주기")
                    statCell(value: monthlyAverageText, label: "월 평균회")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.theme.primary)
            )
        }
        .buttonStyle(.plain)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline(24))
                .foregroundColor(.theme.onPrimary)
            Text(label)
                .font(.appSmall)
                .foregroundColor(.theme.onPrimary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    /// 평균 세차 주기 — 리듬 데이터 기반, 없으면 "-"
    private var averageIntervalText: String {
        guard let avg = rhythmService.summary?.averageIntervalDays else { return "-" }
        return "\(avg)일"
    }

    /// 월 평균 세차 횟수 — 첫 세차 이후 경과 개월 기준 (소수 1자리)
    private var monthlyAverageText: String {
        let dates = washLogs.compactMap { parseWashDate($0.washDate) }
        guard !dates.isEmpty, let oldest = dates.min() else { return "-" }
        let months = Calendar.current.dateComponents([.month], from: oldest, to: Date()).month ?? 0
        let effectiveMonths = max(months, 1)
        let avg = Double(washLogs.count) / Double(effectiveMonths)
        return String(format: "%.1f", avg)
    }

    /// "yyyy-MM-dd" 문자열을 Date 로 파싱
    private func parseWashDate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(raw.prefix(10)))
    }

    /// 다음 세차 추천 — 녹색 카드. 탭하면 세차 리듬 상세(시트) 진입.
    private var nextWashCard: some View {
        Button(action: { showRhythmDetail = true }) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundColor(.theme.secondary)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.theme.surfaceLowest)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if let summary = rhythmService.summary, let nextDate = summary.nextWashDate {
                        Text(dDayText(summary.daysUntilNextWash))
                            .font(.appLabelSmall)
                            .fontWeight(.heavy)
                            .kerning(1.2)
                            .foregroundColor(.theme.secondary)
                        Text("다음 세차는 \(nextWashDateText(nextDate))")
                            .font(.appBodyBold)
                            .foregroundColor(.theme.textPrimary)
                        Text(nextWashSubtitle)
                            .font(.appSmall)
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("다음 세차")
                            .font(.appBodyBold)
                            .foregroundColor(.theme.textPrimary)
                        Text("첫 세차를 기록하면 추천일이 표시돼요")
                            .font(.appSmall)
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.theme.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.theme.accent.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private func dDayText(_ daysUntil: Int?) -> String {
        guard let d = daysUntil else { return "D-DAY" }
        if d < 0 { return "D+\(-d)" }
        if d == 0 { return "D-DAY" }
        return "D-\(d)"
    }

    private func nextWashDateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }

    /// 녹색 카드 보조 문구 — 날씨 메시지 있으면 사용, 없으면 기본 문구
    private var nextWashSubtitle: String {
        if let w = rhythmService.nextWashWeather, w.source != .unavailable {
            return w.message
        }
        return "지난 기록을 보니 이쯤이 좋아요"
    }

    /// 최근 세차 카드
    @ViewBuilder
    private var recentWashSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 세차")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                if let carId = primaryCar?.id, washLogs.first != nil {
                    NavigationLink(value: MyCarNavTarget.washLogs(carId)) {
                        Text("전체보기")
                            .font(.appSmallBold)
                            .foregroundColor(.theme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let log = washLogs.first, let carId = primaryCar?.id {
                NavigationLink(value: MyCarNavTarget.washLogs(carId)) {
                    recentWashCard(log)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "drop")
                        .foregroundColor(.theme.textDisabled)
                    Text("아직 세차 기록이 없어요. 첫 세차를 남겨볼까요?")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.theme.surfaceLow)
                )
            }
        }
    }

    private func recentWashCard(_ log: WashLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.theme.accentBright, Color.theme.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "drop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.theme.onAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(log.washDate)
                    .font(.appLabelSmall)
                    .fontWeight(.heavy)
                    .foregroundColor(.theme.textSecondary)
                Text(log.memo?.isEmpty == false ? log.memo! : "세차 완료")
                    .font(.appCaptionBold)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.theme.textDisabled)
        }
        .padding(14)
        .cardStyle()
    }

    /// 차량 + 세차 기록 동시 로드
    private func reloadAll() async {
        await loadCars()
        await loadWashLogs()
        await loadRhythm()
    }

    /// 대표 차량의 세차 리듬 로드 — 다크 카드의 평균 주기 / 녹색 다음 세차 카드용
    private func loadRhythm() async {
        guard let car = primaryCar else { return }
        await rhythmService.loadRhythm(for: car)
    }

    private func loadWashLogs() async {
        let carIds = myCars.map { $0.id }
        guard !carIds.isEmpty else {
            washLogs = []
            return
        }
        do {
            let persistLogs: [WashLog] = try await supabase
                .from("wash_logs")
                .select("*, feeds(id, content, thumbnail_url, like_count, comment_count)")
                .in("car_id", values: carIds)
                .eq("status", value: "ACTIVE")
                .order("wash_date", ascending: false)
                .execute()
                .value
            washLogs = persistLogs
        } catch {
            print("Wash logs load error: \(error)")
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
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: car.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    LinearGradient(
                        colors: [
                            Color(red: 71/255, green: 85/255, blue: 105/255),
                            Color(red: 30/255, green: 41/255, blue: 59/255)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "car.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.5))
                    )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                // 대표 배지 — 차명 위에 별도 행으로 노출
                if car.isPrimary {
                    Text("대표")
                        .font(.appLabelSmall)
                        .fontWeight(.heavy)
                        .kerning(1.0)
                        .foregroundColor(.theme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.theme.accent.opacity(0.12))
                        )
                }
                Text(car.carModel)
                    .font(.appHeadline2)
                    .foregroundColor(.theme.textPrimary)
                Text(carSubtitle)
                    .font(.appCaption)
                    .foregroundColor(.theme.textSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.theme.surfaceLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.theme.outlineVariant, lineWidth: 1)
        )
    }

    /// "아마존 그레이 · 2021년" 형태 부제
    private var carSubtitle: String {
        var parts: [String] = []
        if let color = car.carColor, !color.isEmpty { parts.append(color) }
        // String(year) — Int interpolation 시 천 단위 콤마 자동 추가 회피
        if let year = car.carYear { parts.append("\(String(year))년") }
        return parts.joined(separator: " · ")
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

                    // 피드 연결 뱃지 — value-based push (destination-based 는 path 연동 불안정)
                    if let linkedFeed = log.feeds {
                        NavigationLink(value: MyCarNavTarget.feedDetail(linkedFeed.id)) {
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
                                    .fill(Color.theme.accent.opacity(0.12))
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
