import Foundation
import SwiftUI
import Combine

/// 코치마크 진행 상태를 보관하는 전역 컨트롤러
///
/// - UserDefaults 의 버전 키를 보고 첫 사용자에게만 자동 시작
/// - 마이페이지 → "도움말 다시 보기" 진입 시 강제 시작
/// - 각 탭/FAB 의 `.coachmarkAnchor(id:)` 모디파이어가 등록한 좌표를 보관
@MainActor
final class CoachmarkController: ObservableObject {
    static let shared = CoachmarkController()

    @Published private(set) var isActive = false
    @Published private(set) var currentIndex = 0
    @Published private(set) var steps: [CoachmarkStep] = []

    /// `.coachmarkAnchor(id:)` 으로 등록된 글로벌 frame 들
    @Published private(set) var anchors: [String: CGRect] = [:]

    private init() {}

    // MARK: - 시작 / 종료

    /// 버전 키별 1회 자동 시작 — UserDefaults 에 노출 기록이 있으면 무시
    /// - Parameters:
    ///   - version: `CoachmarkVersion.homeV1` 등의 키
    ///   - steps: 노출할 단계 배열
    func startIfNeeded(version: String, steps: [CoachmarkStep]) {
        guard !isActive else { return }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: version) {
            return
        }
        // 처음 노출 — 시작
        beginInternal(steps: steps, version: version)
    }

    /// 사용자가 명시적으로 다시 보기 — 노출 기록 무시하고 강제 시작
    func forceStart(steps: [CoachmarkStep]) {
        beginInternal(steps: steps, version: nil)
    }

    /// 다음 단계로 진행 — 마지막이면 종료 + shown 저장
    func next() {
        guard isActive else { return }
        if currentIndex + 1 >= steps.count {
            finish(savingShown: true)
        } else {
            currentIndex += 1
        }
    }

    /// 사용자가 건너뛰기를 누름 — 시작 시 저장한 version 키에 shown=true 기록
    func skip() {
        finish(savingShown: true)
    }

    /// 외부에서 강제 종료 (예: 백그라운드/로그아웃) — shown 저장 여부 선택 가능
    func dismiss(markAsShown: Bool) {
        finish(savingShown: markAsShown)
    }

    // MARK: - Anchor 등록

    /// `.coachmarkAnchor(id:)` 모디파이어가 좌표를 등록할 때 호출
    func registerAnchor(_ id: String, frame: CGRect) {
        // 동일한 frame 이면 publish 하지 않음 — 무한 갱신 방지
        if let existing = anchors[id], existing == frame { return }
        anchors[id] = frame
    }

    // MARK: - 파생 상태

    var currentStep: CoachmarkStep? {
        guard isActive, currentIndex < steps.count else { return nil }
        return steps[currentIndex]
    }

    /// 현재 단계가 강조하는 영역 — anchor 가 없으면 nil (전체 dim 만)
    var spotlightRect: CGRect? {
        guard let step = currentStep, let anchorId = step.anchorId else { return nil }
        return anchors[anchorId]
    }

    /// 진행률 — 0...1
    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(steps.count)
    }

    // MARK: - 내부

    /// 시작 시 사용한 version 키 — finish() 시 shown 기록에 사용
    private var activeVersion: String?

    private func beginInternal(steps: [CoachmarkStep], version: String?) {
        self.steps = steps
        self.currentIndex = 0
        self.activeVersion = version
        // anchor 좌표가 등록되기 전에 시작하면 spotlight 가 비어 있음
        // → 호출부에서 약간의 delay 후 시작하도록 가이드 (P3-011 문서 참조)
        withAnimation(.easeInOut(duration: 0.25)) {
            self.isActive = true
        }
    }

    private func finish(savingShown: Bool) {
        if savingShown, let version = activeVersion {
            UserDefaults.standard.set(true, forKey: version)
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            self.isActive = false
        }
        self.currentIndex = 0
        self.steps = []
        self.activeVersion = nil
    }
}
