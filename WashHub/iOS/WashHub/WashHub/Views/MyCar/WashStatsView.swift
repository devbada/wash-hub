import SwiftUI
import Supabase

// MARK: - 세차 통계 리포트
struct WashStatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var monthlyStats: [MonthStat] = []
    @State private var topEquipments: [EquipmentStat] = []
    @State private var totalWashCount = 0
    @State private var averageInterval: Double = 0
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.theme.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 연도 선택
                        yearSelector

                        // 요약 카드
                        summaryCards

                        // 월별 세차 횟수 차트
                        monthlyChartSection

                        // 자주 사용한 용품 TOP 5
                        topEquipmentSection
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("세차 통계")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStats() }
        .onChange(of: selectedYear) { _, _ in
            Task { await loadStats() }
        }
    }

    // MARK: - 연도 선택
    private var yearSelector: some View {
        HStack {
            Button(action: { selectedYear -= 1 }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.theme.secondary)
            }
            .disabled(selectedYear <= 2020)

            Text("\(String(selectedYear))년")
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)
                .frame(minWidth: 80)

            Button(action: { selectedYear += 1 }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.theme.secondary)
            }
            .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 요약 카드
    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "drop.fill",
                title: "총 세차",
                value: "\(totalWashCount)회",
                color: .theme.secondary
            )
            StatCard(
                icon: "calendar",
                title: "평균 주기",
                value: averageInterval > 0 ? String(format: "%.0f일", averageInterval) : "-",
                color: .theme.tertiary
            )
            StatCard(
                icon: "star.fill",
                title: "월 평균",
                value: totalWashCount > 0 ? String(format: "%.1f회", Double(totalWashCount) / 12.0) : "-",
                color: .theme.kakaoYellow
            )
        }
    }

    // MARK: - 월별 차트
    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("월별 세차 횟수")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            if monthlyStats.allSatisfy({ $0.count == 0 }) {
                emptyChartView
            } else {
                MonthlyBarChart(stats: monthlyStats)
                    .frame(height: 180)
            }
        }
        .padding(16)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(12)
    }

    // MARK: - TOP 5 용품
    private var topEquipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("자주 사용한 용품")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            if topEquipments.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "flask")
                            .font(.system(size: 28))
                            .foregroundColor(.theme.textDisabled)
                        Text("사용 기록이 없습니다")
                            .font(.appCaption)
                            .foregroundColor(.theme.textDisabled)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(Array(topEquipments.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        // 순위
                        Text("\(index + 1)")
                            .font(.appHeadline2)
                            .foregroundColor(index < 3 ? .theme.secondary : .theme.textDisabled)
                            .frame(width: 28)

                        // 이미지
                        AsyncImage(url: URL(string: item.imageUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.theme.surface)
                                    .overlay(
                                        Image(systemName: "drop.circle")
                                            .foregroundColor(.theme.textDisabled)
                                    )
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.appBodyMedium)
                                .foregroundColor(.theme.textPrimary)
                                .lineLimit(1)
                            if let category = item.category {
                                Text(category)
                                    .font(.appSmall)
                                    .foregroundColor(.theme.textDisabled)
                            }
                        }

                        Spacer()

                        Text("\(item.usageCount)회")
                            .font(.appBodyBold)
                            .foregroundColor(.theme.secondary)
                    }
                    .padding(.vertical, 4)

                    if index < topEquipments.count - 1 {
                        Divider().background(Color.theme.border)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(12)
    }

    private var emptyChartView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 28))
                    .foregroundColor(.theme.textDisabled)
                Text("세차 기록이 없습니다")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    // MARK: - 데이터 로드
    private func loadStats() async {
        isLoading = true
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            // 1. 해당 연도 세차 기록 전체 조회
            let startDate = "\(selectedYear)-01-01"
            let endDate = "\(selectedYear)-12-31"

            let persistLogs: [WashLog] = try await supabase
                .from("wash_logs")
                .select()
                .eq("user_id", value: userId)
                .eq("status", value: "ACTIVE")
                .gte("wash_date", value: startDate)
                .lte("wash_date", value: endDate)
                .order("wash_date", ascending: true)
                .execute()
                .value

            // 2. 월별 통계 계산
            var monthlyCounts = Array(repeating: 0, count: 12)
            for log in persistLogs {
                if let month = extractMonth(from: log.washDate) {
                    monthlyCounts[month - 1] += 1
                }
            }
            monthlyStats = (1...12).map { month in
                MonthStat(month: month, count: monthlyCounts[month - 1])
            }

            // 3. 총 횟수 & 평균 주기
            totalWashCount = persistLogs.count
            averageInterval = calculateAverageInterval(logs: persistLogs)

            // 4. 자주 사용한 용품 TOP 5
            await loadTopEquipments(userId: userId, startDate: startDate, endDate: endDate)

        } catch {
            print("Wash stats load error: \(error)")
        }
        isLoading = false
    }

    private func loadTopEquipments(userId: String, startDate: String, endDate: String) async {
        do {
            // wash_log_equipments + equipments JOIN
            struct LogEquipment: Codable {
                let equipmentId: String
                let equipments: EquipmentMini?

                enum CodingKeys: String, CodingKey {
                    case equipmentId = "equipment_id"
                    case equipments
                }
            }
            struct EquipmentMini: Codable {
                let id: String
                let name: String
                let category: String?
                let imageUrl: String?

                enum CodingKeys: String, CodingKey {
                    case id, name, category
                    case imageUrl = "image_url"
                }
            }

            // wash_logs의 id 목록을 먼저 가져오고, wash_log_equipments에서 JOIN
            let persistLogEquipments: [LogEquipment] = try await supabase
                .from("wash_log_equipments")
                .select("equipment_id, equipments(id, name, category, image_url)")
                .execute()
                .value

            // 장비별 사용 횟수 집계
            var equipmentCounts: [String: (name: String, category: String?, imageUrl: String?, count: Int)] = [:]
            for le in persistLogEquipments {
                if let eq = le.equipments {
                    let existing = equipmentCounts[eq.id]
                    equipmentCounts[eq.id] = (
                        name: eq.name,
                        category: eq.category,
                        imageUrl: eq.imageUrl,
                        count: (existing?.count ?? 0) + 1
                    )
                }
            }

            topEquipments = equipmentCounts
                .sorted { $0.value.count > $1.value.count }
                .prefix(5)
                .map { EquipmentStat(
                    id: $0.key,
                    name: $0.value.name,
                    category: $0.value.category,
                    imageUrl: $0.value.imageUrl,
                    usageCount: $0.value.count
                )}

        } catch {
            print("Top equipments load error: \(error)")
            topEquipments = []
        }
    }

    private func extractMonth(from dateString: String) -> Int? {
        let parts = dateString.prefix(10).split(separator: "-")
        guard parts.count >= 2, let month = Int(parts[1]) else { return nil }
        return month
    }

    private func calculateAverageInterval(logs: [WashLog]) -> Double {
        guard logs.count > 1 else { return 0 }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let dates = logs.compactMap { df.date(from: String($0.washDate.prefix(10))) }.sorted()
        guard dates.count > 1 else { return 0 }

        var totalDays: Double = 0
        for i in 1..<dates.count {
            totalDays += dates[i].timeIntervalSince(dates[i - 1]) / 86400
        }
        return totalDays / Double(dates.count - 1)
    }
}

// MARK: - 요약 카드 컴포넌트
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)
            Text(title)
                .font(.appSmall)
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(12)
    }
}

// MARK: - 월별 바 차트 (SwiftUI 순수 구현)
struct MonthlyBarChart: View {
    let stats: [MonthStat]

    private var maxCount: Int {
        max(stats.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(stats) { stat in
                VStack(spacing: 4) {
                    if stat.count > 0 {
                        Text("\(stat.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.theme.secondary)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(stat.count > 0 ? Color.theme.secondary : Color.theme.border.opacity(0.3))
                        .frame(height: stat.count > 0
                            ? CGFloat(stat.count) / CGFloat(maxCount) * 130
                            : 4
                        )

                    Text("\(stat.month)월")
                        .font(.system(size: 10))
                        .foregroundColor(.theme.textDisabled)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 데이터 모델
struct MonthStat: Identifiable {
    let id = UUID()
    let month: Int
    let count: Int
}

struct EquipmentStat: Identifiable {
    let id: String
    let name: String
    let category: String?
    let imageUrl: String?
    let usageCount: Int
}
