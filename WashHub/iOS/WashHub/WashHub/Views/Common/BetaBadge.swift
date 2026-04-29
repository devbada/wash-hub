import SwiftUI

/// "BETA" 라벨 — WashHub 로고 옆에 superscript 처럼 살짝 위에 부착하는 캡슐 배지
///
/// - 디자인 시스템(Carbon & Citrus)의 Citrus 그라데이션을 사용
/// - tertiary(밝은 Citrus) → secondary(짙은 Citrus) 의 미세한 톤 변화
/// - 화이트 텍스트 + 미세 그림자로 살짝 떠 있는 느낌
///
/// 사용 예:
/// ```swift
/// HStack(alignment: .firstTextBaseline, spacing: 6) {
///     Text("WashHub").font(.headline(24)).foregroundColor(.theme.secondary)
///     BetaBadge()
/// }
/// ```
struct BetaBadge: View {
    /// 표시 변형 — 메인 헤더용(.compact) / 스플래시용(.large)
    enum Variant {
        case compact
        case large
    }

    var variant: Variant = .compact

    var body: some View {
        Text("BETA")
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .tracking(1.0)
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 132/255, green: 204/255, blue: 22/255),  // #84CC16 tertiary
                                Color(red: 101/255, green: 163/255, blue: 13/255)   // #65A30D secondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(
                color: Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.28),
                radius: variant == .large ? 6 : 3,
                x: 0,
                y: variant == .large ? 3 : 1.5
            )
            .offset(y: yOffset)   // 헤더에서는 살짝 위로 띄워 superscript 효과
    }

    private var fontSize: CGFloat {
        variant == .large ? 13 : 10
    }

    private var horizontalPadding: CGFloat {
        variant == .large ? 10 : 7
    }

    private var verticalPadding: CGFloat {
        variant == .large ? 4 : 3
    }

    private var yOffset: CGFloat {
        variant == .large ? 0 : -3
    }
}

#Preview {
    VStack(spacing: 32) {
        // 헤더용 (compact)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("WashHub")
                .font(.headline(24))
                .foregroundColor(.theme.secondary)
            BetaBadge()
        }

        // 스플래시용 (large)
        HStack(spacing: 10) {
            Text("WashHub")
                .font(.appTitle)
                .foregroundColor(.theme.secondary)
            BetaBadge(variant: .large)
        }
    }
    .padding(40)
    .background(Color.theme.surface)
}
