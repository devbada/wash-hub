import Foundation
import Combine
import Supabase

@MainActor
final class RoutineService: ObservableObject {
    @Published var routines: [Routine] = []
    @Published var isLoading = false

    private let routineSelect = "*, profiles!user_id(id, nickname, avatar_url, is_official), routine_steps(id, routine_id, step_order, title, description, duration, created_at)"
    private let pageSize = 20

    // MARK: - 루틴 목록 조회
    func loadRoutines(offset: Int = 0) async {
        isLoading = true
        do {
            try Task.checkCancellation()
            let persistRoutines: [Routine] = try await supabase
                .from("routines")
                .select(routineSelect)
                .eq("status", value: "ACTIVE")
                .order("fork_count", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            try Task.checkCancellation()
            if offset == 0 {
                routines = persistRoutines
            } else {
                routines.append(contentsOf: persistRoutines)
            }
        } catch is CancellationError {
            print("Routine load cancelled (normal)")
        } catch {
            print("Routine load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 루틴 상세 조회
    func loadRoutine(id: String) async -> Routine? {
        do {
            let persistRoutine: Routine = try await supabase
                .from("routines")
                .select(routineSelect)
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return persistRoutine
        } catch {
            print("Routine detail error: \(error)")
            return nil
        }
    }

    // MARK: - 루틴 생성 (+ steps + products 한번에)
    struct StepInput {
        let order: Int
        let title: String
        let description: String?
        let duration: Int?
    }

    func createRoutine(
        title: String,
        description: String?,
        duration: Int?,
        difficulty: Int?,
        steps: [StepInput],
        products: [String]
    ) async throws -> String {
        let session = try await supabase.auth.session
        let routineId = UUID().uuidString

        // 1. 루틴 생성
        var routineData: [String: String] = [
            "id": routineId,
            "user_id": session.user.id.uuidString,
            "title": title,
            "status": "ACTIVE"
        ]
        if let desc = description, !desc.isEmpty { routineData["description"] = desc }
        if let dur = duration { routineData["duration"] = "\(dur)" }
        if let diff = difficulty { routineData["difficulty"] = "\(diff)" }

        try await supabase.from("routines").insert(routineData).execute()

        // 2. 단계 생성
        for step in steps {
            var stepData: [String: String] = [
                "routine_id": routineId,
                "step_order": "\(step.order)",
                "title": step.title
            ]
            if let desc = step.description, !desc.isEmpty { stepData["description"] = desc }
            if let dur = step.duration { stepData["duration"] = "\(dur)" }

            try await supabase.from("routine_steps").insert(stepData).execute()
        }

        // 3. 사용 제품 등록
        for product in products where !product.isEmpty {
            try await supabase.from("routine_products").insert([
                "routine_id": routineId,
                "product_name": product
            ]).execute()
        }

        return routineId
    }

    // MARK: - 루틴 삭제
    func deleteRoutine(id: String) async throws {
        try await supabase
            .from("routines")
            .update(["status": "DELETED"])
            .eq("id", value: id)
            .execute()

        routines.removeAll { $0.id == id }
    }

    // MARK: - 내 루틴 조회
    func loadMyRoutines(userId: String) async -> [Routine] {
        do {
            let persistRoutines: [Routine] = try await supabase
                .from("routines")
                .select(routineSelect)
                .eq("user_id", value: userId)
                .neq("status", value: "DELETED")
                .order("created_at", ascending: false)
                .execute()
                .value
            return persistRoutines
        } catch {
            print("My routines error: \(error)")
            return []
        }
    }

    // MARK: - 사용 제품 조회
    func loadProducts(routineId: String) async -> [RoutineProduct] {
        do {
            let persistProducts: [RoutineProduct] = try await supabase
                .from("routine_products")
                .select()
                .eq("routine_id", value: routineId)
                .execute()
                .value
            return persistProducts
        } catch {
            print("Routine products error: \(error)")
            return []
        }
    }
}
