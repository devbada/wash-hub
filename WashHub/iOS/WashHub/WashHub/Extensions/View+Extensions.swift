import SwiftUI
import UIKit

// MARK: - UIImage 리사이즈/압축 유틸
// 원본 iPhone 사진은 쉽게 10-20MB 에 달해 Supabase Storage 제한(5MB)을 초과한다.
// 업로드 전에 긴 변 기준 리사이즈 + JPEG 품질 단계적 축소로 타겟 용량 이하를 보장한다.
extension UIImage {

    /// 긴 변이 `maxDimension` 이하가 되도록 비율 유지 리사이즈.
    func resized(maxDimension: CGFloat = 1024) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// `maxBytes` 이하의 JPEG Data 로 인코딩 (리사이즈 + 품질 단계 축소).
    /// - Parameters:
    ///   - maxDimension: 긴 변 최대 픽셀 수 (default 1024)
    ///   - maxBytes: 허용 최대 바이트 수 (default 2MB)
    func jpegDataUnder(maxDimension: CGFloat = 1024, maxBytes: Int = 2 * 1024 * 1024) -> Data? {
        let resizedImage = self.resized(maxDimension: maxDimension)
        let qualities: [CGFloat] = [0.85, 0.7, 0.55, 0.4, 0.25]

        for quality in qualities {
            if let data = resizedImage.jpegData(compressionQuality: quality),
               data.count <= maxBytes {
                return data
            }
        }
        // 최저 품질로도 실패 시 — 호출 측에서 사이즈 재검증 필요
        return resizedImage.jpegData(compressionQuality: 0.25)
    }
}

// MARK: - 공통 View Modifier (Electric Neon Premium Design System)
extension View {

    /// WashHub 카드 스타일 — No-Line Rule: 보더 없이 tonal layering
    func cardStyle() -> some View {
        self
            .background(Color.theme.surfaceLow)
            .cornerRadius(16)
    }

    /// WashHub 상승 카드 — 인터렉티브 카드용
    func elevatedCardStyle() -> some View {
        self
            .background(Color.theme.surfaceContainer)
            .cornerRadius(16)
            .shadow(color: Color.theme.primaryDim.opacity(0.08), radius: 20, x: 0, y: 8)
    }

    /// Speed-line 카드 — 좌측 primary 강조선 포함
    func speedLineCardStyle(isActive: Bool = false) -> some View {
        self
            .background(Color.theme.surfaceLow)
            .cornerRadius(16)
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Color.theme.primary : Color.clear)
                        .frame(width: 2)
                    Spacer()
                }
            )
    }

    /// WashHub Hero CTA — Citrus 액센트 그라디언트, 강한 글로우
    /// 주요 화면에서 가장 돋보여야 할 단 하나의 액션 버튼에만 사용
    func ctaButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 132/255, green: 204/255, blue: 22/255),  // #84CC16 Citrus Bright
                        Color(red: 101/255, green: 163/255, blue: 13/255)   // #65A30D Olive
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.45), radius: 20, x: 0, y: 10)
            .shadow(color: Color(red: 132/255, green: 204/255, blue: 22/255).opacity(0.25), radius: 6, x: 0, y: 2)
    }

    /// WashHub 프라이머리 버튼 스타일 — Gradient CTA
    func primaryButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.onPrimaryContainer)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.theme.primary, Color.theme.primaryContainer],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.theme.primary.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    /// WashHub 세컨더리 버튼 스타일 — Ghost style
    func secondaryButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.outline.opacity(0.4), lineWidth: 1)
            )
    }

    /// WashHub Destructive 버튼 — 에러 컬러 아웃라인
    func destructiveButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.error.opacity(0.4), lineWidth: 2)
            )
    }

    /// WashHub 텍스트 필드 스타일 — No border, tonal bg
    func washHubTextField() -> some View {
        self
            .font(.appBody)
            .foregroundColor(.theme.textPrimary)
            .padding(16)
            .background(Color.theme.surfaceHighest)
            .cornerRadius(12)
    }

    /// Glassmorphism 스타일 — 네비게이션/모달용
    func glassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(16)
    }

    /// Ambient Glow Shadow — 요소가 떠 있는 느낌
    func ambientGlow(color: Color = Color.theme.primaryDim, radius: CGFloat = 24, opacity: Double = 0.1) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
