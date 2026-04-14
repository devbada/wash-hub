import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 모자이크 영역 정보 — 자동 감지 얼굴 또는 수동 드래그 영역
struct DetectedFace: Identifiable {
    let id = UUID()
    /// Vision 정규화 좌표 (좌하단 원점, 0~1) — 수동 영역도 동일 좌표계로 변환하여 저장
    let normalizedRect: CGRect
    /// UIKit 좌표계로 변환된 영역 (좌상단 원점, 이미지 크기 기준)
    let uiRect: CGRect
    /// 모자이크 적용 여부 (사용자가 토글)
    var isSelected: Bool = true
    /// 수동 드래그로 추가된 영역인지 여부
    var isManual: Bool = false
}

/// 얼굴 자동 모자이크 서비스
/// Vision 프레임워크로 얼굴 감지 → Core Image pixellate 필터로 모자이크 처리
final class FaceMosaicService {

    static let shared = FaceMosaicService()
    private let ciContext = CIContext()
    private init() {}

    /// 이미지에서 얼굴을 감지하고 모자이크 처리한 이미지를 반환한다
    /// - Parameter image: 원본 UIImage
    /// - Returns: (모자이크 적용 UIImage, 감지된 얼굴 수)
    func mosaicFaces(in image: UIImage) async -> (UIImage, Int) {
        guard let cgImage = image.cgImage else { return (image, 0) }

        let faceRects = await detectFaces(in: cgImage)
        guard !faceRects.isEmpty else { return (image, 0) }

        let mosaicImage = applyMosaic(to: image, faceRects: faceRects)
        return (mosaicImage, faceRects.count)
    }

    /// 이미지에서 얼굴 영역을 감지하여 DetectedFace 배열을 반환한다 (편집 UI용)
    /// - Parameter image: 원본 UIImage
    /// - Returns: 감지된 얼굴 배열 (UIKit 좌표 포함)
    func detectFacesForEditor(in image: UIImage) async -> [DetectedFace] {
        guard let cgImage = image.cgImage else { return [] }
        let normalizedRects = await detectFaces(in: cgImage)

        let imgW = image.size.width
        let imgH = image.size.height

        return normalizedRects.map { rect in
            // Vision(좌하단 원점, 0~1) → UIKit(좌상단 원점, 픽셀)
            let uiRect = CGRect(
                x: rect.origin.x * imgW,
                y: (1.0 - rect.origin.y - rect.size.height) * imgH,
                width: rect.size.width * imgW,
                height: rect.size.height * imgH
            )
            return DetectedFace(normalizedRect: rect, uiRect: uiRect)
        }
    }

    /// 선택된 얼굴만 모자이크 처리한 이미지를 반환한다
    /// - Parameters:
    ///   - image: 원본 UIImage
    ///   - faces: DetectedFace 배열 (isSelected == true인 얼굴만 모자이크)
    /// - Returns: 모자이크 적용된 UIImage
    func mosaicSelectedFaces(in image: UIImage, faces: [DetectedFace]) -> UIImage {
        let selectedRects = faces.filter { $0.isSelected }.map { $0.normalizedRect }
        guard !selectedRects.isEmpty else { return image }
        return applyMosaic(to: image, faceRects: selectedRects)
    }

