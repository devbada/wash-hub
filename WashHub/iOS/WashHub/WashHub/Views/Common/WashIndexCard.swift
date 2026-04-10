import SwiftUI

struct WashIndexCard: View {
    @StateObject private var washIndexService = WashIndexService()

    var body: some View {
        Group {
            if washIndexService.isLoading {
                loadingView
            } else if let index = washIndexService.washIndex {
                indexCard(index)
            }
        }
        .task {
            await washIndexService.loadWashIndex()
        }
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
                    // WASH INDEX 라벨
                    Text("WASH INDEX")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.theme.textSecondary)

                    // 큰 메시지
                    Text(index.message)
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)
                        .lineLimit(2)

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

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .theme.secondary
        case 60..<80: return .theme.primary
        case 40..<60: return Color.yellow
        default: return .theme.error
        }
    }
}
