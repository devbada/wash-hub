import SwiftUI

struct RoutineDetailView: View {
    let routineId: String

    @EnvironmentObject var authManager: AuthManager
    @State private var routine: Routine?
    @State private var products: [RoutineProduct] = []
    @State private var showFollowRoutine = false
    @State private var showLoginAlert = false

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if let routine = routine {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 히어로 섹션
                        heroSection(routine)

                        // 단계 타임라인
                        stepsTimeline(routine)

                        // 사용 제품
                        if !products.isEmpty {
                            productsSection
                        }

                        Spacer().frame(height: 80)
                    }
                }

                // 고정 하단 CTA
                VStack {
                    Spacer()
                    Button(action: {
                        if authManager.isGuest { showLoginAlert = true }
                        else { showFollowRoutine = true }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("따라하기 시작")
                        }
                        .primaryButtonStyle()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.theme.surface.opacity(0), Color.theme.surface, Color.theme.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            } else {
                ProgressView().tint(.theme.primary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 따라하기 시트 dismiss 후 → usage_count 등 최신 값 반영을 위해 재조회
        .fullScreenCover(isPresented: $showFollowRoutine, onDismiss: {
            Task { await reloadRoutine() }
        }) {
            if let routine = routine {
                FollowRoutineView(routine: routine)
                    .environmentObject(authManager)
            }
        }
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") { authManager.exitGuestMode() }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("따라하기는 로그인 후 이용할 수 있습니다.")
        }
        .task {
            await reloadRoutine()
            let service = RoutineService()
            products = await service.loadProducts(routineId: routineId)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                AppUIState.shared.hideBottomUI = true
            }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.3)) {
                AppUIState.shared.hideBottomUI = false
            }
        }
    }

    /// 루틴 데이터 재조회 — 따라하기 완료 후 usage_count 즉시 반영용
    private func reloadRoutine() async {
        let service = RoutineService()
        if let fresh = await service.loadRoutine(id: routineId) {
            routine = fresh
        }
    }

    // MARK: - Hero Section (Stitch: gradient glow + author bar + stats grid)
    private func heroSection(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 프리미엄 라벨
            Text("PREMIUM SERVICE")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundColor(.theme.primary)

            // 큰 제목
            Text(routine.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.theme.textPrimary)
                .tracking(-0.5)

            // 작성자 바
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: routine.profiles?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Circle().fill(Color.theme.surfaceHighest)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.theme.primary.opacity(0.3), lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Author")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.theme.textSecondary)
                    Text(routine.profiles?.displayName ?? "사용자")
                        .font(.appBodyBold)
                        .foregroundColor(.theme.textPrimary)
                }

                Spacer()

                // 완료한 사람 수 — DB trigger 로 자동 카운트되는 실제 따라하기 완료 수
                VStack(alignment: .trailing, spacing: 2) {
                    Text("따라했어요")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.theme.textSecondary)
                    Text("\(routine.usageCount)명")
                        .font(.appBodyBold)
                        .foregroundColor(.theme.secondary)
                }
            }
            .padding(14)
            .background(Color.theme.surfaceLow)
            .cornerRadius(16)

            // Stats Grid (3열)
            HStack(spacing: 12) {
                statBox(label: "DIFFICULTY", content: {
                    AnyView(
                        HStack(spacing: 3) {
                            ForEach(0..<(routine.difficulty ?? 0), id: \.self) { _ in
                                Circle().fill(Color.theme.primary).frame(width: 5, height: 5)
                            }
                            ForEach(0..<(5 - (routine.difficulty ?? 0)), id: \.self) { _ in
                                Circle().fill(Color.theme.textSecondary.opacity(0.2)).frame(width: 5, height: 5)
                            }
                        }
                    )
                })

                statBox(label: "DURATION", content: {
                    AnyView(
                        Text(routine.durationText)
                            .font(.appHeadline3)
                            .foregroundColor(.theme.textPrimary)
                    )
                })

                statBox(label: "STEPS", content: {
                    AnyView(
                        Text("\(routine.routineSteps?.count ?? 0)개")
                            .font(.appHeadline3)
                            .foregroundColor(.theme.textPrimary)
                    )
                })
            }
        }
        .padding(20)
    }

    private func statBox(label: String, content: () -> AnyView) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(.theme.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(12)
        .overlay(
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.theme.primary)
                    .frame(width: 2)
                Spacer()
            }
        )
    }

    // MARK: - Steps Timeline (Stitch: vertical line + numbered circles)
    private func stepsTimeline(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("단계")
                    .font(.appHeadline2)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text("\(routine.routineSteps?.count ?? 0) STAGES TOTAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.theme.primary)
            }
            .padding(.horizontal, 20)

            let sortedSteps = (routine.routineSteps ?? []).sorted { $0.stepOrder < $1.stepOrder }

            ZStack(alignment: .leading) {
                // Timeline vertical line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.theme.primary.opacity(0.4), Color.theme.primary.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)
                    .padding(.leading, 44)

                VStack(spacing: 12) {
                    ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 16) {
                            // 순번 원 — 첫번째만 glow
                            ZStack {
                                Circle()
                                    .fill(Color.theme.surface)
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .stroke(Color.theme.primary, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                Text("\(step.stepOrder)")
                                    .font(.appBodyBold)
                                    .foregroundColor(.theme.primary)
                            }
                            .shadow(color: index == 0 ? Color.theme.primary.opacity(0.3) : .clear, radius: 8)

                            // 단계 내용 카드
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(step.title)
                                        .font(.appBodyBold)
                                        .foregroundColor(.theme.textPrimary)
                                    Spacer()
                                    if !step.durationText.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 12))
                                            Text(step.durationText)
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.theme.secondary)
                                    }
                                }

                                if let desc = step.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.appSmall)
                                        .foregroundColor(.theme.textSecondary)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(14)
                            .background(Color.theme.surfaceLow)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Products (Stitch: rounded-full chips with icon)
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("사용 제품")
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(products) { product in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 14))
                                .foregroundColor(.theme.primary)
                            Text(product.productName)
                                .font(.appCaption)
                                .foregroundColor(.theme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.theme.surfaceBright)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.theme.outlineVariant.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
