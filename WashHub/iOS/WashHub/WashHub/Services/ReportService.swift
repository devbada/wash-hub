import Foundation
import Combine
import Supabase

@MainActor
final class ReportService: ObservableObject {
    @Published var myReports: [Report] = []
    @Published var isLoading = false

    // MARK: - 신고 생성
    func createReport(
        targetType: ReportTargetType,
        targetId: String,
        reason: ReportReason,
        description: String?
    ) async throws {
        struct ReportInsert: Encodable {
            let reporter_id: String
            let target_type: String
            let target_id: String
            let reason: String
            let description: String?
        }

        guard let userId = supabase.auth.currentUser?.id.uuidString else {
            return
        }

        let insert = ReportInsert(
            reporter_id: userId,
            target_type: targetType.rawValue,
            target_id: targetId,
            reason: reason.rawValue,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await supabase
            .from("reports")
            .insert(insert)
            .execute()
    }

    // MARK: - 내 신고 목록 조회
    func loadMyReports() async {
        isLoading = true
        do {
            let persistReports: [Report] = try await supabase
                .from("reports")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            myReports = persistReports
        } catch {
            print("Load my reports error: \(error)")
        }
        isLoading = false
    }
}
