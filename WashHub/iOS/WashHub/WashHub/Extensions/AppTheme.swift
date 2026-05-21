import SwiftUI

/// 사용자가 설정에서 고를 수 있는 앱 테마 (Design System v3 — 12종)
///
/// rawValue 는 디자인 시스템/웹과 동일한 id 문자열을 사용한다.
/// 기존 4종 + pastel-explore 5종 + mono-explore 3종 = 총 12종.
enum AppTheme: String, CaseIterable, Identifiable {
    // 기존 4종
    case periwinkle
    case mistyBlue = "misty-blue"
    case sage
    case slatePink = "slate-pink"
    // pastel-explore 5종
    case lavender
    case peach
    case mintRose = "mint-rose"
    case butter
    case iris
    // mono-explore 3종 (모노톤)
    case monoNeutral = "mono-neutral"
    case monoWarm = "mono-warm"
    case monoCool = "mono-cool"

    var id: String { rawValue }

    /// 이 테마의 색상 팔레트
    var colors: ColorTheme {
        switch self {
        case .periwinkle:  return .periwinkle
        case .mistyBlue:   return .mistyBlue
        case .sage:        return .sage
        case .slatePink:   return .slatePink
        case .lavender:    return .lavender
        case .peach:       return .peach
        case .mintRose:    return .mintRose
        case .butter:      return .butter
        case .iris:        return .iris
        case .monoNeutral: return .monoNeutral
        case .monoWarm:    return .monoWarm
        case .monoCool:    return .monoCool
        }
    }

    /// 한글 이름
    var nameKo: String {
        switch self {
        case .periwinkle:  return "페리윙클 크림"
        case .mistyBlue:   return "미스티 블루 피치"
        case .sage:        return "세이지 라벤더"
        case .slatePink:   return "슬레이트 블루 핑크"
        case .lavender:    return "라벤더 스카이"
        case .peach:       return "복숭아 라떼"
        case .mintRose:    return "민트 로즈"
        case .butter:      return "버터 세이지"
        case .iris:        return "아이리스 살구"
        case .monoNeutral: return "중립 모노"
        case .monoWarm:    return "따뜻한 모노"
        case .monoCool:    return "시원한 모노"
        }
    }

    /// 영문 이름
    var nameEn: String {
        switch self {
        case .periwinkle:  return "Periwinkle Cream"
        case .mistyBlue:   return "Misty Blue Peach"
        case .sage:        return "Sage Lavender"
        case .slatePink:   return "Slate Blue Pink"
        case .lavender:    return "Lavender Sky"
        case .peach:       return "Peach Cream"
        case .mintRose:    return "Mint Rose"
        case .butter:      return "Butter Sage"
        case .iris:        return "Iris Apricot"
        case .monoNeutral: return "Neutral Mono"
        case .monoWarm:    return "Warm Mono"
        case .monoCool:    return "Cool Mono"
        }
    }

    /// 한 줄 무드 카피
    var mood: String {
        switch self {
        case .periwinkle:  return "몽글한 라벤더 블루 · 부드럽고 친근한 일상"
        case .mistyBlue:   return "안개 낀 새벽처럼 차분한 · 청결하고 신뢰감 있는"
        case .sage:        return "자연을 가까이 · 내추럴하고 안 질리는"
        case .slatePink:   return "디테일링 럭셔리 · 세련되고 페미닌한"
        case .lavender:    return "몽글몽글 라벤더 · 페미닌하고 향수 같은"
        case .peach:       return "따뜻한 카페 라떼 · 친근한 라이프스타일"
        case .mintRose:    return "민트초코 + 분홍 · 물·청결·신선의 느낌"
        case .butter:      return "자연과 웰니스 · 내추럴하고 안 질리는"
        case .iris:        return "모던하고 신뢰감 있는 · 안전한 중간 톤"
        case .monoNeutral: return "가장 기본 회색 · 순수하고 미디어 같은"
        case .monoWarm:    return "미색 종이 · 에디토리얼하고 친근한"
        case .monoCool:    return "슬레이트 회색 · 테크하고 프로페셔널한"
        }
    }
}
