import SwiftUI

struct WashIndexCard: View {
    @StateObject private var washIndexService = WashIndexService()
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
            await washIndexService.loadWashIndex()
        }
        .fullScreenCover(isPresented: $showForecast) {
            WashForecastView()
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
                    .fill(Color.theme.secondary.opacity(0.1))
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
    /// 빨강(나쁨) → 주황 → 노랑 → 라임 → 짙은 Citrus(아주 좋음)
    /// 디자인 시스템(Carbon & Citrus)의 기조색을 따르되 시각 식별성을 위해 중간톤은 자연색 사용
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100:
            // 매우 좋음 — 짙은 Citrus (브랜드 시그니처)
            return Color(red: 101/255, green: 163/255, blue: 13/255)   // #65A30D
        case 75..<90:
            // 좋음 — 밝은 Citrus
            return Color(red: 132/255, green: 204/255, blue: 22/255)   // #84CC16
        case 55..<75:
            // 보통 — 따뜻한 노랑
            return Color(red: 234/255, green: 179/255, blue: 8/255)    // #EAB308 (Tailwind yellow-500)
        case 35..<55:
            // 별로 — 주황
            return Color(red: 249/255, green: 115/255, blue: 22/255)   // #F97316 (Tailwind orange-500)
        default:
            // 나쁨 — 짙은 빨강 (디자인 시스템 error)
            return .theme.error                                         // #DC2626
        }
    }
}
