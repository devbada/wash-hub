import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 모자이크 영역의 출처 — 자동 검출 종류 식별
enum SensitiveAreaKind {
    case face          // Vision 얼굴 자동 검출
    case licensePlate  // Vision Text 인식 + 한국 번호판 정규식
    case manual        // 사용자 드래그 추가

    var displayName: String {
        switch self {
        case .face:         return "얼굴"
        case .licensePlate: return "번호판"
        case .manual:       return "직접 추가"
        }
    }
}

/// 모자이크 영역 정보 — 자동 감지(얼굴/번호판) 또는 수동 드래그 영역
struct DetectedFace: Identifiable {
    let id = UUID()
    /// Vision 정규화 좌표 (좌하단 원점, 0~1) — 수동 영역도 동일 좌표계로 변환하여 저장
    let normalizedRect: CGRect
    /// UIKit 좌표계로 변환된 영역 (좌상단 원점, 이미지 크기 기준)
    let uiRect: CGRect
    /// 모자이크 적용 여부 (사용자가 토글)
    var isSelected: Bool = true
    /// 영역 종류 (face/licensePlate/manual)
    var kind: SensitiveAreaKind = .face

    /// 호환용 — 기존 isManual 사용처 보존
    var isManual: Bool { kind == .manual }
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
            return DetectedFace(normalizedRect: rect, uiRect: uiRect, kind: .face)
        }
    }

    /// 얼굴 + 번호판 + 그 외 민감 영역을 한 번에 검출 (편집 UI용)
    /// - Parameter image: 원본 UIImage
    /// - Returns: 얼굴/번호판 자동 검출 결과 통합 배열 — 사용자가 추가 수동 영역을 더할 수 있음
    func detectSensitiveAreasForEditor(in image: UIImage) async -> [DetectedFace] {
        guard let cgImage = image.cgImage else { return [] }

        // 얼굴/번호판 병렬 검출 — 둘 다 Vision 이라 GPU/Neural Engine 동시 사용 가능
        async let faceRectsTask = detectFaces(in: cgImage)
        async let plateRectsTask = detectLicensePlates(in: cgImage)
        let faceRects = await faceRectsTask
        let plateRects = await plateRectsTask

        let imgW = image.size.width
        let imgH = image.size.height

        var areas: [DetectedFace] = []

        // 얼굴
        for rect in faceRects {
            let uiRect = CGRect(
                x: rect.origin.x * imgW,
                y: (1.0 - rect.origin.y - rect.size.height) * imgH,
                width: rect.size.width * imgW,
                height: rect.size.height * imgH
            )
            areas.append(DetectedFace(normalizedRect: rect, uiRect: uiRect, kind: .face))
        }

        // 번호판 — 텍스트 bounding box 가 빡빡하므로 가로 5%, 세로 15% 여유
        // (한국 번호판은 가로 글자열만 인식되어 상하 padding 이 필요)
        for rect in plateRects {
            let inflated = CGRect(
                x: max(0, rect.origin.x - rect.width * 0.05),
                y: max(0, rect.origin.y - rect.height * 0.20),
                width: min(1 - rect.origin.x, rect.width * 1.10),
                height: min(1 - rect.origin.y, rect.height * 1.40)
            )
            let uiRect = CGRect(
                x: inflated.origin.x * imgW,
                y: (1.0 - inflated.origin.y - inflated.size.height) * imgH,
                width: inflated.size.width * imgW,
                height: inflated.size.height * imgH
            )
            areas.append(DetectedFace(normalizedRect: inflated, uiRect: uiRect, kind: .licensePlate))
        }

        return areas
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
            kind: .manual
        )
    }

    // MARK: - 얼굴 감지 (Vision)

    /// Vision 프레임워크로 얼굴 영역을 감지한다
    /// - Parameter cgImage: CGImage
    /// - Returns: 정규화된 얼굴 영역 배열 (Vision 좌표: 좌하단 원점, 0~1 범위)
    ///
    /// - Note: Vision 의 completionHandler 와 `handler.perform` 의 throw 가
    ///         동시에 발생하면 continuation 이 두 번 resume 되어 fatal error 가 발생할 수 있다.
    ///         (예: 시뮬레이터에서 "Could not create inference context" 에러 발생 시)
    ///         `ResumeGuard` 로 단 1회만 resume 되도록 보호한다.
    private func detectFaces(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            let guardBox = ResumeGuard<[CGRect]>(continuation: continuation)

            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFaceObservation] else {
                    guardBox.resume([])
                    return
                }
                let rects = results.map { $0.boundingBox }
                guardBox.resume(rects)
            }

            // 정확도 우선 (배터리보다 감지율 중시)
            request.revision = VNDetectFaceRectanglesRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Face detection error: \(error)")
                guardBox.resume([])
            }
        }
    }

    // MARK: - 번호판 감지 (Vision Text Recognition + 한국 번호판 정규식)

    /// 한국 차량 번호판 정규식
    /// - 신형 8자리: 숫자 3 + 한글 1 + 숫자 4 (예: 123가1234)
    /// - 구형 7자리: 숫자 2 + 한글 1 + 숫자 4 (예: 12가1234)
    /// - OCR 결과에 공백/하이픈이 들어갈 수 있으므로 사전 정규화 후 매칭
    private static let licensePlateRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "^\\d{2,3}[가-힣]\\d{4}$",
            options: []
        )
    }()

    /// Vision Text Recognition 으로 한국 번호판 텍스트를 찾고 그 bounding box 를 반환
    /// - Parameter cgImage: CGImage
    /// - Returns: Vision 정규화 좌표(좌하단 원점, 0~1) 의 번호판 영역 배열
    private func detectLicensePlates(in cgImage: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            let guardBox = ResumeGuard<[CGRect]>(continuation: continuation)

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    guardBox.resume([])
                    return
                }

                guard let regex = Self.licensePlateRegex else {
                    guardBox.resume([])
                    return
                }

                var rects: [CGRect] = []
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    // 공백/하이픈 제거 후 매칭 (OCR 가 공백을 끼울 수 있음)
                    let normalized = candidate.string
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "·", with: "")
                    let range = NSRange(normalized.startIndex..., in: normalized)
                    if regex.firstMatch(in: normalized, options: [], range: range) != nil {
                        rects.append(observation.boundingBox)
                    }
                }
                guardBox.resume(rects)
            }

            // 한국어 인식 + 정확도 우선 + 자동 교정 끔 (번호판 글자를 임의로 바꾸지 않도록)
            request.recognitionLanguages = ["ko"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            // 번호판은 사전에 없는 글자 조합이라 customWords 도 불필요

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("License plate detection error: \(error)")
                guardBox.resume([])
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

// MARK: - Continuation 단일 resume 보호용 헬퍼

/// `withCheckedContinuation` 사용 시 두 경로(예: completionHandler / catch 블록)에서
/// resume 이 동시에 일어날 가능성이 있을 때 단 1회만 resume 되도록 보장한다.
///
/// Vision 의 `VNRequest.completionHandler` 와 `VNImageRequestHandler.perform` 의 throw 가
/// 함께 발생하는 경우(시뮬레이터의 "Could not create inference context" 등)
/// SWIFT TASK CONTINUATION MISUSE fatal error 가 발생하므로 이를 방지한다.
private final class ResumeGuard<T> {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, Never>

    init(continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let shouldResume = !didResume
        if shouldResume { didResume = true }
        lock.unlock()
        if shouldResume {
            continuation.resume(returning: value)
        }
    }
}
