import SwiftUI

/// 서비스 종료 일정과 개인정보 문의 경로를 최초 1회 명확하게 안내한다.
///
/// 공지를 확인해도 앱 내 회원 탈퇴 기능은 계속 제공한다. 최종 종료일까지
/// 백엔드·OAuth를 유지하는 것이 전제이며, 이 화면은 `ContentView`의 최상단에 표시된다.
struct ServiceSunsetNoticeView: View {
    let onAcknowledge: () -> Void

    private enum Sunset {
        static let endDate = "2026년 11월 9일 23:59 (KST)"
        static let inquiryEmail = "xsitherx@gmail.com"

        static var inquiryURL: URL {
            URL(string: "mailto:\(inquiryEmail)?subject=WashHub%20서비스%20종료%20문의")!
        }
    }

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    scheduleCard
                    dataGuidance
                    inquiry

                    Button(action: onAcknowledge) {
                        Text("안내를 확인했습니다")
                            .primaryButtonStyle()
                    }
                    .accessibilityHint("서비스 종료 안내를 닫고 앱을 계속 사용합니다.")
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(.theme.secondary)
                .accessibilityHidden(true)

            Text("WashHub 서비스 종료 안내")
                .font(.appHeadline1)
                .foregroundColor(.theme.textPrimary)

            Text("WashHub는 운영을 종료하게 되었습니다. 갑작스러운 안내를 드리게 되어 죄송합니다.")
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("최종 서비스 종료", systemImage: "calendar")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)

            Text(Sunset.endDate)
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            Text("종료일까지 기존 기능과 앱 내 회원 탈퇴를 이용할 수 있습니다. 종료일 이후에는 서비스와 데이터 조회가 불가능합니다.")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.theme.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dataGuidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("개인정보와 콘텐츠")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            Text("서비스 종료 전에는 마이페이지에서 회원 탈퇴를 요청할 수 있습니다. 종료 절차에서는 관련 법령에 따라 개인정보와 사용자 콘텐츠를 파기하거나, 보존 의무가 있는 최소 정보만 분리 보관합니다.")
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inquiry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("문의")
                .font(.appHeadline3)
                .foregroundColor(.theme.textPrimary)

            Text("개인정보 열람·삭제 등 궁금한 사항은 아래 이메일로 문의해 주세요.")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)

            Link(destination: Sunset.inquiryURL) {
                Label(Sunset.inquiryEmail, systemImage: "envelope")
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.secondary)
            }
            .accessibilityHint("이메일 앱에서 서비스 종료 문의를 작성합니다.")
        }
    }
}
