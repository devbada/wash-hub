import SwiftUI
import UIKit

/// 앱 시작 시 1.5초간 노출되는 스플래시
///
/// - 현재 사용자의 세차 단계(alternateIconName) 에 맞는 아이콘을 크게 표시
/// - 앱 이름 + 슬로건 노출
/// - LaunchScreen(iOS 단색) → SwiftUI 부팅 → 이 스플래시 → 메인 ContentView 순서
///
/// iOS 18+ 부터 alternate icon 이 Assets.car 에 묶여 직접 로드 불가 → 별도 ImageSet 사용
struct SplashView: View {
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

                // 앱 이름 + Beta 배지 + 슬로건
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("WashHub")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundColor(.theme.textPrimary)
                            .tracking(-0.5)
                        BetaBadge(variant: .large)
                    }

                    Text("비가 와도 세차")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                        .tracking(2)
                }
            }
        }
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
