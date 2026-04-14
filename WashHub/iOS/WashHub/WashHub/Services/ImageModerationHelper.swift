import UIKit

/// 이미지 모더레이션 처리 결과
enum ModerationAction {
    case allowed(UIImage)          // 정상 통과 (모자이크 적용 후 이미지 포함)
    case blocked                   // NSFW 차단
}

/// 이미지 업로드 전 모더레이션 파이프라인 통합 유틸
/// 1. NSFW 감지 → 차단
/// 2. 얼굴 감지 → 자동 모자이크
final class ImageModerationHelper {

    static let shared = ImageModerationHelper()
    private let nsfwDetector = NSFWDetector.shared
    private let faceMosaic = FaceMosaicService.shared
    private init() {}

    /// 이미지를 모더레이션 파이프라인에 통과시킨다
    /// - Parameters:
    ///   - image: 원본 UIImage
    ///   - skipFaceMosaic: true이면 얼굴 모자이크를 건너뛴다 (프로필 사진 등)
    /// - Returns: ModerationAction (allowed 또는 blocked)
    func process(image: UIImage, skipFaceMosaic: Bool = false) async -> ModerationAction {
        // Step 1: NSFW 감지
        let nsfwResult = await nsfwDetector.classify(image: image)
        guard nsfwResult.isSafe else {
            return .blocked
        }

        // Step 2: 얼굴 감지 + 자동 모자이크 (프로필 사진은 스킵)
        if !skipFaceMosaic {
            let (processedImage, faceCount) = await faceMosaic.mosaicFaces(in: image)
            if faceCount > 0 {
                print("Face mosaic: \(faceCount) faces detected")
            }
            return .allowed(processedImage)
        }

        return .allowed(image)
    }

    /// 여러 이미지를 일괄 처리한다
    /// - Parameter images: 원본 UIImage 배열
    /// - Returns: (처리된 이미지 배열, 차단된 이미지 수)
    func processBatch(images: [UIImage]) async -> (processed: [UIImage], blockedCount: Int) {
        var processed: [UIImage] = []
        var blockedCount = 0

        for image in images {
            let result = await process(image: image)
            switch result {
            case .allowed(let img):
                processed.append(img)
            case .blocked:
                blockedCount += 1
            }
        }

        return (processed, blockedCount)
    }
}
