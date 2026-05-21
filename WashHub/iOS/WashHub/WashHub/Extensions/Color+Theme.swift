import SwiftUI

extension Color {
    /// 현재 적용 중인 테마 색상. ThemeManager 가 테마 변경 시 갱신한다.
    /// (앱 전반이 `Color.theme.xxx` 로 참조하므로 전역 var 로 둔다.)
    nonisolated(unsafe) static var theme: ColorTheme = .periwinkle

    /// 0xRRGGBB 정수로 Color 생성
    init(hex: UInt) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Pastel Theme Collection (Design System v3)
//
// 검정 기반 Carbon & Citrus 폐기. 사용자가 고르는 4종 파스텔 테마.
// 디자인 시스템: design-system/re-design-v2/WashHub Design System/DESIGN.md
//
// 구조: 디자이너가 확정한 토큰을 스토어드 프로퍼티로 보관하고,
// 앱 전반에서 쓰는 기존 토큰명(secondary, surfaceHigh 등)은 파생 접근자로 노출한다.
// 이렇게 하면 4개 테마를 갈아끼워도 호출부 수정이 필요 없다.
struct ColorTheme {

    // MARK: 스토어드 토큰 (테마별 정의)

    /// 메인 브랜드 / CTA — #RRGGBB
    let primary: Color
    /// Pressed / Hover
    let primaryDim: Color
    /// 보조 CTA, 밝은 primary 톤
    let primaryContainer: Color
    /// primary 배경 위 텍스트
    let onPrimary: Color

    /// 파스텔 액센트 (peach / lavender / pink)
    let accent: Color
    /// 밝은 액센트
    let accentBright: Color
    /// 액센트 틴트 배경 (저투명)
    let accentBg: Color
    /// 액센트 배경 위 텍스트
    let onAccent: Color

    /// 메인 페이지 배경
    let surface: Color
    /// 카드 / Floating — 순백
    let surfaceLowest: Color
    /// 인셋 섹션 배경
    let surfaceLow: Color
    /// 보조 카드 / 칩 배경
    let surfaceContainer: Color

    /// 본문 / 헤드라인 텍스트
    let textPrimary: Color
    /// 메타 / 보조 텍스트
    let textSecondary: Color
    /// Variant 텍스트
    let onSurfaceVariant: Color
    /// 아웃라인 (Ghost Border)
    let outline: Color

    /// 에러
    let error: Color
    /// 에러 배경 틴트
    let errorContainer: Color

    /// 카카오 노랑 — 테마 무관 고정 브랜드 컬러
    let kakaoYellow = Color(hex: 0xFEE500)

    // MARK: 파생 / 호환 접근자
    //
    // 기존 코드가 쓰던 토큰명을 유지한다. 파스텔 테마에서는 가독성을 위해
    // 강조색(secondary/tertiary)을 텍스트로도 안전한 primary 계열로 매핑한다.

    /// 강조색 — primary 계열 (텍스트로도 안전한 대비 확보)
    var secondary: Color { primary }
    var secondaryDim: Color { primaryDim }
    /// 서브 강조 — primary 계열
    var tertiary: Color { primary }
    /// 정보 강조
    var infoBlue: Color { primary }
    /// 깊은 에러
    var errorDim: Color { error }

    /// Secondary 버튼 배경
    var surfaceHigh: Color { surfaceLow }
    /// 입력 필드 / 칩 배경
    var surfaceHighest: Color { surfaceContainer }
    /// 강조 Surface (순백 얼라이어스)
    var surfaceBright: Color { surfaceLowest }

    /// 아웃라인 variant (Ghost Border)
    var outlineVariant: Color { outline }
    /// 호환용 얇은 테두리
    var border: Color { outline.opacity(0.5) }
    /// 비활성 / 플레이스홀더 텍스트
    var textDisabled: Color { textSecondary.opacity(0.55) }
    /// primaryContainer 위 텍스트
    var onPrimaryContainer: Color { onPrimary }
    /// 기존 호환 — surface 와 동일
    var neutral: Color { surface }

    /// 주 그라데이션 (밝은 → 진한 primary)
    var primaryGradient: [Color] { [primaryContainer, primary] }
}

// MARK: - 4개 테마 팔레트 (디자이너 확정값 — DESIGN.md §2)

extension ColorTheme {

