import Foundation
import Combine
import Supabase

@MainActor
final class EquipmentReviewService: ObservableObject {
    @Published var reviews: [EquipmentReview] = []
    @Published var isLoading = false
    @Published var myExistingReview: EquipmentReview?

    // MARK: - 리뷰 목록 조회
    func loadReviews(equipmentId: String) async {
        isLoading = true
        do {
            let persistReviews: [EquipmentReview] = try await supabase
                .from("equipment_reviews")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official, deleted_at)")
                .eq("equipment_id", value: equipmentId)
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value

            reviews = persistReviews
        } catch {
            print("Equipment reviews load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 내 리뷰 존재 여부 확인
    func checkMyReview(equipmentId: String) async {
        do {
            let session = try await supabase.auth.session
            let persistMyReviews: [EquipmentReview] = try await supabase
                .from("equipment_reviews")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official, deleted_at)")
                .eq("equipment_id", value: equipmentId)
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "ACTIVE")
                .limit(1)
                .execute()
                .value

            myExistingReview = persistMyReviews.first
        } catch {
            myExistingReview = nil
        }
    }

    // MARK: - 리뷰 작성
    func addReview(equipmentId: String, rating: Int, reviewText: String?) async throws {
        let session = try await supabase.auth.session

        var insertData: [String: String] = [
            "equipment_id": equipmentId,
            "user_id": session.user.id.uuidString,
            "rating": "\(rating)",
            "status": "ACTIVE"
        ]

        if let text = reviewText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insertData["review_text"] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        try await supabase
            .from("equipment_reviews")
            .insert(insertData)
            .execute()

        await loadReviews(equipmentId: equipmentId)
        await checkMyReview(equipmentId: equipmentId)
    }

    // MARK: - 리뷰 수정
    func updateReview(reviewId: String, equipmentId: String, rating: Int, reviewText: String?) async throws {
        struct ReviewUpdate: Encodable {
            let rating: Int
            let review_text: String?
        }

        let trimmedText = reviewText?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await supabase
            .from("equipment_reviews")
            .update(ReviewUpdate(rating: rating, review_text: trimmedText))
            .eq("id", value: reviewId)
            .execute()

        await loadReviews(equipmentId: equipmentId)
        await checkMyReview(equipmentId: equipmentId)
    }

    // MARK: - 리뷰 삭제 (소프트 삭제)
    func deleteReview(reviewId: String, equipmentId: String) async throws {
        try await supabase
            .from("equipment_reviews")
            .update(["status": "DELETED"])
            .eq("id", value: reviewId)
            .execute()

        await loadReviews(equipmentId: equipmentId)
        myExistingReview = nil
    }
}
