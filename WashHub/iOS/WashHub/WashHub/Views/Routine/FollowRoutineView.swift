import SwiftUI

struct FollowRoutineView: View {
    let routine: Routine

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var executionService = RoutineExecutionService()
    @State private var isStarted = false
    @State private var showAbandonAlert = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    // 사진 캡처 + 공유 흐름 (루틴 강화 — Photos 앨범 저장 기반)
    @State private var showBeforeCaptureSheet = false
    @State private var showAfterCaptureSheet = false
    @State private var showShareDecisionSheet = false
    @State private var showCreateFeedSheet = false
    @State private var photoPickerActive = false  // 카메라 picker 활성화 트리거
    @State private var capturePhase: CapturePhase = .before
    @State private var pendingCaptureImage: UIImage?  // 임시 — 앨범 저장 직전

    enum CapturePhase { case before, after }

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
            // ① ② ③ — 하단 고정 커스텀 시트 (fullScreenCover 안에서 confirmationDialog 가 상단에 뜨는 이슈 회피)
            .overlay(alignment: .bottom) {
                bottomCaptureSheets
            }
            // ④ 카메라 — "사진 찍기" 탭 시 즉시 카메라 실행 (소스 선택 단계 없음)
            .fullScreenCover(isPresented: $photoPickerActive) {
                ImagePicker(sourceType: .camera) { image in
                    Task {
                        _ = await RoutineExecutionService.savePhotoToAlbum(image)
                        await MainActor.run {
                            // 카메라 dismiss 후 다음 흐름으로 분기
                            if capturePhase == .before {
                                Task { await startNewExecution() }
                            } else {
                                showShareDecisionSheet = true
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }
            // ⑤ 피드 작성 시트 — prefilled 본문/태그 + onFeedCreated 콜백으로 routine_executions.feed_id 링크
            .sheet(isPresented: $showCreateFeedSheet, onDismiss: {
                stopTimer()
                dismiss()
            }) {
                CreateFeedView(
                    prefilledContent: feedPrefillContent(),
                    prefilledHashtags: feedPrefillHashtags(),
                    showPhotoFromAlbumHint: true,
                    onFeedCreated: { feedId in
                        Task {
                            await executionService.linkFeed(feedId: feedId)
                        }
                    }
                )
                .environmentObject(authManager)
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
            .onDisappear {
                // 방어적 타이머 정리 (dismiss 경로가 여러개라 명시적 cleanup)
                stopTimer()
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
                // 모든 단계가 완료되었으면 자동으로 완료 흐름 진입
                if executionService.isCompleted {
                    await finalizeRoutine()
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

    /// 모든 스텝이 완료되었는지 여부
    private var allStepsCompleted: Bool {
        completedCount >= totalCount && totalCount > 0
    }

    // MARK: - Bottom Actions (포기 / 다음 or 완료)
    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button(action: { showAbandonAlert = true }) {
                Text("포기하기")
                    .destructiveButtonStyle()
            }

            if allStepsCompleted {
                // 모든 스텝 완료 → "완료하기" 버튼 → After 사진/공유 흐름 진입
                Button(action: {
                    Task { await finalizeRoutine() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("완료하기")
                    }
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
                .disabled(!isStarted || executionService.isCompleted)
                .opacity(!isStarted || executionService.isCompleted ? 0.4 : 1.0)
            } else {
                // 아직 남은 스텝 → "다음" 버튼 (현재 스텝 완료 처리)
                Button(action: {
                    Task {
                        await advanceToNextStep()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("다음")
                        Image(systemName: "chevron.right")
                    }
                    .font(.appBodyBold)
                    .foregroundColor(.theme.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.theme.secondary, Color.theme.secondary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.theme.secondary.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .disabled(!isStarted || executionService.isCompleted)
                .opacity(!isStarted || executionService.isCompleted ? 0.4 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.theme.surfaceLow.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }

    /// "다음" 버튼: 현재 첫 번째 미완료 스텝을 완료 처리
    private func advanceToNextStep() async {
        // 첫 번째 미완료 스텝 찾기
        guard let nextStep = sortedSteps.first(where: { step in
            let exec = executionService.executionSteps.first { $0.stepId == step.id }
            return !(exec?.completed ?? false)
        }),
        let execStep = executionService.executionSteps.first(where: { $0.stepId == nextStep.id }) else {
            return
        }

        await executionService.toggleStep(executionStepId: execStep.id)

        // 모든 단계 완료 시 자동으로 완료 흐름 진입 (After 사진 → 공유)
        if executionService.isCompleted {
            await finalizeRoutine()
        }
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
        // 진행 중이던 실행 복원 → 그대로 이어가기 (Before 사진 안 묻음)
        if let _ = await executionService.restoreInProgress(routineId: routine.id) {
            isStarted = true
            if let startedAtString = executionService.currentExecution?.startedAt,
               let startedDate = parseISO8601(startedAtString) {
                let elapsed = max(0, Int(Date().timeIntervalSince(startedDate)))
                elapsedSeconds = elapsed
            }
            startTimer()
            return
        }

        // 신규 시작 → 먼저 Before 사진 권유
        showBeforeCaptureSheet = true
    }

    /// Before 사진 단계가 끝난 후 실제 실행 시작 (또는 사용자가 Skip 선택 시)
    private func startNewExecution() async {
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

    // MARK: - 하단 시트 (Before / After / Share) — fullScreenCover 안에서 confirmationDialog 위치 이슈 회피용
    @ViewBuilder
    private var bottomCaptureSheets: some View {
        ZStack(alignment: .bottom) {
            // 어떤 시트라도 활성일 때 dimmed 배경
            if showBeforeCaptureSheet || showAfterCaptureSheet || showShareDecisionSheet {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        // 배경 탭 = 건너뛰기 / 마치기 (보수적 cancel)
                        if showBeforeCaptureSheet {
                            showBeforeCaptureSheet = false
                            Task { await startNewExecution() }
                        } else if showAfterCaptureSheet {
                            showAfterCaptureSheet = false
                            showShareDecisionSheet = true
                        } else if showShareDecisionSheet {
                            showShareDecisionSheet = false
                            stopTimer()
                            dismiss()
                        }
                    }
            }

            if showBeforeCaptureSheet {
                BottomActionCard(
                    title: "시작 사진을 찍어볼까요?",
                    message: "나중에 피드로 공유할 때 빠르게 사용할 수 있어요. 사진은 사진 앨범에 저장됩니다.",
                    primaryLabel: "사진 찍기",
                    primaryAction: {
                        showBeforeCaptureSheet = false
                        capturePhase = .before
                        photoPickerActive = true
                    },
                    cancelLabel: "건너뛰기",
                    cancelAction: {
                        showBeforeCaptureSheet = false
                        Task { await startNewExecution() }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showAfterCaptureSheet {
                BottomActionCard(
                    title: "완료 사진도 남겨볼까요?",
                    message: "Before/After 비교 사진이 있으면 더 멋진 피드가 됩니다.",
                    primaryLabel: "사진 찍기",
                    primaryAction: {
                        showAfterCaptureSheet = false
                        capturePhase = .after
                        photoPickerActive = true
                    },
                    cancelLabel: "건너뛰기",
                    cancelAction: {
                        showAfterCaptureSheet = false
                        showShareDecisionSheet = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showShareDecisionSheet {
                BottomActionCard(
                    title: "이 결과를 피드로 공유할까요?",
                    message: "\(max(1, elapsedSeconds / 60))분 동안 \(totalCount)단계를 완료하셨어요. 수고하셨어요!",
                    primaryLabel: "피드 작성하기",
                    primaryAction: {
                        showShareDecisionSheet = false
                        showCreateFeedSheet = true
                    },
                    cancelLabel: "그냥 마치기",
                    cancelAction: {
                        showShareDecisionSheet = false
                        stopTimer()
                        dismiss()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showBeforeCaptureSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showAfterCaptureSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showShareDecisionSheet)
    }

    /// 모든 단계 완료 후: duration 저장 → After 사진 권유 → 공유 시트
    private func finalizeRoutine() async {
        // duration_seconds 와 함께 완료 처리 (이미 완료 상태면 service guard 로 noop)
        await executionService.completeExecution(durationSeconds: elapsedSeconds)
        stopTimer()
        // After 사진 권유 시트 노출 → 답변에 따라 공유 시트로 이어짐
        showAfterCaptureSheet = true
    }

    // MARK: - 피드 사전 채움 텍스트/태그 생성
    /// 본문 — 루틴 제목 + 소요시간 + 단계수 + 작성자 크레딧
    private func feedPrefillContent() -> String {
        let minutes = max(1, elapsedSeconds / 60)
        let stepCount = totalCount
        let authorName = routine.profiles?.displayName ?? "익명"
        return """
        '\(routine.title)' 따라했어요!
        \(minutes)분 동안 \(stepCount)단계 진행했어요.

        작성자: \(authorName)
        """
    }

    /// 추천 해시태그 — 루틴 이름 + 일반 #루틴따라하기
    private func feedPrefillHashtags() -> [String] {
        let normalized = routine.title.components(separatedBy: .whitespacesAndNewlines).joined()
        var tags: [String] = ["#루틴따라하기"]
        if !normalized.isEmpty { tags.insert("#\(normalized)", at: 0) }
        return tags
    }

    /// Supabase 에서 넘어오는 ISO8601 문자열 파싱 (fractional seconds 포함/미포함 모두 지원)
    private func parseISO8601(_ str: String) -> Date? {
        let formatter1 = ISO8601DateFormatter()
        formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter1.date(from: str) { return date }

        let formatter2 = ISO8601DateFormatter()
        formatter2.formatOptions = [.withInternetDateTime]
        return formatter2.date(from: str)
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

// 하단 시트 카드 정의는 Views/Common/BottomActionCard.swift 로 이동 (공용)
