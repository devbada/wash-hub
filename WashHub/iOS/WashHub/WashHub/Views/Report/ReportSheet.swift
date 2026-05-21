import SwiftUI

// MARK: - 신고 다이얼로그
struct ReportSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var reportService = ReportService()

    let targetType: ReportTargetType
    let targetId: String

    /// 신고 완료 후 추가 동작 (차단 제안 등)
    var onReported: (() -> Void)?

    @State private var selectedReason: ReportReason?
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 안내 문구
                        VStack(alignment: .leading, spacing: 8) {
                            Text("신고 사유를 선택해주세요")
                                .font(.appHeadline3)
                                .foregroundColor(.theme.textPrimary)
                            Text("허위 신고 시 서비스 이용이 제한될 수 있습니다.")
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                        }

                        // 사유 선택
                        VStack(spacing: 8) {
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                Button(action: { selectedReason = reason }) {
                                    HStack {
                                        Image(systemName: selectedReason == reason
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                            .foregroundColor(selectedReason == reason
                                                             ? .theme.secondary
                                                             : .theme.textDisabled)
                                            .font(.system(size: 20))

                                        Text(reason.displayName)
                                            .font(.appBody)
                                            .foregroundColor(.theme.textPrimary)

                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedReason == reason
                                                  ? Color.theme.accent.opacity(0.08)
                                                  : Color.theme.surfaceLowest)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedReason == reason
                                                    ? Color.theme.accent.opacity(0.3)
                                                    : Color.theme.border,
                                                    lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 상세 설명 (선택)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("상세 설명 (선택)")
                                    .font(.appLabel)
                                    .foregroundColor(.theme.textSecondary)
                                Spacer()
                                Text("\(description.count)/500")
                                    .font(.appSmall)
                                    .foregroundColor(description.count > 500 ? .theme.error : .theme.textDisabled)
                            }

                            TextEditor(text: $description)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.theme.surfaceLowest)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.theme.border, lineWidth: 1)
                                )
                                .onAppear {
                                    UITextView.appearance().backgroundColor = .clear
                                }
                                .onChange(of: description) { _, newValue in
                                    if newValue.count > 500 {
                                        description = String(newValue.prefix(500))
                                    }
                                }
                        }

                        // 에러 메시지
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                        }

                        // 제출 버튼
                        Button(action: submitReport) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("신고하기")
                                    .primaryButtonStyle()
                            }
                        }
                        .disabled(selectedReason == nil || isSubmitting)
                        .opacity(selectedReason == nil ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
            .navigationTitle("신고")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .alert("신고 완료", isPresented: $showSuccess) {
                Button("확인") {
                    dismiss()
                    onReported?()
                }
            } message: {
                Text("신고가 접수되었습니다.\n검토 후 적절한 조치를 취하겠습니다.")
            }
        }
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await reportService.createReport(
                    targetType: targetType,
                    targetId: targetId,
                    reason: reason,
                    description: description.isEmpty ? nil : description
                )
                showSuccess = true
            } catch {
                // TODO-minam: 중복 신고 에러 코드 세분화
                if "\(error)".contains("duplicate") || "\(error)".contains("unique") {
                    errorMessage = "이미 신고한 대상입니다."
                } else {
                    errorMessage = "신고 처리에 실패했습니다. 잠시 후 다시 시도해주세요."
                }
                print("Report submit error: \(error)")
            }
            isSubmitting = false
        }
    }
}
