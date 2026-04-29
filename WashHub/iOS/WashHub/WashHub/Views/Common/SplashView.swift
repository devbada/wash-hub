import SwiftUI
import UIKit

/// 앱 시작 시 1.5초간 노출되는 스플래시
///
/// - 현재 사용자의 세차 단계(alternateIconName) 에 맞는 아이콘을 크게 표시
/// - 앱 이름 + 매번 랜덤 슬로건
/// - LaunchScreen(iOS 단색) → SwiftUI 부팅 → 이 스플래시 → 메인 ContentView 순서
///
/// iOS 18+ 부터 alternate icon 이 Assets.car 에 묶여 직접 로드 불가 → 별도 ImageSet 사용
struct SplashView: View {
    /// 매 진입마다 새 슬로건 — 인스턴스 생성 시 1회 결정
    @State private var slogan: String = SplashSlogans.random()

    /// 현재 alternateIconName 에서 매핑된 표시용 ImageSet 이름
    private var stageImageName: String {
        Self.stageImageName(for: UIApplication.shared.alternateIconName)
    }

    /// alternate icon name → ImageSet 이름 매핑
    /// - nil = Primary(Just Washed)
    /// - DynamicIconService.iconName 의 반환값 5종에 1:1 대응
    static func stageImageName(for alternateIconName: String?) -> String {
        switch alternateIconName {
        case "AppIconClean":   return "WashStageClean"
        case "AppIconNormal":  return "WashStageNormal"
        case "AppIconDirty":   return "WashStageDirty"
        case "AppIconWashMe":  return "WashStageWashMe"
        default:               return "WashStageJustWashed"  // nil 또는 미지값 = Primary
        }
    }

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 28) {
                // 동적 아이콘 — 현재 세차 단계
                Image(stageImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    // iOS 홈 화면 아이콘처럼 둥근 사각형 마스크 (Squircle 근사)
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                    .shadow(color: Color.theme.primary.opacity(0.18), radius: 28, x: 0, y: 12)

                // 앱 이름 + Beta 배지 + 랜덤 슬로건
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("WashHub")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundColor(.theme.textPrimary)
                            .tracking(-0.5)
                        BetaBadge(variant: .large)
                    }

                    Text(slogan)
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                        .tracking(2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
            }
        }
    }
}

/// 스플래시 슬로건 풀 — 매 실행마다 랜덤 1개 노출하여 사용자에게 신선함 + 약간의 위트
enum SplashSlogans {
    static let all: [String] = [
        "비가 와도 세차",
        "오늘도 반짝, 내 차의 하루",
        "광택은 마음의 평화",
        "닦을수록 빛나는 하루",
        "더러움은 잠깐, 만족은 오래",
        "차에 진심인 사람들의 모임",
        "한 번 더 닦으면 한 번 더 새 차",
        "손맛으로 빛나는 드라이브",
        "셀프세차의 미학",
        "도장 하나, 마음 한 줌",
        "광택이 곧 인격",
        "세차장에서 만나요",
        "물기 한 방울도 허락하지 않는다",
        "오늘의 세차, 내일의 자존감",
        "비 오는 날엔 광이 난다"
    ]

    /// 랜덤 1개 — 가중치 없이 균등
    static func random() -> String {
        all.randomElement() ?? "비가 와도 세차"
    }
}

#if DEBUG
struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
            .preferredColorScheme(.light)
    }
}
#endif
