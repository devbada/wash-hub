import SwiftUI
import Supabase

/// 세차 리듬 풀스크린 상세 — 차량 picker + 통계 + 전체 노선도 + 다음 세차 카드 + 기록 리스트
struct WashRhythmDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rhythmService = WashRhythmService()

    let initialCarId: String
    /// 차량 배열은 @State 로 보관 — 주기 변경 후 자체 재 fetch 가능해야 새 effectiveInterval 즉시 반영
    @State private var allCars: [MyCar]

    @State private var selectedCarId: String
    @State private var showSettingSheet = false
    @State private var navigatedFeedId: String?

    init(initialCarId: String, allCars: [MyCar]) {
        self.initialCarId = initialCarId
        _allCars = State(initialValue: allCars)
        _selectedCarId = State(initialValue: initialCarId)
    }

    private var selectedCar: MyCar? {
        allCars.first { $0.id == selectedCarId }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 차량 picker (2대 이상일 때)
                        if allCars.count >= 2 {
                            carPicker
                        }

                        // 통계 요약
                        if let summary = rhythmService.summary {
                            statsSection(summary: summary)

                            // 전체 노선도
                            timelineSection(summary: summary)

                            // 다음 세차 카드
                            if let nextDate = summary.nextWashDate {
                                nextWashCard(date: nextDate, summary: summary)
                            }

                            // 기록 리스트
                            historySection(summary: summary)
                        } else if rhythmService.isLoading {
                            ProgressView()
                                .tint(Color.rhythmAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("세차 리듬")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color.rhythmAccent)
                    }
                }
            }
            .sheet(isPresented: $showSettingSheet) {
                if let car = selectedCar {
                    IntervalSettingSheet(car: car) {
                        // 저장 완료 — Service 가 .washCarIntervalChanged 알림 post.
                        // .onReceive 가 받아서 cars 자체를 fresh fetch + summary reload
                    }
                }
            }
            .task {
                await reload()
            }
            .onChange(of: selectedCarId) { _, _ in
                Task { await reload() }
            }
            // 주기 변경 시 cars 자체를 다시 fetch — selectedCar 의 effective interval 즉시 갱신
            .onReceive(NotificationCenter.default.publisher(for: .washCarIntervalChanged)) { _ in
                Task {
                    await refetchCars()
                    await reload()
                }
            }
            // 피드 작성 → wash_log 자동 생성 가능성 → 리듬 즉시 갱신
            .onReceive(NotificationCenter.default.publisher(for: .feedCreated)) { _ in
                Task {
                    WashRhythmService.invalidateCache(carId: selectedCarId)
                    await reload()
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigatedFeedId != nil },
                set: { if !$0 { navigatedFeedId = nil } }
            )) {
                if let feedId = navigatedFeedId {
                    FeedDetailView(feedId: feedId)
                }
            }
        }
    }

    // MARK: - 차량 picker

    private var carPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allCars) { car in
                    let isSelected = car.id == selectedCarId
                    Button(action: { selectedCarId = car.id }) {
                        Text(car.nickname?.isEmpty == false ? car.nickname! : car.carModel)
                            .font(.appLabel)
                            .foregroundColor(isSelected ? .white : .theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.rhythmAccent : Color.theme.surfaceHigh)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 통계

    private func statsSection(summary: WashRhythmSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("요약")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            HStack(spacing: 10) {
                statCard(
                    label: "평균 주기",
                    value: summary.averageIntervalDays.map { "\($0)일" } ?? "-",
                    color: Color.rhythmAccent
                )
                statCard(
                    label: "최근 간격",
                    value: summary.recentIntervalDays.map { "\($0)일" } ?? "-",
                    color: .theme.tertiary
                )
                statCard(
                    label: "올해 누적",
                    value: "\(summary.washCountThisYear)회",
                    color: .theme.primary
                )
            }
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.appSmall)
                .foregroundColor(.theme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - 노선도

    private func timelineSection(summary: WashRhythmSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("노선도")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            SubwayLineView(stations: summary.stations, compact: false) { station in
                handleStationTap(station)
            }
            .frame(height: 90)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surfaceLowest)
            )
        }
    }

    private func handleStationTap(_ station: WashRhythmStation) {
        switch station.kind {
        case .past:
            if let feedId = station.feedId {
                navigatedFeedId = feedId
            }
            // feedId 가 없는 wash_log 는 별도 동작 없음 (TODO: wash_log 상세 시트)
        case .nextRecommended:
            showSettingSheet = true
        }
    }

    // MARK: - 다음 세차 카드

    private func nextWashCard(date: Date, summary: WashRhythmSummary) -> some View {
        let weather = rhythmService.nextWashWeather
        return VStack(alignment: .leading, spacing: 12) {
            Text("다음 세차")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(dDayLabel(summary.daysUntilNextWash))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color.rhythmAccent)
                    Text(formattedDate(date))
                        .font(.appBodyBold)
                        .foregroundColor(.theme.textPrimary)
                }

                Text(intervalDescription(summary: summary))
                    .font(.appCaption)
                    .foregroundColor(.theme.textSecondary)

                // 날씨 정보 + 신뢰도 별점
                if let w = weather, w.source != .unavailable {
                    Divider().padding(.vertical, 2)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: w.isRainExpected ? "cloud.rain.fill" : "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(w.isRainExpected ? .theme.primary : Color.rhythmAccent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.message)
                                .font(.appCaption)
                                .foregroundColor(.theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 4) {
                                Text("신뢰도")
                                    .font(.system(size: 10))
                                    .foregroundColor(.theme.textDisabled)
                                ForEach(0..<5, id: \.self) { idx in
                                    Image(systemName: idx < w.reliability ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundColor(idx < w.reliability ? Color.rhythmAccent : .theme.textDisabled)
                                }
                                if w.source == .longRange {
                                    Text("(참고용)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.theme.textDisabled)
                                }
                            }
                        }
                        Spacer()
                    }
                } else if rhythmService.isWeatherLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(Color.rhythmAccent).scaleEffect(0.7)
                        Text("날씨 확인 중...")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                    }
                }

                HStack {
                    Spacer()
                    Button(action: { showSettingSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("주기 변경")
                        }
                        .font(.appCaptionMedium)
                        .foregroundColor(Color.rhythmAccent)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.rhythmAccent.opacity(0.08))
            )
        }
    }

    // MARK: - 기록 리스트

    private func historySection(summary: WashRhythmSummary) -> some View {
        let pastStations = summary.stations.filter { $0.kind == .past }.reversed()
        return VStack(alignment: .leading, spacing: 8) {
            Text("기록")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            VStack(spacing: 6) {
                ForEach(Array(pastStations), id: \.id) { station in
                    Button(action: { handleStationTap(station) }) {
                        HStack {
                            Circle()
                                .fill(Color.rhythmAccent)
                                .frame(width: 10, height: 10)
                            Text(formattedFullDate(station.date))
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                            Spacer()
                            if station.feedId != nil {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.rhythmAccent)
                            }
                            if station.feedId != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.theme.textDisabled)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.theme.surfaceLowest)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(station.feedId == nil)
                }
            }
        }
    }

    // MARK: - 데이터 로드

    private func reload() async {
        guard let car = selectedCar else { return }
        await rhythmService.loadRhythm(for: car, forceRefresh: true)
    }

    /// 주기 변경 등으로 my_cars 가 갱신됐을 때 — 차량 배열 자체를 다시 fetch
    /// → selectedCar 의 effectiveWashIntervalDays 가 새 값으로 즉시 반영됨
    private func refetchCars() async {
        do {
            let session = try await supabase.auth.session
            let persistCars: [MyCar] = try await supabase
                .from("my_cars")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "ACTIVE")
                .order("is_primary", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            allCars = persistCars
        } catch {
            print("WashRhythmDetailView refetchCars error: \(error)")
        }
    }

    // MARK: - 포맷터

    private func dDayLabel(_ days: Int?) -> String {
        guard let days = days else { return "-" }
        if days < 0 { return "D+\(-days)" }
        if days == 0 { return "D-Day" }
        return "D-\(days)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. M. d (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    private func intervalDescription(summary: WashRhythmSummary) -> String {
        let days = summary.effectiveIntervalDays
        return summary.isAutoMode
            ? "자동 추천 \(days)일 주기"
            : "\(days)일 주기 (직접 설정)"
    }
}
