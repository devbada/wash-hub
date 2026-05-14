import SwiftUI

struct NicknameSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var isDuplicate = false
    @State private var isChecked = false
    @State private var errorMessage: String?
    @State private var showLogoutAlert = false

    /// 실시간 형식 검증 (길이 + 문자만). 욕설·사칭은 저장 직전에만 검사 (UX 우선)
    private var validationResult: Result<String, NicknameValidator.ValidationError> {
        Result { try NicknameValidator.validateFormat(nickname, minLength: 2, maxLength: 10) }
            .mapError { ($0 as? NicknameValidator.ValidationError) ?? .empty }
    }

    private var isValid: Bool {
        if case .success = validationResult { return true }
        return false
    }

    private var canSubmit: Bool {
        isValid && isChecked && !isDuplicate && !isLoading
    }

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // 헤더
                VStack(spacing: 8) {
                    Text("닉네임 설정")
                        .font(.appHeadline1)
                        .foregroundColor(.theme.textPrimary)

                    Text("WashHub에서 사용할 닉네임을 설정해주세요")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                }
                .padding(.top, 60)

                // 닉네임 입력
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("닉네임 (2~10자)", text: $nickname)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: nickname) {
                                isChecked = false
                                isDuplicate = false
                            }

                        Button("중복확인") {
                            checkDuplicate()
                        }
                        .font(.appLabel)
                        .foregroundColor(isValid ? .theme.onPrimary : .theme.textDisabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isValid ? Color.theme.primary : Color.theme.surfaceHigh)
                        .cornerRadius(8)
                        .disabled(!isValid || isLoading)
                    }
                    .padding(16)
                    .background(Color.theme.surfaceHigh)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(statusBorderColor, lineWidth: 1)
                    )

                    // 상태 메시지 — 형식 에러 우선, 그 다음 중복 결과
                    if !nickname.isEmpty, case .failure(let err) = validationResult {
                        Text(err.userMessage)
                            .font(.appSmall)
                            .foregroundColor(.theme.error)
                    } else if isChecked {
                        Text(isDuplicate ? "이미 사용 중인 닉네임입니다" : "사용 가능한 닉네임입니다")
                            .font(.appSmall)
                            .foregroundColor(isDuplicate ? .theme.error : .theme.tertiary)
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(.theme.error)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // 완료 버튼
                Button(action: submit) {
                    Text("완료")
                        .primaryButtonStyle()
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1.0 : 0.4)
                .padding(.horizontal, 24)

                // 로그아웃 (세션 만료/데이터 초기화 등으로 진행 불가 시)
                Button(action: { showLogoutAlert = true }) {
                    Text("다른 계정으로 로그인")
                        .font(.appCaption)
                        .foregroundColor(.theme.textDisabled)
                        .underline()
                }
                .padding(.bottom, 40)
            }
        }
        .alert("다시 로그인하시겠습니까?", isPresented: $showLogoutAlert) {
            Button("로그아웃", role: .destructive) {
                Task {
                    try? await authManager.signOut()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 세션을 종료하고 로그인 화면으로 돌아갑니다.")
        }
    }

    private var statusBorderColor: Color {
        if isChecked && !isDuplicate {
            return .theme.tertiary
        } else if isChecked && isDuplicate {
            return .theme.error
        }
        return .theme.border
    }

    private func checkDuplicate() {
        isLoading = true
        Task {
            do {
                isDuplicate = try await authManager.checkNicknameDuplicate(nickname)
                isChecked = true
            } catch {
                errorMessage = "중복 검사에 실패했습니다"
            }
            isLoading = false
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // 1) 저장 직전 전체 검증 — 형식 + 욕설 사전 + 사칭 (걸리면 실패)
                let validated = try NicknameValidator.validate(nickname, minLength: 2, maxLength: 10)

                // 2) 원격 욕설 검증 (Edge Function nickname-validate, korcen)
                try await NicknameValidator.validateProfanityRemote(validated)

                // 3) 닉네임 저장
                try await authManager.updateNickname(validated)
            } catch let err as NicknameValidator.ValidationError {
                errorMessage = err.userMessage
            } catch {
                // TODO-minam: 세션 만료/FK 위반 등 구체적 에러 분기 추가 고려
                print("닉네임 설정 에러: \(error)")
                errorMessage = "닉네임 설정에 실패했습니다. 아래 '다른 계정으로 로그인'을 눌러 재로그인해주세요."
            }
            isLoading = false
        }
    }
}
