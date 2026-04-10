import SwiftUI

extension Color {
    static let theme = ColorTheme()
}

// MARK: - Carbon & Citrus (Light Theme)
// 디자인 시스템: wash_hub/design-system/design.md
// Creative North Star: "Precision Detailing Bay"
// Carbon Black(#18181B) + Olive/Citrus Accent(#65A30D) + Pristine Off-White(#FAFAFA)
struct ColorTheme {
    // MARK: - Primary (Carbon Black)

    /// Carbon — 핵심 CTA, 브랜드, 본문 텍스트 - #18181B
    let primary = Color(red: 24/255, green: 24/255, blue: 27/255)

    /// Dimmed Primary — Pressed/Hover - #09090B
    let primaryDim = Color(red: 9/255, green: 9/255, blue: 11/255)

    /// Primary Container — Secondary 버튼 배경 - #27272A
    let primaryContainer = Color(red: 39/255, green: 39/255, blue: 42/255)

    // MARK: - Secondary (Citrus Olive — 브랜드 액센트)

    /// Olive Green — 브랜드 액센트, 강조, 선택 상태 - #65A30D
    let secondary = Color(red: 101/255, green: 163/255, blue: 13/255)

    /// Olive Dim — Pressed 상태 - #4D7C0F
    let secondaryDim = Color(red: 77/255, green: 124/255, blue: 15/255)

    // MARK: - Tertiary / Accent (Citrus Bright)

    /// Olive Bright — 서브 강조 (차량 태그 등) - #84CC16
    let tertiary = Color(red: 132/255, green: 204/255, blue: 22/255)

    /// Olive Bright — 정보/하이라이트 - #84CC16
    let infoBlue = Color(red: 132/255, green: 204/255, blue: 22/255)

    // MARK: - Error

    /// 에러/위험 - #DC2626
    let error = Color(red: 220/255, green: 38/255, blue: 38/255)

    /// 에러 Dim - #991B1B
    let errorDim = Color(red: 153/255, green: 27/255, blue: 27/255)

    // MARK: - Surface Hierarchy (Zinc Scale, Tonal Layering)

    /// 메인 페이지 배경 - #FAFAFA
    let surface = Color(red: 250/255, green: 250/255, blue: 250/255)

    /// 순백 — 카드/Floating 요소 - #FFFFFF
    let surfaceLowest = Color.white

    /// 인셋 섹션 배경 - #F4F4F5
    let surfaceLow = Color(red: 244/255, green: 244/255, blue: 245/255)

    /// 보조 카드 배경 - #E4E4E7
    let surfaceContainer = Color(red: 228/255, green: 228/255, blue: 231/255)

    /// Secondary 버튼 배경 - #F4F4F5
    let surfaceHigh = Color(red: 244/255, green: 244/255, blue: 245/255)

    /// 입력 필드, 칩 배경 - #E4E4E7
    let surfaceHighest = Color(red: 228/255, green: 228/255, blue: 231/255)

    /// 강조 Surface (순백 얼라이어스) - #FFFFFF
    let surfaceBright = Color.white

    // MARK: - Text (Zinc Scale, 순수 검정 금지)

    /// 본문/헤드라인 — Carbon Black - #18181B
    let textPrimary = Color(red: 24/255, green: 24/255, blue: 27/255)

    /// 메타/보조 텍스트 — Zinc 500 - #71717A
    let textSecondary = Color(red: 113/255, green: 113/255, blue: 122/255)

    /// 비활성/플레이스홀더 — Zinc 400 - #A1A1AA
    let textDisabled = Color(red: 161/255, green: 161/255, blue: 170/255)

    /// Variant 텍스트 — Zinc 600 - #52525B
    let onSurfaceVariant = Color(red: 82/255, green: 82/255, blue: 91/255)

    // MARK: - Outline (Ghost Border)

    /// Ghost Border — 15% opacity - #D4D4D8
    let border = Color(red: 212/255, green: 212/255, blue: 216/255).opacity(0.5)

    /// 아웃라인 — Zinc 300 - #D4D4D8
    let outline = Color(red: 212/255, green: 212/255, blue: 216/255)

    /// 아웃라인 variant — Zinc 200 - #E4E4E7
    let outlineVariant = Color(red: 228/255, green: 228/255, blue: 231/255)

    // MARK: - On Colors (반전 텍스트)

    /// primary(Carbon) 배경 위 텍스트 - #FAFAFA
    let onPrimary = Color(red: 250/255, green: 250/255, blue: 250/255)

    /// primaryContainer 위 텍스트 - #FAFAFA
    let onPrimaryContainer = Color(red: 250/255, green: 250/255, blue: 250/255)

    // MARK: - Legacy / Compatibility

    /// 카카오 노랑
    let kakaoYellow = Color(red: 254/255, green: 229/255, blue: 0/255)

    /// neutral (기존 호환) - surface 와 동일 매핑
    var neutral: Color { surface }
}
