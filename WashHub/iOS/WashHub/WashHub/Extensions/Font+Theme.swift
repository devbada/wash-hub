import SwiftUI

extension Font {
    /// Headlines: Space Grotesk
    static func headline(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom("SpaceGrotesk-Bold", size: size, relativeTo: textStyle)
    }

    static func headlineMedium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom("SpaceGrotesk-Medium", size: size, relativeTo: textStyle)
    }

    /// Body / Labels: Manrope
    static func bodyText(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Manrope-Regular", size: size, relativeTo: textStyle)
    }

    static func bodyMedium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Manrope-Medium", size: size, relativeTo: textStyle)
    }

    static func bodySemiBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Manrope-SemiBold", size: size, relativeTo: textStyle)
    }

    static func bodyBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Manrope-Bold", size: size, relativeTo: textStyle)
    }

    static func label(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .callout) -> Font {
        .custom("Manrope-Medium", size: size, relativeTo: textStyle)
    }
}

// MARK: - 타이포그래피 프리셋
extension Font {
    static let appTitle = Font.headline(32, relativeTo: .largeTitle)
    static let appHeadline1 = Font.headline(24, relativeTo: .title2)
    static let appHeadline2 = Font.headline(20, relativeTo: .title3)
    static let appHeadline3 = Font.headlineMedium(18, relativeTo: .headline)
    static let appBody = Font.bodyText(16)
    static let appBodyMedium = Font.bodyMedium(16)
    static let appBodyBold = Font.bodyBold(16)
    static let appCaption = Font.bodyText(14, relativeTo: .callout)
    static let appCaptionMedium = Font.bodyMedium(14, relativeTo: .callout)
    static let appCaptionBold = Font.bodyBold(14, relativeTo: .callout)
    static let appSmall = Font.bodyText(12, relativeTo: .caption)
    static let appSmallBold = Font.bodyBold(12, relativeTo: .caption)
    static let appLabel = Font.label(14, relativeTo: .callout)
    static let appLabelSmall = Font.label(12, relativeTo: .caption)
}
