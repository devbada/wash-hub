import SwiftUI
internal import CoreLocation

struct WashIndexCard: View {
    @StateObject private var washIndexService = WashIndexService()
    /// 사용자 현재 위치 — 권한 거부 / 좌표 미확보 시 서울 기본값으로 폴백
    @StateObject private var locationManager = LocationManager()
    @State private var showForecast = false

    var body: some View {
        Group {
            if let index = washIndexService.washIndex {
                indexCard(index)
                    .onTapGesture { showForecast = true }
            } else if washIndexService.isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .task {
            // 1) 위치 권한 분기 — 미정이면 요청, 이미 허용된 상태면 위치 1회 갱신
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
            // 2) 현재 가용한 좌표로 즉시 로드 (좌표 없으면 서울 폴백)
            await reloadIndex()
        }
        // 위치가 들어오면(또는 바뀌면) 해당 좌표로 재조회 — "다른 지역인데 서울로 표시" 버그 방지
        .onChange(of: locationManager.userLocation) { _, _ in
            Task { await reloadIndex() }
        }
        .fullScreenCover(isPresented: $showForecast) {
            WashForecastView(initialLocation: locationManager.userLocation)
        }
    }

    /// 현재 LocationManager 좌표로 세차지수 로드. 좌표 미확보 시 서울 기본값.
    private func reloadIndex() async {
        if let coord = locationManager.userLocation {
            await washIndexService.loadWashIndex(
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        } else {
            await washIndexService.loadWashIndex()
        }
    }

    private var placeholderView: some View {
        HStack {
            Image(systemName: "cloud.sun")
                .font(.system(size: 20))
                .foregroundColor(.theme.textDisabled)
            Text("세차지수를 불러올 수 없습니다")
                .font(.appSmall)
                .foregroundColor(.theme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.theme.surfaceLow)
        .cornerRadius(16)
    }

    private var loadingView: some View {
        HStack {
            ProgressView().tint(.theme.primary)
            Text("세차지수 로딩 중...")
                .font(.appSmall)
                .foregroundColor(.theme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.theme.surfaceLow)
        .cornerRadius(16)
    }

    private func indexCard(_ index: WashIndex) -> some View {
        ZStack {
            // Background Ambient Glow
            HStack {
                Spacer()
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .offset(x: 30, y: -20)
            }

            HStack(alignment: .center, spacing: 16) {
                // 좌측: 텍스트 영역
                VStack(alignment: .leading, spacing: 12) {
                    // WASH INDEX 라벨 + 지역명
                    HStack(spacing: 6) {
                        Text("WASH INDEX")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.theme.textSecondary)

                        if !washIndexService.regionName.isEmpty {
                            Text("·")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.theme.textDisabled)
                            HStack(spacing: 2) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 8))
                                Text(washIndexService.regionName)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.theme.textSecondary)
                        }
                    }

                    // 큰 메시지
                    Text(index.message)
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)
                        .lineLimit(2)

                    // 임박 강수 예보 안내 (내일/모레 비 예보 강할 때만 표시)
                    if let note = index.forecastNote {
                        forecastNoteChip(note)
                    }

                    // 날씨 상세 그리드
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        weatherItem(icon: "cloud.rain", value: "강수 \(index.details.rainProbability)%")
                        weatherItem(icon: "aqi.medium", value: "먼지 \(dustLevel(index.details.fineDust))")
                        weatherItem(icon: "humidity", value: "습도 \(index.details.humidity)%")
                        weatherItem(icon: "thermometer", value: "온도 \(String(format: "%.0f°C", index.details.temperature))")
                    }
                }
                .padding(.leading, 8) // Speed-line 과 텍스트 겹침 방지

                Spacer()

                // 우측: 점수 원형 게이지
                scoreCircle(index)
            }

            // Speed-line (좌측 세로 바)
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(scoreColor(index.score))
                    .frame(width: 2, height: 48)
                Spacer()
            }

        }
        .padding(20)
        .overlay(
            // 하단 우측: 7일 예보 힌트 (카드 밖 overlay로 점수와 겹치지 않게)
            HStack(spacing: 3) {
                Text("7일 예보")
                    .font(.system(size: 10, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.theme.textDisabled)
            .padding(.trailing, 20)
            .padding(.bottom, 6)
            , alignment: .bottomTrailing
        )
        .background(Color.theme.surfaceLow)
        .cornerRadius(16)
        .ambientGlow(color: scoreColor(index.score), radius: 20, opacity: 0.08)
    }

    // MARK: - Score Circle (SVG 스타일)
    private func scoreCircle(_ index: WashIndex) -> some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.theme.surfaceHigh, lineWidth: 8)
                .frame(width: 100, height: 100)

            // Progress
            Circle()
                .trim(from: 0, to: Double(index.score) / 100)
                .stroke(
                    scoreColor(index.score),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            // Score text
            VStack(spacing: -2) {
                Text("\(index.score)")
                    .font(.system(size: 32, weight: .heavy, design: .default))
                    .foregroundColor(scoreColor(index.score))
                Text(index.grade)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(scoreColor(index.score))
            }
        }
        .frame(width: 100, height: 100)
    }

    // MARK: - Forecast Note Chip (임박 강수 예보 보조 문구)
    private func forecastNoteChip(_ note: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cloud.rain.fill")
                .font(.system(size: 10, weight: .bold))
            Text(note)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(.theme.onSurfaceVariant)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(6)
    }

    // MARK: - Weather Item
    private func weatherItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.theme.primary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.theme.textSecondary)
        }
    }

    // MARK: - Helpers
    private func dustLevel(_ value: Int) -> String {
        switch value {
        case 0..<31: return "좋음"
        case 31..<81: return "보통"
        case 81..<151: return "나쁨"
        default: return "매우나쁨"
        }
    }

    /// 세차지수 점수 → 5단계 컬러 스펙트럼
    /// 좋음(그린) → 보통(앰버) → 나쁨(레드) 의 의미 전달용 시맨틱 색.
    /// v3 파스텔 테마와 어울리도록 기존 시트러스/원색을 톤다운한 자연색으로 교체.
    /// (품질 신호이므로 테마와 무관하게 일관 유지 — 에러색만 테마 error 사용)
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100:
            return Color(hex: 0x4F9D69)   // 매우 좋음 — 부드러운 그린
        case 75..<90:
            return Color(hex: 0x74AE74)   // 좋음 — 연한 그린
        case 55..<75:
            return Color(hex: 0xE0A23C)   // 보통 — 부드러운 앰버
        case 35..<55:
            return Color(hex: 0xDD8A5C)   // 별로 — 코랄 오렌지
        default:
            return .theme.error           // 나쁨 — 테마 error
        }
    }
}
