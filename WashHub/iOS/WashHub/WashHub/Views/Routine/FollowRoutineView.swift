import SwiftUI

struct FollowRoutineView: View {
    let routine: Routine

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var executionService = RoutineExecutionService()
    @State private var isStarted = false
    @State private var showCompleteAlert = false
    @State private var showAbandonAlert = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    private var sortedSteps: [RoutineStep] {
        (routine.routineSteps ?? []).sorted { $0.stepOrder < $1.stepOrder }
    }

    private var completedCount: Int {
        executionService.executionSteps.filter { $0.completed }.count
    }

    private var totalCount: Int {
        executionService.executionSteps.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Section
                    progressSection

                    // Checklist
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sortedSteps) { step in
                                let execStep = executionService.executionSteps.first { $0.stepId == step.id }
                                let isCompleted = execStep?.completed ?? false
                                let isCurrent = !isCompleted && isFirstUncompleted(step)

                                stepCard(step: step, execStep: execStep, isCompleted: isCompleted, isCurrent: isCurrent)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }

                // Bottom Action Bar
                VStack {
                    Spacer()
                    bottomActions
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if isStarted && !executionService.isCompleted {
                            showAbandonAlert = true
                        } else {
                            stopTimer()
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("따라하기")
                        .font(.appHeadline3)
                        .foregroundColor(.theme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 타이머
                    Text(formatTime(elapsedSeconds))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.theme.primary)
                        .shadow(color: Color.theme.primary.opacity(0.4), radius: 5)
                }
            }
            .alert("세차 완료!", isPresented: $showCompleteAlert) {
                Button("확인") {
                    stopTimer()
                    dismiss()
                }
            } message: {
                let minutes = elapsedSeconds / 60
                Text("수고하셨습니다! 총 \(minutes)분 소요되었습니다.")
            }
            .alert("중단하시겠습니까?", isPresented: $showAbandonAlert) {
                Button("계속하기", role: .cancel) {}
                Button("중단", role: .destructive) {
                    Task {
                        await executionService.abandonExecution()
                        stopTimer()
                        dismiss()
                    }
                }
            } message: {
                Text("진행 상황이 저장되지 않습니다.")
            }
            .task {
                await startOrRestore()
            }
        }
    }

    // MARK: - Progress Section (Stitch: gradient bar + counter)
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CURRENT PROGRESS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.theme.textSecondary)
                Spacer()
                Text("\(completedCount)/\(totalCount) 단계 완료")
                    .font(.appBodyBold)
                    .foregroundColor(.theme.primary)
            }

            // Gradient progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.theme.surfaceHighest)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.theme.primary, Color.theme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * executionService.progress, height: 6)
                        .shadow(color: Color.theme.primary.opacity(0.3), radius: 6)
                        .animation(.easeInOut(duration: 0.3), value: executionService.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Step Card (Stitch: Completed/Current/Upcoming states)
    private func stepCard(step: RoutineStep, execStep: RoutineExecutionStep?, isCompleted: Bool, isCurrent: Bool) -> some View {
        Button(action: {
            guard let execStep = execStep else { return }
            Task {
                await executionService.toggleStep(executionStepId: execStep.id)
                if executionService.isCompleted {
                    showCompleteAlert = true
                }
            }
        }) {
            HStack(spacing: 14) {
                // 체크 원
                if isCompleted {
                    ZStack {
                        Circle()
                            .fill(Color.theme.secondary)
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.theme.secondary.opacity(0.4), radius: 8)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.theme.surface)
                    }
                } else if isCurrent {
                    ZStack {
                        Circle()
                            .stroke(Color.theme.primary, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        Text(String(format: "%02d", step.stepOrder))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.theme.primary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.theme.outlineVariant, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        Text(String(format: "%02d", step.stepOrder))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.theme.textSecondary)
                    }
                }

                // 텍스트
                VStack(alignment: .leading, spacing: 3) {
                    // 상태 라벨
                    Text(isCompleted ? "STEP \(String(format: "%02d", step.stepOrder))" : (isCurrent ? "CURRENT STEP" : "UPCOMING"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(isCompleted ? .theme.secondary : (isCurrent ? .theme.primary : .theme.textSecondary))

                    Text(step.title)
                        .font(.appBodyBold)
                        .foregroundColor(isCompleted ? .theme.textSecondary : .theme.textPrimary)
                        .strikethrough(isCompleted, color: .theme.secondary.opacity(0.5))
                }

                Spacer()
            }
            .padding(16)
            .background(isCurrent ? Color.theme.surfaceHigh : Color.theme.surfaceLow)
            .cornerRadius(16)
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isCompleted ? Color.theme.secondary : (isCurrent ? Color.theme.primary : Color.clear))
                        .frame(width: 4)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .opacity((!isCompleted && !isCurrent) ? 0.6 : 1.0)
            .shadow(color: isCurrent ? Color.theme.primary.opacity(0.1) : .clear, radius: 10)
        }
        .disabled(executionService.isCompleted)
    }

    // MARK: - Bottom Actions (Stitch: 포기/완료 side by side)
    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button(action: { showAbandonAlert = true }) {
                Text("포기하기")
                    .destructiveButtonStyle()
            }

            Button(action: {
                Task {
                    await executionService.completeExecution()
                    showCompleteAlert = true
                }
            }) {
                Text("완료하기")
                    .font(.appBodyBold)
                    .foregroundColor(.theme.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.theme.secondary, Color.theme.secondaryDim],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.theme.secondary.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .disabled(!executionService.isCompleted)
            .opacity(executionService.isCompleted ? 1.0 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.theme.surfaceLow.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Helpers
    private func isFirstUncompleted(_ step: RoutineStep) -> Bool {
        let uncompleted = sortedSteps.first { s in
            let exec = executionService.executionSteps.first { $0.stepId == s.id }
            return !(exec?.completed ?? false)
        }
        return uncompleted?.id == step.id
    }

    private func startOrRestore() async {
        if let _ = await executionService.restoreInProgress(routineId: routine.id) {
            isStarted = true
            startTimer()
            return
        }

        do {
            _ = try await executionService.startExecution(
                routineId: routine.id,
                steps: sortedSteps
            )
            isStarted = true
            startTimer()
        } catch {
            print("Start execution error: \(error)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
