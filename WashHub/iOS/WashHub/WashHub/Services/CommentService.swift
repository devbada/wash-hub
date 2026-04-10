import Foundation
import Combine
import Supabase

@MainActor
final class CommentService: ObservableObject {
    @Published var comments: [Comment] = []

    // MARK: - 댓글 목록 조회
    func loadComments(feedId: String) async {
        do {
            let persistComments: [Comment] = try await supabase
                .from("comments")
                .select("*, profiles!user_id(id, nickname, avatar_url)")
                .eq("feed_id", value: feedId)
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: true)
                .execute()
                .value

            comments = persistComments
        } catch {
            print("Comments load error: \(error)")
        }
    }

    // MARK: - 댓글 작성
    func addComment(feedId: String, content: String, parentCommentId: String? = nil) async throws {
        let session = try await supabase.auth.session

        var insertData: [String: String] = [
            "feed_id": feedId,
            "user_id": session.user.id.uuidString,
            "content": content,
            "status": "ACTIVE"
        ]

        if let parentId = parentCommentId {
            insertData["parent_comment_id"] = parentId
        }

        try await supabase
            .from("comments")
            .insert(insertData)
            .execute()

        await loadComments(feedId: feedId)
    }

    // MARK: - 댓글 수정 (5분 이내만 가능)
    func updateComment(commentId: String, feedId: String, content: String) async throws {
        try await supabase
            .from("comments")
            .update(["content": content])
            .eq("id", value: commentId)
            .execute()

        await loadComments(feedId: feedId)
    }

    // MARK: - 댓글 삭제 (소프트 삭제)
    func deleteComment(commentId: String, feedId: String) async throws {
        try await supabase
            .from("comments")
            .update(["status": "DELETED"])
            .eq("id", value: commentId)
            .execute()

        await loadComments(feedId: feedId)
    }

    // MARK: - 수정 가능 여부 (5분 이내)
    func canEdit(comment: Comment) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let createdDate = formatter.date(from: comment.createdAt) else {
            // fallback: fractionalSeconds 없는 포맷
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            guard let date = fallback.date(from: comment.createdAt) else { return false }
            return Date().timeIntervalSince(date) < 300 // 5분 = 300초
        }
        return Date().timeIntervalSince(createdDate) < 300
    }
}
