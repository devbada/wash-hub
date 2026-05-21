import SwiftUI

struct BadgeCollectionView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var badgeService = BadgeService()
    @State private var selectedBadge: Badge?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 획득 현황 헤더
                    progressHeader

                    // 뱃지 그리드
                    badgeGrid
                }
                .padding(16)
            }
        }
        .navigationTitle("뱃지")
        .navigationBarTitleDisplayMode(.large)
        // .sheet(item:) 패턴 — selectedBadge 가 set 됨과 동시에 sheet 표시
        // (이전 .sheet(isPresented:) + selectedBadge 두 state 동시 set 시
        //  첫 클릭 race condition 으로 빈 화면 보이던 버그 수정)
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(
                badge: badge,
                isUnlocked: badgeService.isUnlocked(badgeId: badge.id),
                unlockedAt: badgeService.myBadges.first(where: { $0.badgeId == badge.id })?.unlockedAt,
                onSetTitle: { badgeId in
                    guard let userId = authManager.currentUser?.id else { return false }
                    let success = await badgeService.setTitle(userId: userId, badgeId: badgeId)
                    if success {
                        await authManager.loadProfile(userId: userId)
                    }
                    return success
                }
            )
            .environmentObject(authManager)
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        async let badges: () = badgeService.loadAllBadges()
        if let userId = authManager.currentUser?.id {
            async let myBadges: () = badgeService.loadMyBadges(userId: userId)
            _ = await (badges, myBadges)
        } else {
            _ = await badges
        }
    }

    // MARK: - 획득 현황 헤더
    private var progressHeader: some View {
        let total = badgeService.allBadges.count
        let unlocked = badgeService.myBadges.count
        let progress = total > 0 ? Double(unlocked) / Double(total) : 0

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.theme.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("뱃지 컬렉션")
                        .font(.appHeadline2)
                        .foregroundColor(.theme.textPrimary)
                    Text("\(unlocked)/\(total)개 획득")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                }
                Spacer()
            }

            // 프로그레스 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.theme.surfaceContainer)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.theme.accent)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - 뱃지 그리드
    private var badgeGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(badgeService.allBadges) { badge in
                let unlocked = badgeService.isUnlocked(badgeId: badge.id)
                BadgeGridItem(badge: badge, isUnlocked: unlocked)
                    .onTapGesture {
                        // .sheet(item:) 가 selectedBadge non-nil 시 자동 표시
                        selectedBadge = badge
                    }
            }
        }
    }
}

// MARK: - 그리드 아이템
struct BadgeGridItem: View {
    let badge: Badge
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            // 아이콘 원형
            ZStack {
                if isUnlocked {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                } else {
                    Circle()
                        .fill(Color.theme.surfaceContainer)
                        .frame(width: 64, height: 64)
                }

                Image(systemName: badge.iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(isUnlocked ? .white : .theme.textDisabled)
            }

            // 이름
            Text(badge.name)
                .font(.appSmall)
                .foregroundColor(isUnlocked ? .theme.textPrimary : .theme.textDisabled)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }

    private var gradientColors: [Color] {
        guard let type = BadgeType(rawValue: badge.badgeType) else {
            return [.theme.accentBright, .theme.accent]
        }
        let (start, end) = type.gradientColors
        return [Color(hex: start), Color(hex: end)]
    }
}

// MARK: - 뱃지 상세 시트
struct BadgeDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    let badge: Badge
    let isUnlocked: Bool
    let unlockedAt: String?
    let onSetTitle: (String?) async -> Bool
    @State private var isSettingTitle = false

    /// authManager에서 실시간으로 읽어 즉시 반영
    private var isCurrentTitle: Bool {
        authManager.currentUser?.titleBadgeId == badge.id
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // 대형 아이콘
                    ZStack {
                        if isUnlocked {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 20, y: 10)
                        } else {
                            Circle()
                                .fill(Color.theme.surfaceContainer)
                                .frame(width: 120, height: 120)
                        }

                        Image(systemName: badge.iconName)
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(isUnlocked ? .white : .theme.textDisabled)
                    }

                    // 이름 + 설명
                    VStack(spacing: 8) {
                        Text(badge.name)
                            .font(.appHeadline1)
                            .foregroundColor(.theme.textPrimary)

                        Text(badge.description)
                            .font(.appBody)
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // 획득 조건
                    if let condition = badge.unlockCondition {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(isUnlocked ? .theme.secondary : .theme.textDisabled)
                            Text("조건: \(conditionText(condition))")
                                .font(.appCaption)
                                .foregroundColor(isUnlocked ? .theme.secondary : .theme.textDisabled)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isUnlocked ? Color.theme.accent.opacity(0.1) : Color.theme.surfaceLow)
                        )
                    }

                    // 획득 일시
                    if let unlockedAt = unlockedAt {
                        Text("획득: \(String(unlockedAt.prefix(10)))")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                    }

                    Spacer()

                    // 타이틀 설정 버튼
                    if isUnlocked {
                        Button(action: {
                            isSettingTitle = true
                            Task {
                                let success = await onSetTitle(isCurrentTitle ? nil : badge.id)
                                isSettingTitle = false
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            if isSettingTitle {
                                ProgressView()
                                    .tint(isCurrentTitle ? .theme.textSecondary : .theme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isCurrentTitle ? Color.theme.surfaceHigh : Color.theme.primary)
                                    )
                            } else {
                                Text(isCurrentTitle ? "타이틀 해제" : "대표 타이틀로 설정")
                                    .font(.appBodyMedium)
                                    .foregroundColor(isCurrentTitle ? .theme.textSecondary : .theme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isCurrentTitle ? Color.theme.surfaceHigh : Color.theme.primary)
                                    )
                            }
                        }
                        .disabled(isSettingTitle)
                    } else {
                        Text("아직 획득하지 못한 뱃지입니다")
                            .font(.appCaption)
                            .foregroundColor(.theme.textDisabled)
                            .padding(.vertical, 16)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }
        }
    }

    private var gradientColors: [Color] {
        guard let type = BadgeType(rawValue: badge.badgeType) else {
            return [.theme.accentBright, .theme.accent]
        }
        let (start, end) = type.gradientColors
        return [Color(hex: start), Color(hex: end)]
    }

    private func conditionText(_ condition: BadgeCondition) -> String {
        switch condition.type {
        case "WASH_COUNT": return "세차 기록 \(condition.value)회"
        case "REVIEW_COUNT": return "리뷰 작성 \(condition.value)개"
        case "LIKE_RECEIVED_COUNT": return "받은 좋아요 \(condition.value)개"
        case "COMMENT_COUNT": return "댓글 작성 \(condition.value)개"
        case "FOLLOWER_COUNT": return "팔로워 \(condition.value)명"
        case "BADGE_COUNT": return "뱃지 \(condition.value)개 획득"
        case "ALL_BADGES": return "모든 뱃지 획득"
        default: return "\(condition.value)"
        }
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
