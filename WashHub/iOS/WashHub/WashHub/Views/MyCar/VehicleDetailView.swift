import SwiftUI
import Supabase

/// v2 차량 상세 화면 (프로토타입 12 Vehicle)
///
/// 내차 탭에서 차량 카드를 탭하면 진입한다.
/// 구성: 히어로(차량 사진) + 차량 정보 + 통계 3-grid + 섹션 리스트.
struct VehicleDetailView: View {
    let car: MyCar
    /// 차량 정보 수정 — MyCarListView 가 AddMyCarView 시트를 띄움
    var onEdit: () -> Void = {}
    /// 차량 삭제 — MyCarListView 가 실제 삭제 처리
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var washLogs: [WashLog] = []
    @State private var isLoading = true
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    titleSection
                    statsRow
                    sectionList
                    BottomTabBarSpacer()
                }
                .padding(.bottom, 8)
            }
        }
        .navigationTitle(car.carModel)
        .navigationBarTitleDisplayMode(.inline)
        .alert("차량 삭제", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("\(car.carModel)을(를) 삭제할까요?\n관련 세차 기록도 함께 삭제돼요.")
        }
        .task { await loadWashLogs() }
    }

    // MARK: - 히어로 (차량 사진)
    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let urlStr = car.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            if car.isPrimary {
                Text("대표 차량")
                    .font(.appLabelSmall)
                    .fontWeight(.heavy)
                    .foregroundColor(.theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.theme.accent))
                    .padding(14)
            }
        }
    }

    private var heroPlaceholder: some View {
        LinearGradient(
            colors: [Color(red: 0.28, green: 0.34, blue: 0.41),
                     Color(red: 0.06, green: 0.09, blue: 0.16)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "car.fill")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.4))
        )
    }

    // MARK: - 차량 정보
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(car.carYear.map { "\(String($0)) 년식" } ?? "내 차")
                .font(.appLabelSmall)
                .fontWeight(.heavy)
                .kerning(1.4)
                .foregroundColor(.theme.secondary)

            Text(car.nickname?.isEmpty == false ? car.nickname! : car.carModel)
                .font(.appHeadline1)
                .foregroundColor(.theme.textPrimary)

            Text([car.carColor, car.carNumber].compactMap { $0 }.joined(separator: " · "))
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - 통계 3-grid
    private var statsRow: some View {
        HStack(spacing: 10) {
            statCell(icon: "drop.fill", value: "\(washLogs.count)회", label: "총 세차", color: .theme.secondary)
            statCell(icon: "clock", value: lastWashText, label: "마지막 세차", color: .theme.textPrimary)
            statCell(icon: "calendar", value: nextWashText, label: "다음 예정", color: Color.rhythmAccent)
        }
        .padding(.horizontal, 16)
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)
            Text(label)
                .font(.appSmall)
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.theme.surfaceLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.theme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - 섹션 리스트
    private var sectionList: some View {
        VStack(spacing: 8) {
            NavigationLink(value: MyCarNavTarget.washLogs(car.id)) {
                sectionRow(icon: "list.bullet.rectangle", label: "세차 기록",
                           sub: "\(washLogs.count)건", danger: false)
            }
            .buttonStyle(.plain)

            NavigationLink(value: MyCarNavTarget.stats) {
                sectionRow(icon: "chart.bar.fill", label: "세차 통계",
                           sub: "월별 · 평균 주기", danger: false)
            }
            .buttonStyle(.plain)

            sectionRow(icon: "star", label: "즐겨찾는 세차장", sub: "아직 없어요", danger: false)

            Button(action: onEdit) {
                sectionRow(icon: "slider.horizontal.3", label: "차량 정보 수정", sub: nil, danger: false)
            }
            .buttonStyle(.plain)

            Button(action: { showDeleteConfirm = true }) {
                sectionRow(icon: "trash", label: "차량 삭제", sub: nil, danger: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func sectionRow(icon: String, label: String, sub: String?, danger: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(danger ? .theme.error : .theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(danger ? Color.theme.error.opacity(0.10) : Color.theme.surfaceLow)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appCaptionMedium)
                    .foregroundColor(danger ? .theme.error : .theme.textPrimary)
                if let sub {
                    Text(sub)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.theme.surfaceLowest)
        )
    }

    // MARK: - 통계 텍스트

    /// 가장 최근 세차로부터 경과일
    private var lastWashText: String {
        guard let last = washLogs.first, let date = parseDate(last.washDate) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "오늘" }
        return "\(days)일 전"
    }

    /// 다음 예정 세차일 — 마지막 세차 + 차량 주기
    private var nextWashText: String {
        guard let last = washLogs.first, let date = parseDate(last.washDate) else { return "—" }
        guard let next = Calendar.current.date(byAdding: .day, value: car.effectiveWashIntervalDays, to: date) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        if days > 0 { return "D-\(days)" }
        if days == 0 { return "D-Day" }
        return "지남"
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    // MARK: - 데이터 로드
    private func loadWashLogs() async {
        do {
            let persistLogs: [WashLog] = try await supabase
                .from("wash_logs")
                .select()
                .eq("car_id", value: car.id)
                .eq("status", value: "ACTIVE")
                .order("wash_date", ascending: false)
                .execute()
                .value
            washLogs = persistLogs
        } catch {
            print("VehicleDetail wash logs load error: \(error)")
        }
        isLoading = false
    }
}
