import SwiftUI

struct CreateRoutineView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var difficulty = 2
    @State private var steps: [StepDraft] = [StepDraft(order: 1, title: "", duration: nil)]
    @State private var products: [String] = [""]
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    var onComplete: () async -> Void

    struct StepDraft: Identifiable {
        let id = UUID()
        var order: Int
        var title: String
        var description: String = ""
        var duration: Int?
    }

    private var totalDuration: Int {
        steps.compactMap { $0.duration }.reduce(0, +)
    }

    private var canSubmit: Bool {
        !title.isEmpty && steps.allSatisfy({ !$0.title.isEmpty }) && !isLoading
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 히어로 헤더
                        heroHeader

                        // 폼 필드
                        formSection

                        // 난이도
                        difficultySection

                        // 단계 관리
                        stepsManagement

                        // 사용 제품
                        productsManagement

                        // 총 소요시간
                        if totalDuration > 0 {
                            totalTimeFooter
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appSmall)
                                .foregroundColor(.theme.error)
                        }
                    }
                    .padding(20)
                }
                .onTapGesture { hideKeyboard() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("취소")
                            .font(.appCaption)
                            .tracking(1)
                            .foregroundColor(.theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("루틴 등록")
                        .font(.appHeadline3)
                        .foregroundColor(.theme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submit) {
                        if isLoading {
                            ProgressView().tint(.theme.primary)
                        } else {
                            Text("등록")
                                .font(.system(size: 14, weight: .heavy))
                                .tracking(2)
                                .foregroundColor(canSubmit ? .theme.primaryContainer : .theme.textDisabled)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .alert("등록 완료", isPresented: $showSuccess) {
                Button("확인") { dismiss() }
            } message: {
                Text("루틴이 성공적으로 등록되었습니다!")
            }
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEW PROCEDURE")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundColor(.theme.primary)
            Text("새로운 루틴 설계")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            // 제목
            VStack(alignment: .leading, spacing: 6) {
                Text("ROUTINE TITLE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.theme.textSecondary)
                TextField("루틴의 이름을 입력하세요", text: $title)
                    .washHubTextField()
            }

            // 설명
            VStack(alignment: .leading, spacing: 6) {
                Text("DETAILED DESCRIPTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.theme.textSecondary)
                TextField("이 루틴에 대한 설명을 적어주세요", text: $description)
                    .washHubTextField()
            }
        }
    }

    // MARK: - Difficulty (Stitch: glow dots)
    private var difficultySection: some View {
        HStack {
            Text("DIFFICULTY LEVEL")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(.theme.textSecondary)

            Spacer()

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: { difficulty = level }) {
                        Circle()
                            .fill(level <= difficulty ? Color.theme.primary : Color.theme.surfaceHighest)
                            .frame(width: 12, height: 12)
                            .shadow(color: level <= difficulty ? Color.theme.primary.opacity(0.6) : .clear, radius: 4)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.theme.surfaceLow)
        .cornerRadius(12)
    }

    // MARK: - Steps Management (Stitch: drag handle + numbered + duration)
    private var stepsManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("단계 설정")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Button(action: addStep) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("단계 추가")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.theme.secondary)
                }
            }

            ForEach(steps.indices, id: \.self) { index in
                stepCard(index: index)
            }
        }
    }

    private func stepCard(index: Int) -> some View {
        HStack(spacing: 12) {
            // Drag indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(.theme.textDisabled)

            // 순번 원
            ZStack {
                Circle()
                    .fill(Color.theme.surfaceContainer)
                    .frame(width: 30, height: 30)
                Circle()
                    .stroke(Color.theme.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 30, height: 30)
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.theme.primary)
            }

            // 이름 + 시간
            VStack(spacing: 0) {
                TextField("단계 이름", text: $steps[index].title)
                    .font(.appCaption)
                    .foregroundColor(.theme.textPrimary)
            }

            // 시간 입력
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.theme.textDisabled)
                TextField("분", text: Binding(
                    get: { steps[index].duration.map { "\($0)" } ?? "" },
                    set: { steps[index].duration = Int($0) }
                ))
                .keyboardType(.numberPad)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.theme.primary)
                .frame(width: 32)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.theme.surfaceLow)
            .cornerRadius(8)

            // 삭제
            if steps.count > 1 {
                Button(action: { removeStep(at: index) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.theme.outlineVariant)
                }
            }
        }
        .padding(14)
        .background(Color.theme.surfaceHigh)
        .cornerRadius(16)
    }

    // MARK: - Products
    private var productsManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("사용 제품")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Button(action: { products.append("") }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("추가")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.theme.primary)
                }
            }

            // 추가된 제품 chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(products.indices, id: \.self) { index in
                        if !products[index].isEmpty {
                            HStack(spacing: 4) {
                                Text(products[index])
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.theme.textPrimary)
                                Button(action: { products.remove(at: index) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(.theme.outlineVariant)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.theme.surfaceHigh)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.theme.outlineVariant.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // 입력 필드 (마지막 비어있는 것만)
            if let lastIndex = products.indices.last, products[lastIndex].isEmpty {
                TextField("제품명 입력", text: $products[lastIndex])
                    .washHubTextField()
            }
        }
    }

    // MARK: - Total Time Footer
    private var totalTimeFooter: some View {
        HStack {
            Text("TOTAL ESTIMATED TIME")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(.theme.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(.theme.primaryContainer)
                Text("총 소요시간: \(totalDuration)분")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.primaryContainer)
            }
        }
        .padding(.top, 16)
        .overlay(
            Rectangle()
                .fill(Color.theme.surfaceHighest)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions
    private func addStep() {
        let newOrder = steps.count + 1
        steps.append(StepDraft(order: newOrder, title: "", duration: nil))
    }

    private func removeStep(at index: Int) {
        steps.remove(at: index)
        for i in steps.indices {
            steps[i].order = i + 1
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let service = RoutineService()
                _ = try await service.createRoutine(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    duration: totalDuration > 0 ? totalDuration : nil,
                    difficulty: difficulty,
                    steps: steps.enumerated().map { index, step in
                        RoutineService.StepInput(
                            order: index + 1,
                            title: step.title,
                            description: step.description.isEmpty ? nil : step.description,
                            duration: step.duration
                        )
                    },
                    products: products.filter { !$0.isEmpty }
                )

                await onComplete()
                showSuccess = true
            } catch {
                errorMessage = "등록 실패: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
