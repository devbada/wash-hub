import SwiftUI
import Supabase

/// 마이페이지 상단의 "내 세차 리듬" 요약 카드
///
/// - 차량 picker (여러 대일 때만)
/// - 평균/최근 간격 뱃지
/// - 미니 노선도 (compact)
/// - 다음 세차 D-N 카드
/// - 탭하면 풀스크린 상세(`WashRhythmDetailView`) 진입
struct WashRhythmCard: View {
    @StateObject private var rhythmService = WashRhythmService()
    @State private var cars: [MyCar] = []
    @State private var selectedCarId: String?
    @State private var isInitialLoading = true

    @State private var showDetail = false

    /// 현재 선택된 차량
    private var selectedCar: MyCar? {
        cars.first { $0.id == selectedCarId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Text("내 세차 리듬")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                if selectedCar != nil {
                    Button(action: { showDetail = true }) {
                        HStack(spacing: 2) {
                            Text("상세")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.appCaptionMedium)
                        .foregroundColor(Color.rhythmAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 차량 picker (2대 이상일 때)
            if cars.count >= 2 {
                carPicker
            }

            // 콘텐츠 — 로딩 / 빈 상태 / 정상
            if isInitialLoading {
                loadingView
            } else if cars.isEmpty {
                emptyCarsView
            } else if let summary = rhythmService.summary, !summary.stations.isEmpty {
                rhythmContent(summary: summary)
            } else if rhythmService.summary?.stations.isEmpty == true || rhythmService.summary == nil {
                emptyRhythmView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.surfaceLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.theme.outline.opacity(0.5), lineWidth: 1)
        )
        .task {
            await loadCars()
        }
        // 주기 변경 시 cars 재로드 → 새 effectiveInterval 로 화면 즉시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .washCarIntervalChanged)) { _ in
            Task {
                await loadCars()
                await reload()
            }
        }
        // 피드 작성 시 wash_log 가 자동 생성될 수 있음 → 캐시 무효화 후 리듬 즉시 갱신
        // 차량 미선택 피드는 wash_log 없지만 reload 호출은 무해 (캐시 hit 시 빠름)
        .onReceive(NotificationCenter.default.publisher(for: .feedCreated)) { _ in
            Task {
                if let carId = selectedCarId {
                    WashRhythmService.invalidateCache(carId: carId)
                }
                await reload()
            }
        }
        .sheet(isPresented: $showDetail) {
            if let car = selectedCar {
                WashRhythmDetailView(initialCarId: car.id, allCars: cars)
            }
        }
    }

    // MARK: - 차량 picker

    private var carPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cars) { car in
                    let isSelected = car.id == selectedCarId
                    Button(action: {
                        selectedCarId = car.id
                        Task { await reload() }
                    }) {
                        Text(car.nickname?.isEmpty == false ? car.nickname! : car.carModel)
                            .font(.appLabel)
                            .foregroundColor(isSelected ? .white : .theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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

    // MARK: - 정상 콘텐츠

    private func rhythmContent(summary: WashRhythmSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 평균/최근 뱃지
            HStack(spacing: 10) {
                if let avg = summary.averageIntervalDays {
                    statBadge(icon: "calendar", label: "평균 \(avg)일")
                }
                if let recent = summary.recentIntervalDays {
                    statBadge(icon: "clock", label: "최근 \(recent)일")
                }
                Spacer()
            }

            // 미니 노선도
            SubwayLineView(stations: summary.stations, compact: true) { _ in
                showDetail = true   // 정거장 탭 시 상세 진입
            }
            .frame(height: 50)

            // 다음 세차 D-N
            if let nextDate = summary.nextWashDate {
                nextWashRow(date: nextDate, daysUntil: summary.daysUntilNextWash)
            }
        }
    }

    private func statBadge(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color.rhythmAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.rhythmAccent.opacity(0.10))
        )
    }

    private func nextWashRow(date: Date, daysUntil: Int?) -> some View {
        let weather = rhythmService.nextWashWeather
        return HStack(spacing: 10) {
            Image(systemName: weather?.isRainExpected == true ? "cloud.rain.fill" : "drop.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.rhythmAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDDay(daysUntil: daysUntil) + " · " + formattedDate(date))
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.textPrimary)
                if let w = weather, w.source != .unavailable {
                    Text(w.message)
                        .font(.system(size: 11))
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("다음 세차 추천일")
                        .font(.system(size: 11))
                        .foregroundColor(.theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.rhythmAccent.opacity(0.06))
        )
    }

    // MARK: - 빈 상태

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView().tint(Color.rhythmAccent)
            Spacer()
        }
        .frame(height: 80)
    }

    private var emptyCarsView: some View {
        VStack(spacing: 6) {
            Image(systemName: "car.circle")
                .font(.system(size: 32))
                .foregroundColor(.theme.textDisabled)
            Text("내 차를 등록하면 세차 리듬이 시작돼요")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var emptyRhythmView: some View {
        VStack(spacing: 6) {
            Image(systemName: "drop")
                .font(.system(size: 28))
                .foregroundColor(.theme.textDisabled)
            Text("첫 세차를 기록하면 다음 추천일이 표시돼요")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - 데이터 로드

    private func loadCars() async {
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

            cars = persistCars
            // 첫 진입 시 primary 차량 또는 첫 차량 선택
            if selectedCarId == nil {
                selectedCarId = persistCars.first(where: { $0.isPrimary })?.id ?? persistCars.first?.id
            }
            isInitialLoading = false
            await reload()
        } catch {
            print("WashRhythmCard cars load error: \(error)")
            isInitialLoading = false
        }
    }

    private func reload() async {
        guard let car = selectedCar else { return }
        await rhythmService.loadRhythm(for: car)
    }

    // MARK: - 포맷터

    private func formattedDDay(daysUntil: Int?) -> String {
        guard let days = daysUntil else { return "" }
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
}
