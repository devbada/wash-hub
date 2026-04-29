import Foundation
import Combine
import UIKit          // UIImage
import Photos         // PHPhotoLibrary — Before/After 사진을 사용자 앨범에 저장
import Supabase

@MainActor
final class RoutineExecutionService: ObservableObject {
    @Published var currentExecution: RoutineExecution?
    @Published var executionSteps: [RoutineExecutionStep] = []

    // MARK: - 따라하기 시작
    func startExecution(routineId: String, steps: [RoutineStep]) async throws -> String {
        let session = try await supabase.auth.session
        let executionId = UUID().uuidString

        // 1. 실행 레코드 생성
        try await supabase.from("routine_executions").insert([
            "id": executionId,
            "routine_id": routineId,
            "user_id": session.user.id.uuidString,
            "status": "IN_PROGRESS"
        ]).execute()

        // 2. 각 step에 대한 실행 step 생성
        struct StepInsert: Encodable {
            let execution_id: String
            let step_id: String
            let completed: Bool
        }
        for step in steps {
            let stepInsert = StepInsert(
                execution_id: executionId,
                step_id: step.id,
                completed: false
            )
            try await supabase.from("routine_execution_steps")
                .insert(stepInsert)
                .execute()
        }

        // 3. 현재 상태 로드
        await loadExecution(executionId: executionId)

        return executionId
    }

    // MARK: - 실행 상태 로드
    func loadExecution(executionId: String) async {
        do {
            let persistExecution: RoutineExecution = try await supabase
                .from("routine_executions")
                .select()
                .eq("id", value: executionId)
                .single()
                .execute()
                .value
            currentExecution = persistExecution

            let persistSteps: [RoutineExecutionStep] = try await supabase
                .from("routine_execution_steps")
                .select()
                .eq("execution_id", value: executionId)
                .execute()
                .value
            executionSteps = persistSteps
        } catch {
            print("Load execution error: \(error)")
        }
    }

    // MARK: - 진행 중인 실행 복원 (앱 재진입 시)
    func restoreInProgress(routineId: String) async -> String? {
        do {
            let session = try await supabase.auth.session
            let persistExecutions: [RoutineExecution] = try await supabase
                .from("routine_executions")
                .select()
                .eq("routine_id", value: routineId)
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "IN_PROGRESS")
                .order("started_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let execution = persistExecutions.first {
                await loadExecution(executionId: execution.id)
                return execution.id
            }
        } catch {
            print("Restore execution error: \(error)")
        }
        return nil
    }

    // MARK: - step 완료 토글
    func toggleStep(executionStepId: String) async {
        guard let index = executionSteps.firstIndex(where: { $0.id == executionStepId }) else { return }

        let newCompleted = !executionSteps[index].completed
        let nowString: String? = newCompleted ? ISO8601DateFormatter().string(from: Date()) : nil

        // Encodable payload — completed_at 을 explicit null 로 넘겨야 체크 해제 시 값 정리됨
        struct StepUpdate: Encodable {
            let completed: Bool
            let completed_at: String?
        }
        let payload = StepUpdate(completed: newCompleted, completed_at: nowString)

        do {
            try await supabase
                .from("routine_execution_steps")
                .update(payload)
                .eq("id", value: executionStepId)
                .execute()

            executionSteps[index] = RoutineExecutionStep(
                id: executionSteps[index].id,
                executionId: executionSteps[index].executionId,
                stepId: executionSteps[index].stepId,
                completed: newCompleted,
                completedAt: nowString
            )

            // 모든 step 완료 시 자동 완료 처리 (호출 측에서 elapsedSeconds 알 수 없으니
            // duration 미지정으로 호출 — 명시적 완료에서만 duration 기록)
            if executionSteps.allSatisfy({ $0.completed }) {
                await completeExecution(durationSeconds: nil)
            }
        } catch {
            print("Toggle step error: \(error)")
        }
    }

    // MARK: - 실행 완료
    /// - Parameter durationSeconds: 시작부터 완료까지 실제 소요 초. 자동 완료 시 nil 가능
    func completeExecution(durationSeconds: Int? = nil) async {
        guard let execution = currentExecution else { return }
        // 이미 완료 처리된 경우 중복 호출 방지 (DB trigger 가 카운트를 1번만 올리도록 보장하지만 클라이언트 호출도 막음)
        guard execution.status != "COMPLETED" else { return }

        do {
            let now = ISO8601DateFormatter().string(from: Date())
            // duration 이 있으면 함께 업데이트
            struct CompleteUpdate: Encodable {
                let status: String
                let completed_at: String
                let duration_seconds: Int?
            }
            let payload = CompleteUpdate(
                status: "COMPLETED",
                completed_at: now,
                duration_seconds: durationSeconds
            )
            try await supabase
                .from("routine_executions")
                .update(payload)
                .eq("id", value: execution.id)
                .execute()

            currentExecution = RoutineExecution(
                id: execution.id,
                routineId: execution.routineId,
                userId: execution.userId,
                status: "COMPLETED",
                startedAt: execution.startedAt,
                completedAt: now,
                durationSeconds: durationSeconds,
                feedId: execution.feedId
            )

            // List/Detail 화면 즉시 갱신 (DB trigger 가 usage_count 를 +1 했으므로 재조회 필요)
            NotificationCenter.default.post(
                name: .routineCompleted,
                object: nil,
                userInfo: ["routineId": execution.routineId]
            )
        } catch {
            print("Complete execution error: \(error)")
        }
    }

    // MARK: - 실행 포기
    func abandonExecution() async {
        guard let execution = currentExecution else { return }
        do {
            try await supabase
                .from("routine_executions")
                .update(["status": "ABANDONED"])
                .eq("id", value: execution.id)
                .execute()
            currentExecution = nil
            executionSteps = []
        } catch {
            print("Abandon execution error: \(error)")
        }
    }

    // MARK: - 사용자가 피드로 공유 후 호출 — 실행 → 피드 역링크
    /// 피드 작성이 성공적으로 완료된 후 호출. routine_executions.feed_id 업데이트
    func linkFeed(feedId: String) async {
        guard let execution = currentExecution else { return }
        do {
            try await supabase
                .from("routine_executions")
                .update(["feed_id": feedId])
                .eq("id", value: execution.id)
                .execute()
            currentExecution = RoutineExecution(
                id: execution.id,
                routineId: execution.routineId,
                userId: execution.userId,
                status: execution.status,
                startedAt: execution.startedAt,
                completedAt: execution.completedAt,
                durationSeconds: execution.durationSeconds,
                feedId: feedId
            )
        } catch {
            print("Link feed to execution error: \(error)")
        }
    }

    // MARK: - 사진을 사용자 Photos 앨범에 저장
    /// Before/After 캡처 시 호출. 앱은 reference 안 가짐 (사용자 자산)
    /// - Returns: 저장 성공 여부 (실패 시 권한 문제일 가능성)
    static func savePhotoToAlbum(_ image: UIImage) async -> Bool {
        // PhotoLibrary add 권한 요청 — Info.plist 의 NSPhotoLibraryAddUsageDescription 필요 (이미 있음)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            print("⚠️ Photos 권한 거부 — 사진 저장 불가")
            return false
        }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error = error {
                    print("⚠️ Photos 앨범 저장 실패: \(error)")
                }
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - 진행률
    var progress: Double {
        guard !executionSteps.isEmpty else { return 0 }
        let completed = executionSteps.filter { $0.completed }.count
        return Double(completed) / Double(executionSteps.count)
    }

    var isCompleted: Bool {
        currentExecution?.status == "COMPLETED"
    }
}