    /// 얼굴이 포함되어 있는지만 확인한다 (모자이크 없이)
    /// - Parameter image: 검사할 UIImage
    /// - Returns: 감지된 얼굴 수
    func detectFaceCount(in image: UIImage) async -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let faceRects = await detectFaces(in: cgImage)
        return faceRects.count
    }

    /// 수동 드래그 영역으로 DetectedFace를 생성한다
    /// - Parameters:
    ///   - uiRect: UIKit 좌표 기준 영역 (이미지 크기 기준)
    ///   - imageSize: 원본 이미지 크기
    /// - Returns: DetectedFace (isManual = true)
    func createManualRegion(uiRect: CGRect, imageSize: CGSize) -> DetectedFace {
        // UIKit(좌상단 원점) → Vision 정규화(좌하단 원점, 0~1)
        let normalizedRect = CGRect(
            x: uiRect.origin.x / imageSize.width,
            y: 1.0 - (uiRect.origin.y + uiRect.size.height) / imageSize.height,
            width: uiRect.size.width / imageSize.width,
            height: uiRect.size.height / imageSize.height
        )
        return DetectedFace(
            normalizedRect: normalizedRect,
            uiRect: uiRect,
            isSelected: true,
            isManual: true
        )
    }

    // MARK: - 얼굴 감지 (Vision)

    /// Vision 프레임워크로 얼굴 영역을 감지한다
    /// - Parameter cgImage: CGImage
    /// - Returns: 정규화된 얼굴 영역 배열 (Vision 좌표: 좌하단 원점, 0~1 범위)
    private func detectFaces(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let rects = results.map { $0.boundingBox }
                continuation.resume(returning: rects)
            }

            // 정확도 우선 (배터리보다 감지율 중시)
            request.revision = VNDetectFaceRectanglesRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Face detection error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - 모자이크 적용 (Core Image)

    /// 감지된 얼굴 영역에 pixellate 모자이크를 적용한다
    /// - Parameters:
    ///   - image: 원본 UIImage
    ///   - faceRects: Vision 좌표 기반 얼굴 영역 배열
    /// - Returns: 모자이크 적용된 UIImage
    private func applyMosaic(to image: UIImage, faceRects: [CGRect]) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let imageSize = ciImage.extent.size
        // 모자이크 블록 크기: 이미지 크기 대비 적정 비율
        let pixelScale = max(imageSize.width, imageSize.height) / 40.0

        // 1) 전체 이미지에 pixellate 적용
        guard let pixellated = CIFilter(name: "CIPixellate", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputScaleKey: pixelScale
        ])?.outputImage else { return image }

        // 2) 얼굴 영역별 마스크 생성 후 합성
        var compositedImage = ciImage

        for rect in faceRects {
            // Vision 좌표(좌하단 원점, 0~1) → Core Image 좌표(좌하단 원점, 픽셀) 변환
            let faceX = rect.origin.x * imageSize.width
            let faceY = rect.origin.y * imageSize.height
            let faceW = rect.size.width * imageSize.width
            let faceH = rect.size.height * imageSize.height

            // 얼굴 주위 여유 영역 (20% 확장 — 헤어라인, 턱 포함)
            let padding = max(faceW, faceH) * 0.2
            let expandedRect = CGRect(
                x: faceX - padding,
                y: faceY - padding,
                width: faceW + padding * 2,
                height: faceH + padding * 2
            )

            // 타원형 마스크 (얼굴 형태에 자연스럽게 맞춤)
            let maskCenter = CIVector(
                x: expandedRect.midX,
                y: expandedRect.midY
            )
            let maskRadius0 = min(expandedRect.width, expandedRect.height) / 2.0 * 0.85
            let maskRadius1 = max(expandedRect.width, expandedRect.height) / 2.0

            guard let radialMask = CIFilter(name: "CIRadialGradient", parameters: [
                kCIInputCenterKey: maskCenter,
                "inputRadius0": maskRadius0,
                "inputRadius1": maskRadius1,
                "inputColor0": CIColor.white,
                "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            ])?.outputImage else { continue }

            // 마스크 영역만 pixellated 이미지로 합성
            guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: pixellated,
                kCIInputBackgroundImageKey: compositedImage,
                kCIInputMaskImageKey: radialMask
            ])?.outputImage else { continue }

            compositedImage = blended
        }

        // CIImage → UIImage 변환
        guard let outputCGImage = ciContext.createCGImage(
            compositedImage,
            from: ciImage.extent
        ) else { return image }

        return UIImage(
            cgImage: outputCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}
