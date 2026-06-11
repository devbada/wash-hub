import SwiftUI
internal import CoreLocation

/// 7일 세차예측 풀스크린 시트
struct WashForecastView: View {
    /// true: 풀스크린 커버, false: 외부 NavigationStack push.
    var embedInNavigation: Bool = true
    /// WashIndexCard에서 전달한 위치. 없으면 자체 LocationManager로 보강한다.
    var initialLocation: EquatableCoordinate? = nil

    @StateObject private var washIndexService = WashIndexService()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedForecastID: String?
    @Environment(\.dismiss) private var dismiss

    private var currentCoord: EquatableCoordinate? {
        initialLocation ?? locationManager.userLocation
    }

    private var bestForecast: DailyForecast? {
        washIndexService.forecast.max(by: { $0.score < $1.score })
    }

    private var selectedForecast: DailyForecast? {
        if let selectedForecastID,
           let selected = washIndexService.forecast.first(where: { $0.id == selectedForecastID }) {
            return selected
        }
        return bestForecast ?? washIndexService.forecast.first
    }

    var body: some View {
        Group {
            if embedInNavigation {
                NavigationView { content }
            } else {
                content
            }
        }
        .task {
            if initialLocation == nil {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    locationManager.requestPermission()
                case .authorizedWhenInUse, .authorizedAlways:
                    if locationManager.userLocation == nil {
                        locationManager.requestLocation()
                    }
                default:
                    break
                }
            }
            await reloadForecast()
        }
        .onChange(of: locationManager.userLocation) { _, _ in
            Task { await reloadForecast() }
        }
    }

    private func reloadForecast(forceRefresh: Bool = false) async {
        if let coord = currentCoord {
            await washIndexService.loadForecast(
                latitude: coord.latitude,
                longitude: coord.longitude,
                forceRefresh: forceRefresh
            )
        } else {
            await washIndexService.loadForecast(forceRefresh: forceRefresh)
        }

        if selectedForecastID == nil
            || !washIndexService.forecast.contains(where: { $0.id == selectedForecastID }) {
            selectedForecastID = bestForecast?.id ?? washIndexService.forecast.first?.id
        }
    }

    private var content: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if washIndexService.isForecastLoading {
                loadingView
            } else if washIndexService.forecast.isEmpty {
                emptyView
            } else {
                forecastContent
            }
        }
        .navigationTitle("세차 예측")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if embedInNavigation {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.theme.textPrimary)
                    }
                }
            }
        }
    }

    private var forecastContent: some View {
        // TODO-minam: 실제 기기에서 작은 화면의 7일 타임라인 터치 영역과 한글 줄바꿈을 확인해야 합니다.
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                locationHeader
                    .padding(.bottom, 24)

                if let bestForecast {
                    bestDayHero(bestForecast)
                }

                sectionHeader
                    .padding(.top, 32)
                    .padding(.bottom, 12)

                forecastTimeline

                if let selectedForecast {
                    selectedDayDetail(selectedForecast)
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Location

    private var locationHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(washIndexService.regionName.isEmpty ? "서울" : washIndexService.regionName)
                    .font(.appSmallBold)
            }
            .foregroundColor(.theme.textSecondary)

            Spacer()

            Text("기상청 예보")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.theme.textDisabled)
        }
    }

    // MARK: - Best Day Hero

    private func bestDayHero(_ day: DailyForecast) -> some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color.theme.textPrimary, Color.theme.primaryDim],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .stroke(Color.theme.accentBright.opacity(0.16), lineWidth: 1)
                .frame(width: 180, height: 180)
                .offset(x: 58, y: 68)

            Circle()
                .stroke(Color.theme.accentBright.opacity(0.08), lineWidth: 24)
                .frame(width: 128, height: 128)
                .offset(x: 48, y: 62)

            VStack(alignment: .leading, spacing: 0) {
                Text("이번 주 추천 · \(compactDayLabel(day))")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.theme.accentBright)

                Text("이번 주엔 이날이 좋아요")
                    .font(.appSmall)
                    .foregroundColor(Color.theme.onPrimary.opacity(0.62))
                    .padding(.top, 28)

                Text(heroTitle(day))
                    .font(.headline(28))
                    .foregroundColor(.theme.onPrimary)
                    .tracking(-0.7)
                    .padding(.top, 4)

                HStack(alignment: .bottom, spacing: 16) {
                    Text(heroMessage(day))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.theme.onPrimary.opacity(0.7))
                        .lineSpacing(4)

                    Spacer(minLength: 8)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(day.score)")
                            .font(.headline(42))
                        Text("점")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.theme.accentBright)
                }
                .padding(.top, 24)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, minHeight: 228, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Forecast Timeline

    private var sectionHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("이번 주 날씨")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            Spacer()

            Text("날짜별 세차지수")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.theme.textDisabled)
        }
    }

    private var forecastTimeline: some View {
        HStack(spacing: 4) {
            ForEach(washIndexService.forecast) { day in
                timelineDay(day)
            }
        }
    }

    private func timelineDay(_ day: DailyForecast) -> some View {
        let isSelected = selectedForecast?.id == day.id

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedForecastID = day.id
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(compactDayLabel(day))
                        .font(.system(size: 10, weight: .bold))

                    Image(systemName: day.weatherIcon)
                        .font(.system(size: 18))
                        .foregroundColor(weatherIconColor(day))
                        .frame(height: 22)

                    Text("\(day.score)")
                        .font(.headline(14))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                if day.rainProbability >= 30 || day.pty > 0 {
                    Circle()
                        .fill(Color.theme.error)
                        .frame(width: 5, height: 5)
                        .padding(7)
                }
            }
            .foregroundColor(isSelected ? .theme.onPrimary : .theme.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? Color.theme.textPrimary : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Day Detail

    private func selectedDayDetail(_ day: DailyForecast) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(fullDateLabel(day))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(.theme.secondary)

                    Text(detailTitle(day))
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)
                }

                Spacer(minLength: 12)

                Text("\(day.grade) · \(day.score)점")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(statusColor(day))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(statusColor(day).opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                metric(title: "강수", value: "\(day.rainProbability)%")
                metric(title: "미세먼지", value: day.dustGrade)
                metric(title: "기온", value: "\(day.tempMin)° / \(day.tempMax)°")
            }
            .padding(.top, 24)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: recommendationIcon(day))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.top, 2)

                Text(recommendation(day))
                    .font(.system(size: 12, weight: .semibold))
                    .lineSpacing(3)
            }
            .foregroundColor(statusColor(day))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(statusColor(day).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 14)
        }
        .padding(.top, 28)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.theme.outlineVariant.opacity(0.7))
                .frame(height: 1)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.theme.textSecondary)

            Text(value)
                .font(.headline(14))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background(Color.theme.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Loading / Empty

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.theme.secondary)
            Text("날씨를 확인하고 있어요")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.bolt")
                .font(.system(size: 40))
                .foregroundColor(.theme.textDisabled)
            Text("날씨를 불러오지 못했어요")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
            Button("다시 시도") {
                Task { await reloadForecast(forceRefresh: true) }
            }
            .font(.appCaptionBold)
            .foregroundColor(.theme.secondary)
        }
    }

    // MARK: - Helpers

    private func compactDayLabel(_ day: DailyForecast) -> String {
        day.dayLabel == "오늘" ? "오늘" : day.dayOfWeek
    }

    private func fullDateLabel(_ day: DailyForecast) -> String {
        let parts = day.date.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let date = Int(parts[2]) else {
            return "\(day.shortDate) \(day.dayOfWeek)요일"
        }
        return "\(month)월 \(date)일 \(day.dayOfWeek)요일"
    }

    private func heroTitle(_ day: DailyForecast) -> String {
        "\(day.dayOfWeek)요일,\n\(day.score >= 60 ? "세차하기 좋아요." : "세차는 잠시 미뤄요.")"
    }

    private func heroMessage(_ day: DailyForecast) -> String {
        if day.rainProbability >= 30 || day.pty > 0 {
            return "비가 올 수 있어요.\n세차 전 예보를 한 번 더 봐주세요."
        }
        if day.dustGrade == "좋음" {
            return "비 소식 없고 공기도 좋아요.\n오전에 세차하기 좋은 날이에요."
        }
        return "날씨는 무난해요.\n더워지기 전에 시작하세요."
    }

    private func detailTitle(_ day: DailyForecast) -> String {
        switch day.score {
        case 80...:
            return "세차하기 딱 좋은 날이에요"
        case 60..<80:
            return "가볍게 세차하기 괜찮아요"
        case 40..<60:
            return "세차 전에 날씨를 확인해 주세요"
        default:
            return "오늘은 미루는 게 나아요"
        }
    }

    private func recommendation(_ day: DailyForecast) -> String {
        if day.pty > 0 || day.rainProbability >= 60 {
            return "비가 올 가능성이 높아요. 오늘은 실내 관리나 장비 정리만 해도 충분해요."
        }
        if day.rainProbability >= 30 {
            return "비가 올 수 있어요. 세차한다면 오염만 가볍게 씻어내세요."
        }
        if day.score >= 80 {
            return "오늘은 세차하기 좋아요. 햇볕이 강해지기 전인 오전을 추천해요."
        }
        if day.score >= 60 {
            return "크게 무리 없는 날씨예요. 더워지기 전에 마치는 게 좋아요."
        }
        return "날씨가 바뀔 수 있어요. 출발 전에 예보를 한 번 더 확인해 주세요."
    }

    private func statusColor(_ day: DailyForecast) -> Color {
        switch day.score {
        case 60...:
            return .theme.secondary
        case 40..<60:
            return .theme.accent
        default:
            return .theme.error
        }
    }

    private func recommendationIcon(_ day: DailyForecast) -> String {
        if day.score >= 60 {
            return "checkmark"
        }
        return day.score >= 40 ? "exclamationmark.triangle.fill" : "exclamationmark"
    }

    private func weatherIconColor(_ day: DailyForecast) -> Color {
        // TODO-minam: 실제 기기에서 선택·비선택 상태 모두 날씨 아이콘이 선명한지 확인해 주세요.
        if day.pty == 3 {
            return Color(hex: 0x67B7DC)
        }
        if day.pty > 0 {
            return Color(hex: 0x4A90D9)
        }
        switch day.sky {
        case 1:
            return Color(hex: 0xE6A23C)
        case 3:
            return Color(hex: 0xD6A34A)
        default:
            return Color(hex: 0x8793A3)
        }
    }
}
