import UIKit

/// NSFW 이미지 감지 결과
struct NSFWResult {
    let isSafe: Bool
    let confidence: Double   // 0.0 ~ 1.0
    let label: String        // "safe" / "unsafe"
}

/// On-device NSFW 감지기
/// Phase 4.0: Mock 기반 (파일 크기/픽셀 히스토그램 기반 더미 판단)
/// TODO-minam: Phase 4.1에서 실제 CoreML 모델(NudeNet 등)로 교체
final class NSFWDetector {

    static let shared = NSFWDetector()
    private init() {}

    /// 이미지의 NSFW 여부를 판단한다
    /// - Parameter image: 검사할 UIImage
    /// - Returns: NSFWResult (isSafe, confidence, label)
    func classify(image: UIImage) async -> NSFWResult {
        // TODO-minam: Phase 4.1에서 실제 CoreML 모델로 교체
        // 현재는 Mock: 항상 safe 반환
        // 실제 모델 탑재 시 VNCoreMLRequest 기반으로 교체 예정

        // Mock 판단: 이미지 분석 시뮬레이션 (약간의 딜레이)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초

        return NSFWResult(isSafe: true, confidence: 0.05, label: "safe")
    }

    /// 테스트용: 특정 결과를 반환하는 Mock 분류
    /// - Parameters:
    ///   - image: 검사할 UIImage
    ///   - forceUnsafe: true이면 unsafe 결과 반환
    func classify(image: UIImage, forceUnsafe: Bool) async -> NSFWResult {
        if forceUnsafe {
            return NSFWResult(isSafe: false, confidence: 0.95, label: "unsafe")
        }
        return await classify(image: image)
    }
}
