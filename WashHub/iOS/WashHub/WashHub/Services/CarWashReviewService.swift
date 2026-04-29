import Foundation
import Combine
import Supabase

@MainActor
final class CarWashReviewService: ObservableObject {
    @Published var reviews: [CarWashReview] = []
    @Published var isLoading = false
    @Published var myExistingReview: CarWashReview?

    // MARK: - 리뷰 목록 조회
    func loadReviews(carWashId: String) async {
        isLoading = true
        do {
            let persistReviews: [CarWashReview] = try await supabase
                .from("car_wash_reviews")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official)")
                .eq("car_wash_id", value: carWashId)
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value

            reviews = persistReviews
        } catch {
            print("Car wash reviews load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 내 리뷰 존재 여부 확인
    func checkMyReview(carWashId: String) async {
        do {
            let session = try await supabase.auth.session
            let persistMyReviews: [CarWashReview] = try await supabase
                .from("car_wash_reviews")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official)")
                .eq("car_wash_id", value: carWashId)
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
    func addReview(carWashId: String, rating: Int, reviewText: String?) async throws {
        let session = try await supabase.auth.session

        var insertData: [String: String] = [
            "car_wash_id": carWashId,
            "user_id": session.user.id.uuidString,
            "rating": "\(rating)",
            "status": "ACTIVE"
        ]

        if let text = reviewText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insertData["review_text"] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        try await supabase
            .from("car_wash_reviews")
            .insert(insertData)
            .execute()

        await loadReviews(carWashId: carWashId)
        await checkMyReview(carWashId: carWashId)
    }

    // MARK: - 리뷰 수정
    func updateReview(reviewId: String, carWashId: String, rating: Int, reviewText: String?) async throws {
        struct ReviewUpdate: Encodable {
            let rating: Int
            let review_text: String?
        }

        let trimmedText = reviewText?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await supabase
            .from("car_wash_reviews")
            .update(ReviewUpdate(rating: rating, review_text: trimmedText))
            .eq("id", value: reviewId)
            .execute()

        await loadReviews(carWashId: carWashId)
        await checkMyReview(carWashId: carWashId)
    }

    // MARK: - 리뷰 삭제 (소프트 삭제)
    func deleteReview(reviewId: String, carWashId: String) async throws {
        try await supabase
            .from("car_wash_reviews")
            .update(["status": "DELETED"])
            .eq("id", value: reviewId)
            .execute()

        await loadReviews(carWashId: carWashId)
        myExistingReview = nil
    }
}
