import SwiftUI

/// 7일 세차예측 풀스크린 시트
struct WashForecastView: View {
    @StateObject private var washIndexService = WashIndexService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                if washIndexService.isForecastLoading {
                    loadingView
                } else if washIndexService.forecast.isEmpty {
                    emptyView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // 헤더 요약
                            headerSection
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 16)

                            // 미니 스코어 바 (7일 한눈에)
                            miniScoreBar
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)

                            // 일별 상세 카드
                            LazyVStack(spacing: 12) {
                                ForEach(washIndexService.forecast) { day in
                                    forecastDayCard(day)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("세차 예측")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }
        }
        .task {
            await washIndexService.loadForecast()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 지역명 표시
            if !washIndexService.regionName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(washIndexService.regionName)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.theme.textSecondary)
            }

            if let best = washIndexService.forecast.max(by: { $0.score < $1.score }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.theme.secondary)
                    Text("이번 주 최적의 세차일")
                        .font(.appCaptionBold)
                        .foregroundColor(.theme.secondary)
                }

                Text(bestDayText(best))
                    .font(.appHeadline2)
                    .foregroundColor(.theme.textPrimary)

                Text(best.message)
                    .font(.appCaption)
                    .foregroundColor(.theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mini Score Bar
    private var miniScoreBar: some View {
        HStack(spacing: 6) {
            ForEach(washIndexService.forecast) { day in
                VStack(spacing: 6) {
                    Text(day.dayLabel.isEmpty ? day.dayOfWeek : day.dayLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(
                            day.dayLabel == "오늘"
                                ? .theme.secondary
                                : .theme.textSecondary
                        )

                    ZStack {
                        Circle()
                            .fill(scoreColor(day.score).opacity(0.15))
                            .frame(width: 38, height: 38)

                        Text("\(day.score)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(scoreColor(day.score))
                    }

                    Text(day.shortDate)
                        .font(.system(size: 9))
                        .foregroundColor(.theme.textDisabled)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.theme.surfaceLowest)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Day Card
    private func forecastDayCard(_ day: DailyForecast) -> some View {
        HStack(spacing: 14) {
            // 좌측: 날짜 + 아이콘
            VStack(spacing: 4) {
                Text(day.dayLabel.isEmpty ? "\(day.dayOfWeek)요일" : day.dayLabel)
                    .font(.appSmallBold)
                    .foregroundColor(
                        day.dayLabel == "오늘"
                            ? .theme.secondary
                            : .theme.textPrimary
                    )

                Image(systemName: day.weatherIcon)
                    .font(.system(size: 24))
                    .foregroundColor(weatherIconColor(day))
                    .frame(height: 28)

                Text(day.shortDate)
                    .font(.system(size: 10))
                    .foregroundColor(.theme.textDisabled)
            }
            .frame(width: 56)

            // 중앙: 상세정보
            VStack(alignment: .leading, spacing: 6) {
                Text(day.message)
                    .font(.appCaptionMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    detailChip(icon: "cloud.rain", text: "\(day.rainProbability)%")
                    detailChip(icon: "aqi.medium", text: day.dustGrade)
                    detailChip(icon: "thermometer", text: "\(day.tempMin)°/\(day.tempMax)°")
                }
            }

            Spacer()

            // 우측: 점수
            VStack(spacing: 2) {
                Text("\(day.score)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(scoreColor(day.score))
                Text(day.grade)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(scoreColor(day.score))
            }
            .frame(width: 48)
        }
        .padding(16)
        .background(
            day.dayLabel == "오늘"
                ? Color.theme.secondary.opacity(0.05)
                : Color.theme.surfaceLowest
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    day.dayLabel == "오늘"
                        ? Color.theme.secondary.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }

    // MARK: - Detail Chip
    private func detailChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.theme.secondary)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.theme.textSecondary)
        }
    }

    // MARK: - Loading / Empty
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.theme.secondary)
            Text("세차 예측을 불러오는 중...")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun.bolt")
                .font(.system(size: 40))
                .foregroundColor(.theme.textDisabled)
            Text("예보 데이터를 가져올 수 없습니다")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
            Button("다시 시도") {
                Task { await washIndexService.loadForecast() }
            }
            .font(.appCaptionBold)
            .foregroundColor(.theme.secondary)
        }
    }

    // MARK: - Helpers
    private func bestDayText(_ day: DailyForecast) -> String {
        if !day.dayLabel.isEmpty {
            return "\(day.dayLabel) (\(day.shortDate) \(day.dayOfWeek)) · \(day.score)점"
        }
        return "\(day.shortDate) (\(day.dayOfWeek)) · \(day.score)점"
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .theme.secondary
        case 60..<80: return .theme.tertiary
        case 40..<60: return Color.yellow
        default: return .theme.error
        }
    }

    private func weatherIconColor(_ day: DailyForecast) -> Color {
        if day.pty > 0 { return .theme.textSecondary }
        switch day.sky {
        case 1: return Color.orange
        case 3: return .theme.textSecondary
        default: return .theme.textDisabled
        }
    }
}
