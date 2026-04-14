import SwiftUI

struct RoutineListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var routineService = RoutineService()
    @State private var showCreateRoutine = false
    @State private var showLoginAlert = false
    @State private var searchText = ""

    var filteredRoutines: [Routine] {
        if searchText.isEmpty { return routineService.routines }
        return routineService.routines.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 검색바 — Stitch: rounded-xl, surfaceHigh bg
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.theme.textSecondary)
                        TextField("루틴 검색...", text: $searchText)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                    }
                    .padding(14)
                    .background(Color.theme.surfaceHigh)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if routineService.isLoading && routineService.routines.isEmpty {
                        Spacer()
                        ProgressView().tint(.theme.primary)
                        Spacer()
                    } else if filteredRoutines.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 50))
                                .foregroundColor(.theme.textDisabled)
                            Text("등록된 루틴이 없습니다")
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                            Text("나만의 세차 루틴을 공유해보세요!")
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRoutines) { routine in
                                    NavigationLink(destination: RoutineDetailView(routineId: routine.id)) {
                                        RoutineCard(routine: routine)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await routineService.loadRoutines()
                        }
                    }
                }
            }
            .navigationTitle("루틴")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.isGuest { showLoginAlert = true }
                        else { showCreateRoutine = true }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                CreateRoutineView {
                    await routineService.loadRoutines()
                }
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") { authManager.exitGuestMode() }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("루틴 등록은 로그인 후 이용할 수 있습니다.")
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await routineService.loadRoutines()
        }
    }
}

// MARK: - 루틴 카드 (Stitch Design: Speed-line + Step Preview Chips)
struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 제목
            Text(routine.title)
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)

            // 작성자
            HStack(spacing: 6) {
                AsyncImage(url: URL(string: routine.profiles?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Circle().fill(Color.theme.surfaceHighest)
                    }
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())

                Text(routine.profiles?.displayName ?? "사용자")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.theme.textSecondary)
            }

            // 메타 정보: 난이도 + 소요시간 + 따라하기
            HStack(spacing: 16) {
                // 난이도 dots
                if let diff = routine.difficulty {
                    HStack(spacing: 2) {
                        HStack(spacing: 2) {
                            ForEach(0..<diff, id: \.self) { _ in
                                Circle()
                                    .fill(Color.theme.primary)
                                    .frame(width: 5, height: 5)
                            }
                            ForEach(0..<(5 - diff), id: \.self) { _ in
                                Circle()
                                    .fill(Color.theme.textSecondary.opacity(0.2))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text("LV.\(diff)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.theme.textSecondary)
                            .padding(.leading, 2)
                    }
                }

                // 소요시간
                if let _ = routine.duration {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(routine.durationText)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.theme.textSecondary)
                }

                // 따라하기 수
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                    Text("\(routine.forkCount)")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.theme.textSecondary)
            }

            // Step preview chips
            if let steps = routine.routineSteps?.sorted(by: { $0.stepOrder < $1.stepOrder }),
               !steps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(steps.prefix(4)) { step in
                            Text(step.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.theme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.theme.surfaceHigh)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.theme.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        if steps.count > 4 {
                            Text("+\(steps.count - 4)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                }
            }
        }
        .padding(16)
        .speedLineCardStyle(isActive: true)
    }
}
