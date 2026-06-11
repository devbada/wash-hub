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

    /// 리스트 화면 카드용 썸네일 JPEG 생성.
    /// - 사이즈: 400px (60x60~120x120 표시 영역 + Retina @3x 대응)
    /// - 용량: 최대 300KB (품질 0.85 ~ 0.7 범위 유지하여 화질 손상 최소화)
    /// - 풀이미지(1024px, ~2MB) 대비 트래픽 약 80% 절감 + 화질은 거의 동일.
    func thumbnailJpegData(maxDimension: CGFloat = 400) -> Data? {
        return jpegDataUnder(maxDimension: maxDimension, maxBytes: 300 * 1024)
    }

    /// EXIF orientation 정보를 픽셀에 베이크하여 `.up` orientation 의 새 UIImage 를 반환.
    ///
    /// 카메라로 찍은 세로 사진은 `imageOrientation = .right` 처럼 픽셀은 가로로 저장되고
    /// 표시할 때 회전되는 경우가 흔하다. 이 경우 `cgImage.width/height` 와 `image.size` 가 다르고,
    /// Vision/CoreImage 등 CGImage 픽셀 공간을 쓰는 API 와 SwiftUI 표시 공간이 어긋난다.
    /// 모자이크 편집처럼 좌표 변환이 정확해야 하는 시나리오에서는 진입 직후 이 메서드로
    /// 정규화하면 `cgImage` 크기 == `image.size` 가 되어 모든 좌표계가 일치한다.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 공통 View Modifier (Readable Neutral UI System)
extension View {

    /// 기본 카드 — 흰 배경과 여백으로 구분
    func cardStyle() -> some View {
        self
            .background(Color.theme.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Floating 요소에만 사용하는 낮은 단계의 상승 카드
    func elevatedCardStyle() -> some View {
        self
            .background(Color.theme.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.theme.textPrimary.opacity(0.06), radius: 24, x: 0, y: 8)
    }

    /// 선택된 항목에만 좌측 상태색을 표시하는 호환 카드
    func speedLineCardStyle(isActive: Bool = false) -> some View {
        self
            .background(Color.theme.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Color.theme.accent : Color.clear)
                        .frame(width: 3)
                    Spacer()
                }
            )
    }

    /// 화면에서 가장 중요한 단 하나의 액션
    func ctaButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 기본 Primary 버튼
    func primaryButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Secondary 버튼
    func secondaryButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.theme.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 파괴적 행동 버튼
    func destructiveButtonStyle() -> some View {
        self
            .font(.appBodyBold)
            .foregroundColor(.theme.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.theme.errorContainer)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 기본 입력 필드
    func washHubTextField() -> some View {
        self
            .font(.appBody)
            .foregroundColor(.theme.textPrimary)
            .padding(16)
            .background(Color.theme.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Glassmorphism 스타일 — 네비게이션/모달용
    func glassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(16)
    }

    /// Floating 요소에만 제한적으로 사용하는 Ambient Shadow
    func ambientGlow(color: Color = Color.theme.primaryDim, radius: CGFloat = 24, opacity: Double = 0.1) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
