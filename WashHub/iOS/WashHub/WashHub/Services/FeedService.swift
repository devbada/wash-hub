import Foundation
import Combine
import Supabase

@MainActor
final class FeedService: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var isLoading = false

    private let pageSize = 10

    private let feedSelect = "*, profiles!user_id(id, nickname, avatar_url), my_cars(id, car_model, car_color, car_year)"

    // MARK: - 피드 목록 조회
    func loadFeeds(offset: Int = 0, forceRefresh: Bool = false) async {
        isLoading = true
        do {
            // forceRefresh가 아닌 경우에만 취소 체크 (새로고침은 취소되지 않도록)
            if !forceRefresh {
                try Task.checkCancellation()
            }
            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select(feedSelect)
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            if !forceRefresh {
                try Task.checkCancellation()
            }
            if offset == 0 {
                feeds = persistFeeds
            } else {
                feeds.append(contentsOf: persistFeeds)
            }
        } catch is CancellationError {
            // Task 취소는 정상 동작 (뷰 전환 등) — 무시
            print("Feed load cancelled (normal)")
        } catch {
            print("Feed load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 단일 피드 부분 갱신 (목록의 카운터만 동기화)
    func refreshFeed(id: String) async {
        guard let persistFeed = await loadFeed(id: id) else { return }
        if let index = feeds.firstIndex(where: { $0.id == id }) {
            feeds[index] = persistFeed
        }
    }

    // MARK: - 피드 상세 조회
    func loadFeed(id: String) async -> Feed? {
        do {
            let persistFeed: Feed = try await supabase
                .from("feeds")
                .select(feedSelect)
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return persistFeed
        } catch {
            print("Feed detail load error: \(error)")
            return nil
        }
    }

    // MARK: - 피드 작성
    func createFeed(
        title: String?,
        content: String?,
        location: String?,
        washMethod: String?,
        carId: String?,
        beforeImages: [Data],
        afterImages: [Data],
        extraImages: [Data] = [],
        isSponsored: Bool = false,
        sponsorName: String? = nil
    ) async throws -> String {
        let session = try await supabase.auth.session
        let feedId = UUID().uuidString

        // 1. 피드 레코드 생성
        var feedData: [String: String] = [
            "id": feedId,
            "user_id": session.user.id.uuidString,
            "title": title ?? "",
            "content": content ?? "",
            "location": location ?? "",
            "wash_method": washMethod ?? "",
            "status": "ACTIVE",
            "is_sponsored": isSponsored ? "true" : "false"
        ]
        if let carId = carId {
            feedData["car_id"] = carId
        }
        if let sponsorName = sponsorName {
            feedData["sponsor_name"] = sponsorName
        }

        try await supabase
            .from("feeds")
            .insert(feedData)
            .execute()

        // 2. Before 이미지 업로드 및 레코드 생성
        // 썸네일 우선순위: AFTER 첫 이미지 > BEFORE 첫 이미지 > EXTRA 첫 이미지
        var thumbnailUrl: String?
        var beforeFirstUrl: String?
        for (index, imageData) in beforeImages.enumerated() {
            let path = "\(feedId)/before/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            if index == 0 {
                beforeFirstUrl = publicUrl.absoluteString
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "BEFORE",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)"
                ])
                .execute()
        }

        // 3. After 이미지 업로드 및 레코드 생성
        for (index, imageData) in afterImages.enumerated() {
            let path = "\(feedId)/after/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            // After 첫 이미지가 있다면 썸네일로 우선 채택
            if index == 0 {
                thumbnailUrl = publicUrl.absoluteString
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "AFTER",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)"
                ])
                .execute()
        }

        // After 이미지가 없으면 Before 첫 이미지로 fallback
        if thumbnailUrl == nil {
            thumbnailUrl = beforeFirstUrl
        }

        // 4. Extra 이미지 업로드 및 레코드 생성
        for (index, imageData) in extraImages.enumerated() {
            let path = "\(feedId)/extra/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            // Before/After 모두 없으면 Extra 첫 이미지로 fallback
            if thumbnailUrl == nil && index == 0 {
                thumbnailUrl = publicUrl.absoluteString
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "EXTRA",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)"
                ])
                .execute()
        }

        // 5. 썸네일 URL 업데이트
        // feed_images 트리거(`feed_images_refresh_thumbnail`) 가 자동으로 채우지만
        // 즉시성을 위해 클라이언트에서도 한 번 더 갱신 시도.
        // 실패해도 트리거가 이미 채워놓았을 것이므로 throw 하지 않고 로그만 남김.
        // TODO-minam: RLS 정책으로 feeds.update 가 반복 실패하면 로그 분석 필요
        if let thumbnailUrl = thumbnailUrl {
            do {
                try await supabase
                    .from("feeds")
                    .update(["thumbnail_url": thumbnailUrl])
                    .eq("id", value: feedId)
                    .execute()
            } catch {
                print("⚠️ thumbnail_url 직접 업데이트 실패 (DB 트리거가 fallback 처리): \(error)")
            }
        }

        // 6. 차량이 선택된 경우 wash_logs 에 세차기록 자동 생성
        if let carId = carId {
            do {
                let today = ISO8601DateFormatter.string(
                    from: Date(),
                    timeZone: TimeZone(identifier: "Asia/Seoul") ?? .current,
                    formatOptions: [.withFullDate, .withDashSeparatorInDate]
                )
                try await supabase
                    .from("wash_logs")
                    .insert([
                        "user_id": session.user.id.uuidString,
                        "car_id": carId,
                        "feed_id": feedId,
                        "wash_date": today,
                        "memo": title ?? "피드에서 자동 생성",
                        "status": "ACTIVE"
                    ])
                    .execute()
            } catch {
                // TODO-minam: wash_log 자동 생성 실패 시 로그 분석 필요
                print("⚠️ wash_log 자동 생성 실패 (피드 자체는 정상): \(error)")
            }
        }

        return feedId
    }

    // MARK: - 피드 수정
    func updateFeed(
        id: String,
        title: String?,
        content: String?,
        location: String?,
        washMethod: String?
    ) async throws {
        struct FeedUpdate: Encodable {
            let title: String
            let content: String
            let location: String
            let wash_method: String
            let is_edited: Bool
        }
        let payload = FeedUpdate(
            title: title ?? "",
            content: content ?? "",
            location: location ?? "",
            wash_method: washMethod ?? "",
            is_edited: true
        )

        try await supabase
            .from("feeds")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - 피드 삭제 (소프트 삭제)
    func deleteFeed(id: String) async throws {
        try await supabase
            .from("feeds")
            .update(["status": "DELETED"])
            .eq("id", value: id)
            .execute()

        // 연결된 wash_log 도 소프트 삭제
        do {
            try await supabase
                .from("wash_logs")
                .update(["status": "DELETED"])
                .eq("feed_id", value: id)
                .execute()
        } catch {
            // TODO-minam: 피드 삭제는 성공했으나 wash_log 삭제 실패 시 로그 분석
            print("⚠️ wash_log 연동 삭제 실패: \(error)")
        }

        feeds.removeAll { $0.id == id }
    }

    // MARK: - 좋아요 토글
    func toggleLike(feedId: String) async throws -> Bool {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        let persistLikes: [FeedLike] = try await supabase
            .from("feed_likes")
            .select()
            .eq("feed_id", value: feedId)
            .eq("user_id", value: userId)
            .execute()
            .value

        if persistLikes.isEmpty {
            // 좋아요 추가
            try await supabase
                .from("feed_likes")
                .insert(["feed_id": feedId, "user_id": userId])
                .execute()
            return true
        } else {
            // 좋아요 취소
            try await supabase
                .from("feed_likes")
                .delete()
                .eq("feed_id", value: feedId)
                .eq("user_id", value: userId)
                .execute()
            return false
        }
    }

    // MARK: - 좋아요 여부 확인
    func isLiked(feedId: String) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let persistLikes: [FeedLike] = try await supabase
                .from("feed_likes")
                .select()
                .eq("feed_id", value: feedId)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            return !persistLikes.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - 피드 이미지 조회
    func loadFeedImages(feedId: String) async -> [FeedImage] {
        do {
            let persistImages: [FeedImage] = try await supabase
                .from("feed_images")
                .select()
                .eq("feed_id", value: feedId)
                .order("display_order")
                .execute()
                .value
            return persistImages
        } catch {
            print("Feed images load error: \(error)")
            return []
        }
    }

    // MARK: - 내 피드 조회
    func loadMyFeeds(userId: String) async -> [Feed] {
        do {
            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select(feedSelect)
                .eq("user_id", value: userId)
                .neq("status", value: "DELETED")
                .order("created_at", ascending: false)
                .execute()
                .value
            return persistFeeds
        } catch {
            print("My feeds load error: \(error)")
            return []
        }
    }
}