    /// 테마 A — Periwinkle Cream (기본)
    static let periwinkle = ColorTheme(
        primary:          Color(hex: 0x7383D6),
        primaryDim:       Color(hex: 0x5C6DC4),
        primaryContainer: Color(hex: 0xA0AEE4),
        onPrimary:        .white,
        accent:           Color(hex: 0xF2BEA0),
        accentBright:     Color(hex: 0xF8D3BB),
        accentBg:         Color(hex: 0xF2BEA0).opacity(0.18),
        onAccent:         Color(hex: 0x5C3B33),
        surface:          Color(hex: 0xFAF8F2),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xEFEEF9),
        surfaceContainer: Color(hex: 0xDBDCF0),
        textPrimary:      Color(hex: 0x2D3563),
        textSecondary:    Color(hex: 0x7C85AD),
        onSurfaceVariant: Color(hex: 0x5A6488),
        outline:          Color(hex: 0xCFD4EE),
        error:            Color(hex: 0xC76851),
        errorContainer:   Color(hex: 0xFFE2D8)
    )

    /// 테마 B — Misty Blue Peach
    static let mistyBlue = ColorTheme(
        primary:          Color(hex: 0x6E97B8),
        primaryDim:       Color(hex: 0x547F9F),
        primaryContainer: Color(hex: 0x9DB8CE),
        onPrimary:        .white,
        accent:           Color(hex: 0xF4A78B),
        accentBright:     Color(hex: 0xF9C2AB),
        accentBg:         Color(hex: 0xF4A78B).opacity(0.16),
        onAccent:         Color(hex: 0x5C2F22),
        surface:          Color(hex: 0xF6F9FC),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xE7EFF6),
        surfaceContainer: Color(hex: 0xD2DFEB),
        textPrimary:      Color(hex: 0x27425C),
        textSecondary:    Color(hex: 0x7E97AD),
        onSurfaceVariant: Color(hex: 0x536F87),
        outline:          Color(hex: 0xC7D4DE),
        error:            Color(hex: 0xC2604E),
        errorContainer:   Color(hex: 0xFFE7DB)
    )

    /// 테마 C — Sage Lavender
    static let sage = ColorTheme(
        primary:          Color(hex: 0x7B9C84),
        primaryDim:       Color(hex: 0x5E826A),
        primaryContainer: Color(hex: 0xA7C0AE),
        onPrimary:        .white,
        accent:           Color(hex: 0x9D8DCE),
        accentBright:     Color(hex: 0xB7ABDC),
        accentBg:         Color(hex: 0x9D8DCE).opacity(0.16),
        onAccent:         .white,
        surface:          Color(hex: 0xF6FAF6),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xE9F1EA),
        surfaceContainer: Color(hex: 0xD6E2D8),
        textPrimary:      Color(hex: 0x2F4636),
        textSecondary:    Color(hex: 0x7E9784),
        onSurfaceVariant: Color(hex: 0x536C5B),
        outline:          Color(hex: 0xC5D2C8),
        error:            Color(hex: 0xC76B85),
        errorContainer:   Color(hex: 0xFFE0E7)
    )

    /// 테마 D — Slate Blue Pink
    static let slatePink = ColorTheme(
        primary:          Color(hex: 0x5F73A0),
        primaryDim:       Color(hex: 0x485B86),
        primaryContainer: Color(hex: 0x92A2C3),
        onPrimary:        .white,
        accent:           Color(hex: 0xE0A6BA),
        accentBright:     Color(hex: 0xEDBECC),
        accentBg:         Color(hex: 0xE0A6BA).opacity(0.18),
        onAccent:         Color(hex: 0x4B243A),
        surface:          Color(hex: 0xF7F8FC),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xE8EAF3),
        surfaceContainer: Color(hex: 0xD3D8E5),
        textPrimary:      Color(hex: 0x2A335A),
        textSecondary:    Color(hex: 0x7C84A3),
        onSurfaceVariant: Color(hex: 0x525B7E),
        outline:          Color(hex: 0xC5CADE),
        error:            Color(hex: 0xB85572),
        errorContainer:   Color(hex: 0xFFE3EB)
    )

    // pastel-explore.html 추가 시안 5종.
    // primaryDim 은 시안에 없어 primary 를 약 18% 어둡게 보정한 값.

    /// 테마 E — Lavender Sky
    static let lavender = ColorTheme(
        primary:          Color(hex: 0x7C6BB8),
        primaryDim:       Color(hex: 0x665897),
        primaryContainer: Color(hex: 0xA89BD9),
        onPrimary:        .white,
        accent:           Color(hex: 0x7FB8E0),
        accentBright:     Color(hex: 0xA8D0EC),
        accentBg:         Color(hex: 0x7FB8E0).opacity(0.15),
        onAccent:         .white,
        surface:          Color(hex: 0xFAF8FE),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xF2EEFB),
        surfaceContainer: Color(hex: 0xE5DDF5),
        textPrimary:      Color(hex: 0x3D3551),
        textSecondary:    Color(hex: 0x897FA8),
        onSurfaceVariant: Color(hex: 0x6B6188),
        outline:          Color(hex: 0xDCD3EE),
        error:            Color(hex: 0xD67196),
        errorContainer:   Color(hex: 0xFFE4E9)
    )

    /// 테마 F — Peach Cream
    static let peach = ColorTheme(
        primary:          Color(hex: 0xC97B6E),
        primaryDim:       Color(hex: 0xA5655A),
        primaryContainer: Color(hex: 0xE5A599),
        onPrimary:        .white,
        accent:           Color(hex: 0xF4A78B),
        accentBright:     Color(hex: 0xF9C2AB),
        accentBg:         Color(hex: 0xF4A78B).opacity(0.16),
        onAccent:         Color(hex: 0x5C2F22),
        surface:          Color(hex: 0xFFF8F4),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xFCEFE7),
        surfaceContainer: Color(hex: 0xF7DECF),
        textPrimary:      Color(hex: 0x5C3B33),
        textSecondary:    Color(hex: 0xA5806F),
        onSurfaceVariant: Color(hex: 0x7E5B4F),
        outline:          Color(hex: 0xF0D5C6),
        error:            Color(hex: 0xC2604E),
        errorContainer:   Color(hex: 0xFEE7DB)
    )

    /// 테마 G — Mint Rose
    static let mintRose = ColorTheme(
        primary:          Color(hex: 0x5B9B91),
        primaryDim:       Color(hex: 0x4B7F77),
        primaryContainer: Color(hex: 0x88BEB5),
        onPrimary:        .white,
        accent:           Color(hex: 0xE89BB0),
        accentBright:     Color(hex: 0xF2B8C8),
        accentBg:         Color(hex: 0xE89BB0).opacity(0.16),
        onAccent:         .white,
        surface:          Color(hex: 0xF5FAF8),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xE8F3F0),
        surfaceContainer: Color(hex: 0xD7E9E4),
        textPrimary:      Color(hex: 0x2E544D),
        textSecondary:    Color(hex: 0x7E9C95),
        onSurfaceVariant: Color(hex: 0x577670),
        outline:          Color(hex: 0xC8DDD7),
        error:            Color(hex: 0xC76B85),
        errorContainer:   Color(hex: 0xFFE0E7)
    )

    /// 테마 H — Butter Sage
    static let butter = ColorTheme(
        primary:          Color(hex: 0x9CAA7B),
        primaryDim:       Color(hex: 0x808B65),
        primaryContainer: Color(hex: 0xC0CB9F),
        onPrimary:        .white,
        accent:           Color(hex: 0xE8C56A),
        accentBright:     Color(hex: 0xF0D78A),
        accentBg:         Color(hex: 0xE8C56A).opacity(0.18),
        onAccent:         Color(hex: 0x3F2F0F),
        surface:          Color(hex: 0xFBF9F2),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xF3F0E2),
        surfaceContainer: Color(hex: 0xE8E2CC),
        textPrimary:      Color(hex: 0x3F4730),
        textSecondary:    Color(hex: 0x929B7E),
        onSurfaceVariant: Color(hex: 0x717A5A),
        outline:          Color(hex: 0xD9D5BD),
        error:            Color(hex: 0xC2604E),
        errorContainer:   Color(hex: 0xFFE0D6)
    )

    /// 테마 I — Iris Apricot
    static let iris = ColorTheme(
        primary:          Color(hex: 0x6B7BC4),
        primaryDim:       Color(hex: 0x5865A1),
        primaryContainer: Color(hex: 0x9EAAD9),
        onPrimary:        .white,
        accent:           Color(hex: 0xF2B591),
        accentBright:     Color(hex: 0xF8CFB3),
        accentBg:         Color(hex: 0xF2B591).opacity(0.18),
        onAccent:         Color(hex: 0x5C3219),
        surface:          Color(hex: 0xF6F7FD),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xE9EDFA),
        surfaceContainer: Color(hex: 0xD6DEF3),
        textPrimary:      Color(hex: 0x2F3559),
        textSecondary:    Color(hex: 0x7B85AC),
        onSurfaceVariant: Color(hex: 0x5A6488),
        outline:          Color(hex: 0xCFD7EE),
        error:            Color(hex: 0xC76B57),
        errorContainer:   Color(hex: 0xFFE3DC)
    )

    // mono-explore.html 모노톤(단색 모드) 3종.
    // 액센트도 무채색이라 색 피로 없이 타이포·레이아웃으로 정보 전달.

    /// 테마 J — Neutral Mono
    static let monoNeutral = ColorTheme(
        primary:          Color(hex: 0x404040),
        primaryDim:       Color(hex: 0x343434),
        primaryContainer: Color(hex: 0x525252),
        onPrimary:        .white,
        accent:           Color(hex: 0x525252),
        accentBright:     Color(hex: 0x737373),
        accentBg:         Color(hex: 0x525252).opacity(0.10),
        onAccent:         .white,
        surface:          Color(hex: 0xFAFAFA),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xF5F5F5),
        surfaceContainer: Color(hex: 0xE5E5E5),
        textPrimary:      Color(hex: 0x171717),
        textSecondary:    Color(hex: 0x737373),
        onSurfaceVariant: Color(hex: 0x525252),
        outline:          Color(hex: 0xD4D4D4),
        error:            Color(hex: 0xDC2626),
        errorContainer:   Color(hex: 0xFEE2E2)
    )

    /// 테마 K — Warm Mono
    static let monoWarm = ColorTheme(
        primary:          Color(hex: 0x44403C),
        primaryDim:       Color(hex: 0x383431),
        primaryContainer: Color(hex: 0x57534E),
        onPrimary:        .white,
        accent:           Color(hex: 0x57534E),
        accentBright:     Color(hex: 0x78716C),
        accentBg:         Color(hex: 0x57534E).opacity(0.10),
        onAccent:         .white,
        surface:          Color(hex: 0xFAF9F7),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xF5F4F1),
        surfaceContainer: Color(hex: 0xE7E5E0),
        textPrimary:      Color(hex: 0x1C1917),
        textSecondary:    Color(hex: 0x78716C),
        onSurfaceVariant: Color(hex: 0x57534E),
        outline:          Color(hex: 0xD6D3CE),
        error:            Color(hex: 0xB91C1C),
        errorContainer:   Color(hex: 0xFEE2E2)
    )

    /// 테마 L — Cool Mono
    static let monoCool = ColorTheme(
        primary:          Color(hex: 0x334155),
        primaryDim:       Color(hex: 0x2A3546),
        primaryContainer: Color(hex: 0x475569),
        onPrimary:        .white,
        accent:           Color(hex: 0x475569),
        accentBright:     Color(hex: 0x64748B),
        accentBg:         Color(hex: 0x475569).opacity(0.10),
        onAccent:         .white,
        surface:          Color(hex: 0xF8FAFC),
        surfaceLowest:    .white,
        surfaceLow:       Color(hex: 0xF1F5F9),
        surfaceContainer: Color(hex: 0xE2E8F0),
        textPrimary:      Color(hex: 0x0F172A),
        textSecondary:    Color(hex: 0x64748B),
        onSurfaceVariant: Color(hex: 0x475569),
        outline:          Color(hex: 0xCBD5E1),
        error:            Color(hex: 0xDC2626),
        errorContainer:   Color(hex: 0xFEE2E2)
    )
}
