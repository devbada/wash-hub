import Foundation
import Combine
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

            // 모든 step 완료 시 자동 완료 처리
            if executionSteps.allSatisfy({ $0.completed }) {
                await completeExecution()
            }
        } catch {
            print("Toggle step error: \(error)")
        }
    }

    // MARK: - 실행 완료
    func completeExecution() async {
        guard let execution = currentExecution else { return }
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            try await supabase
                .from("routine_executions")
                .update(["status": "COMPLETED", "completed_at": now])
                .eq("id", value: execution.id)
                .execute()

            currentExecution = RoutineExecution(
                id: execution.id,
                routineId: execution.routineId,
                userId: execution.userId,
                status: "COMPLETED",
                startedAt: execution.startedAt,
                completedAt: now
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
