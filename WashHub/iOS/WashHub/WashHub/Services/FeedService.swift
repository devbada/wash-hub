import Foundation
import Combine
import UIKit  // UIImage — 썸네일 생성 시 사용
import Supabase

@MainActor
final class FeedService: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var isLoading = false
    @Published var hasMorePages = true

    private let pageSize = 10

    private let feedSelect = "*, profiles!user_id(id, nickname, avatar_url), my_cars(id, car_model, car_color, car_year, nickname)"

    // MARK: - 캐시 (첫 페이지만 60초 — pagination 결과는 캐싱 안 함)
    // @StateObject 가 매 뷰마다 인스턴스를 만들기 때문에 static 으로 인스턴스 간 공유한다
    private static let firstPageCacheTTL: TimeInterval = 60
    private static let firstPageCache = TimedCache<String, [Feed]>(ttl: firstPageCacheTTL)
    private static let firstPageCacheKey = "feeds.firstPage"

    /// 피드 mutation(작성/삭제/수정 등) 시 호출 — 다음 fetch 때 신선한 데이터로 갱신
    static func invalidateFeedListCache() {
        firstPageCache.invalidateAll()
    }

    // MARK: - 피드 목록 조회
    /// - Parameters:
    ///   - offset: 시작 인덱스 (0 = 첫 페이지)
    ///   - forceRefresh: true면 캐시 무시 (pull-to-refresh 등 사용자 명시적 새로고침)
    func loadFeeds(offset: Int = 0, forceRefresh: Bool = false) async {
        // 이미 로딩 중이면 중복 호출 방지 (forceRefresh 제외)
        if isLoading && !forceRefresh { return }
        // 추가 페이지 요청인데 더 이상 페이지가 없으면 무시
        if offset > 0 && !hasMorePages { return }

        // 첫 페이지(offset=0) + 강제새로고침 아닐 때만 캐시 시도
        if offset == 0 && !forceRefresh,
           let cached = Self.firstPageCache.value(for: Self.firstPageCacheKey) {
            feeds = cached
            hasMorePages = cached.count >= pageSize
            isLoading = false
            return
        }

        isLoading = true
        do {
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

            // 서버가 pageSize 미만을 반환하면 마지막 페이지
            if persistFeeds.count < pageSize {
                hasMorePages = false
            }

            if offset == 0 {
                feeds = persistFeeds
                hasMorePages = persistFeeds.count >= pageSize
                // 첫 페이지만 캐싱
                Self.firstPageCache.set(persistFeeds, for: Self.firstPageCacheKey)
            } else {
                // 중복 피드 방지: 이미 존재하는 ID 제외
                let existingIds = Set(feeds.map { $0.id })
                let newFeeds = persistFeeds.filter { !existingIds.contains($0.id) }
                feeds.append(contentsOf: newFeeds)
            }
        } catch is CancellationError {
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

    // MARK: - 피드 업로드 이미지 (Data + 원본 사이즈)
    /// 호출 측에서 UIImage 의 size 를 보존하여 전달 — 상세 화면에서 컨테이너 비율 동적 결정에 사용
    struct UploadImage {
        let data: Data
        let width: Int
        let height: Int
    }

    // MARK: - 피드 작성
    /// - Parameter thumbnailFromBefore: true면 Before 사진을, false면 After 사진을 리스트 카드 썸네일로 사용
    /// - Parameter hashtags: 클라이언트에서 추출한 해시태그 (HashtagGenerator 결과)
    /// - Note: 제목(title) 필드는 deprecated — DB 컬럼은 backward compat으로 유지하지만 빈 문자열로 저장
    func createFeed(
        content: String?,
        location: String?,
        washMethod: String?,
        carId: String?,
        beforeImages: [UploadImage],
        afterImages: [UploadImage],
        extraImages: [UploadImage] = [],
        thumbnailFromBefore: Bool = false,
        hashtags: [String] = [],
        isSponsored: Bool = false,
        sponsorName: String? = nil
    ) async throws -> String {
        let session = try await supabase.auth.session
        let feedId = UUID().uuidString

        // 1. 피드 레코드 생성 — title 컬럼은 deprecated, 빈 문자열로 저장
        var feedData: [String: String] = [
            "id": feedId,
            "user_id": session.user.id.uuidString,
            "title": "",
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
        // 썸네일 후보 우선순위: AFTER 첫 이미지 > BEFORE 첫 이미지 > EXTRA 첫 이미지
        // 썸네일은 풀이미지가 아닌 200px 별도 파일로 저장 (리스트 화면 트래픽 절감)
        var thumbnailSourceData: Data?         // 200px 썸네일 생성용 원본 Data
        var beforeFirstThumbnailSource: Data?  // BEFORE fallback
        var extraFirstThumbnailSource: Data?   // EXTRA fallback
        for (index, image) in beforeImages.enumerated() {
            let path = "\(feedId)/before/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: image.data, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            if index == 0 {
                beforeFirstThumbnailSource = image.data
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "BEFORE",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)",
                    "width": "\(image.width)",
                    "height": "\(image.height)"
                ])
                .execute()
        }

        // 3. After 이미지 업로드 및 레코드 생성
        for (index, image) in afterImages.enumerated() {
            let path = "\(feedId)/after/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: image.data, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            // After 첫 이미지가 있다면 썸네일 소스로 우선 채택
            if index == 0 {
                thumbnailSourceData = image.data
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "AFTER",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)",
                    "width": "\(image.width)",
                    "height": "\(image.height)"
                ])
                .execute()
        }

        // 4. Extra 이미지 업로드 및 레코드 생성
        for (index, image) in extraImages.enumerated() {
            let path = "\(feedId)/extra/\(index).jpg"
            try await supabase.storage
                .from("feeds")
                .upload(path: path, file: image.data, options: .init(contentType: "image/jpeg"))

            let publicUrl = try supabase.storage
                .from("feeds")
                .getPublicURL(path: path)

            if index == 0 {
                extraFirstThumbnailSource = image.data
            }

            try await supabase
                .from("feed_images")
                .insert([
                    "feed_id": feedId,
                    "image_type": "EXTRA",
                    "image_url": publicUrl.absoluteString,
                    "display_order": "\(index)",
                    "width": "\(image.width)",
                    "height": "\(image.height)"
                ])
                .execute()
        }

        // 5. 썸네일(200px) 생성 + 별도 파일로 업로드 + DB 갱신
        // 사용자 선택(thumbnailFromBefore) 에 따라 우선순위 결정
        // - thumbnailFromBefore=true:  Before > After > Extra
        // - thumbnailFromBefore=false: After > Before > Extra (기본)
        let chosenSource: Data?
        let chosenSourceType: String?  // 리스트 카드 배지용 — 'BEFORE' / 'AFTER' / 'EXTRA'
        if thumbnailFromBefore {
            if let s = beforeFirstThumbnailSource {
                chosenSource = s; chosenSourceType = "BEFORE"
            } else if let s = thumbnailSourceData {
                chosenSource = s; chosenSourceType = "AFTER"
            } else if let s = extraFirstThumbnailSource {
                chosenSource = s; chosenSourceType = "EXTRA"
            } else {
                chosenSource = nil; chosenSourceType = nil
            }
        } else {
            if let s = thumbnailSourceData {
                chosenSource = s; chosenSourceType = "AFTER"
            } else if let s = beforeFirstThumbnailSource {
                chosenSource = s; chosenSourceType = "BEFORE"
            } else if let s = extraFirstThumbnailSource {
                chosenSource = s; chosenSourceType = "EXTRA"
            } else {
                chosenSource = nil; chosenSourceType = nil
            }
        }
        var thumbnailUrl: String?
        if let sourceData = chosenSource,
           let sourceImage = UIImage(data: sourceData),
           let thumbData = sourceImage.thumbnailJpegData() {
            let thumbPath = "\(feedId)/thumbnail.jpg"
            do {
                try await supabase.storage
                    .from("feeds")
                    .upload(path: thumbPath, file: thumbData, options: .init(contentType: "image/jpeg", upsert: true))
                let publicUrl = try supabase.storage.from("feeds").getPublicURL(path: thumbPath)
                thumbnailUrl = publicUrl.absoluteString
            } catch {
                // TODO-minam: 썸네일 업로드 실패 시 로그 분석 — DB 트리거가 풀이미지로 fallback 처리
                print("⚠️ 썸네일 업로드 실패 (DB 트리거가 fallback): \(error)")
            }
        }

        // feed_images 트리거(`feed_images_refresh_thumbnail`) 가 자동으로 풀이미지를 채우지만
        // 우리가 만든 200px 썸네일이 있으면 그것으로 덮어쓴다 (즉시성).
        // 또한 썸네일 소스 종류(BEFORE/AFTER/EXTRA)도 함께 저장 → 리스트 카드 배지에 활용.
        if thumbnailUrl != nil || chosenSourceType != nil {
            var update: [String: String] = [:]
            if let url = thumbnailUrl { update["thumbnail_url"] = url }
            if let type = chosenSourceType { update["thumbnail_image_type"] = type }
            do {
                try await supabase
                    .from("feeds")
                    .update(update)
                    .eq("id", value: feedId)
                    .execute()
            } catch {
                print("⚠️ thumbnail 메타 업데이트 실패 (DB 트리거가 fallback 처리): \(error)")
            }
        }

        // 5b. 해시태그 저장 — 별도 UPDATE 사용 (배열 타입이라 [String:String] 딕셔너리에 못 담음)
        if !hashtags.isEmpty {
            struct HashtagsUpdate: Encodable { let hashtags: [String] }
            do {
                try await supabase
                    .from("feeds")
                    .update(HashtagsUpdate(hashtags: hashtags))
                    .eq("id", value: feedId)
                    .execute()
            } catch {
                // TODO-minam: 해시태그 저장 실패는 피드 자체에 치명적이지 않으므로 로그만
                print("⚠️ 해시태그 저장 실패: \(error)")
            }
        }

        // 6. 차량이 선택된 경우 wash_logs 에 세차기록 자동 생성
        if let carId = carId {
            do {
                let now = Date()
                let today = ISO8601DateFormatter.string(
                    from: now,
                    timeZone: TimeZone(identifier: "Asia/Seoul") ?? .current,
                    formatOptions: [.withFullDate, .withDashSeparatorInDate]
                )
                // wash_log memo 는 본문 1줄 발췌 — 너무 길면 잘라서 저장 (DB row 가독성)
                let memo: String = {
                    guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                        return "피드에서 자동 생성"
                    }
                    let firstLine = raw.split(separator: "\n").first.map(String.init) ?? raw
                    return String(firstLine.prefix(80))
                }()
                try await supabase
                    .from("wash_logs")
                    .insert([
                        "user_id": session.user.id.uuidString,
                        "car_id": carId,
                        "feed_id": feedId,
                        "wash_date": today,
                        "memo": memo,
                        "status": "ACTIVE"
                    ])
                    .execute()

                // 캐시를 새 세차일로 즉시 갱신 → updateIconIfNeeded()는 DB 재조회 없이 바로 반영
                await DynamicIconService.shared.recordWashDate(now, userId: session.user.id.uuidString)
                // 세차 기록 생성 → 앱 아이콘 즉시 업데이트 (Just Washed: 깨끗한 상태)
                await DynamicIconService.shared.updateIconIfNeeded()
            } catch {
                // TODO-minam: wash_log 자동 생성 실패 시 로그 분석 필요
                print("⚠️ wash_log 자동 생성 실패 (피드 자체는 정상): \(error)")
            }
        }

        // 새 피드가 추가됐으니 첫 페이지 캐시 무효화
        Self.invalidateFeedListCache()
        return feedId
    }

    // MARK: - 피드 수정
    /// - Note: 제목(title) 필드는 deprecated — 호출 측에서 더 이상 전달하지 않음. DB에서도 비우지 않고 그대로 둠
    func updateFeed(
        id: String,
        content: String?,
        location: String?,
        washMethod: String?
    ) async throws {
        struct FeedUpdate: Encodable {
            let content: String
            let location: String
            let wash_method: String
            let is_edited: Bool
        }
        let payload = FeedUpdate(
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

        // 피드 내용 변경 → 캐시 무효화
        Self.invalidateFeedListCache()
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
            // 마지막 세차 기록이 영향받을 수 있으므로 아이콘 캐시도 무효화
            await DynamicIconService.shared.invalidateWashLogCache()
        } catch {
            // TODO-minam: 피드 삭제는 성공했으나 wash_log 삭제 실패 시 로그 분석
            print("⚠️ wash_log 연동 삭제 실패: \(error)")
        }

        feeds.removeAll { $0.id == id }
        // 피드 삭제 → 다른 인스턴스를 위해서도 캐시 무효화
        Self.invalidateFeedListCache()
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
