import SwiftUI

extension Font {
    /// Headlines: Space Grotesk (기하학적 산세리프)
    static func headline(_ size: CGFloat) -> Font {
        .custom("SpaceGrotesk-Bold", size: size)
    }

    static func headlineMedium(_ size: CGFloat) -> Font {
        .custom("SpaceGrotesk-Medium", size: size)
    }

    /// Body / Labels: Manrope (가독성 높은 산세리프)
    static func bodyText(_ size: CGFloat) -> Font {
        .custom("Manrope-Regular", size: size)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("Manrope-Medium", size: size)
    }

    static func bodySemiBold(_ size: CGFloat) -> Font {
        .custom("Manrope-SemiBold", size: size)
    }

    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("Manrope-Bold", size: size)
    }

    static func label(_ size: CGFloat) -> Font {
        .custom("Manrope-Medium", size: size)
    }
}

// MARK: - 타이포그래피 프리셋
extension Font {
    static let appTitle = Font.headline(32)
    static let appHeadline1 = Font.headline(24)
    static let appHeadline2 = Font.headline(20)
    static let appHeadline3 = Font.headlineMedium(18)
    static let appBody = Font.bodyText(16)
    static let appBodyMedium = Font.bodyMedium(16)
    static let appBodyBold = Font.bodyBold(16)
    static let appCaption = Font.bodyText(14)
    static let appCaptionMedium = Font.bodyMedium(14)
    static let appCaptionBold = Font.bodyBold(14)
    static let appSmall = Font.bodyText(12)
    static let appSmallBold = Font.bodyBold(12)
    static let appLabel = Font.label(14)
    static let appLabelSmall = Font.label(10)
}
