import Foundation
import Combine
import Supabase

/// "For You" 추천 피드 — Edge Function `for-you-feed` 호출 래퍼.
/// 기존 `FeedService` 와 분리하여 추천 흐름이 일반 시간순 피드를 오염시키지 않도록 한다.
///
/// 호출 패턴은 `WashIndexService.loadWashIndex` 와 동일하게
/// `supabase.functions.invoke("for-you-feed", options: .init(body: payload))`.
@MainActor
final class ForYouFeedService: ObservableObject {

    // MARK: - Published State
    @Published var items: [ForYouFeedItem] = []
    @Published var isLoading: Bool = false
    @Published var hasMorePages: Bool = true
    @Published var coldStart: Bool = false
    @Published var errorMessage: String?
    /// 마지막 응답의 metrics — 디버그 화면이나 모니터링 분석용
    @Published var lastMetrics: ForYouFeedMetrics?

    // MARK: - Config
    private let pageSize: Int = 20
    /// 추천은 매 진입마다 신선해야 하므로 캐시 보수적 — TTL 30초만
    private static let responseCache = TimedCache<String, ForYouFeedResponse>(ttl: 30)

    // MARK: - Cache key
    private func cacheKey(limit: Int, offset: Int, location: ForYouFeedRequestLocation?) -> String {
        let lat = location.map { String(format: "%.3f", $0.latitude) } ?? "nil"
        let lng = location.map { String(format: "%.3f", $0.longitude) } ?? "nil"
        return "fyf.\(limit).\(offset).\(lat).\(lng)"
    }

    /// 새 피드/좋아요/팔로우 등 추천 결과를 무효화해야 하는 mutation 후 호출
    static func invalidateCache() {
        responseCache.invalidateAll()
    }

    // MARK: - Public API

    /// 추천 피드 첫 페이지 로드.
    /// - Parameters:
    ///   - location: 위치 정보 (옵션 — 없으면 LocationProximityScorer 0 처리)
    ///   - forceRefresh: true면 캐시 무시 (pull-to-refresh)
    func loadFirstPage(location: ForYouFeedRequestLocation? = nil, forceRefresh: Bool = false) async {
        if isLoading && !forceRefresh { return }
        await fetch(offset: 0, location: location, forceRefresh: forceRefresh, append: false)
    }

    /// 다음 페이지 로드 (현재 items 끝에 append).
    func loadNextPage(location: ForYouFeedRequestLocation? = nil) async {
        if isLoading { return }
        if !hasMorePages { return }
        await fetch(offset: items.count, location: location, forceRefresh: false, append: true)
    }

    // MARK: - Internal fetch

    private func fetch(
        offset: Int,
        location: ForYouFeedRequestLocation?,
        forceRefresh: Bool,
        append: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let key = cacheKey(limit: pageSize, offset: offset, location: location)
        if !forceRefresh, let cached = Self.responseCache.value(for: key) {
            applyResponse(cached, append: append)
            return
        }

        let payload = ForYouFeedRequest(
            limit: pageSize,
            offset: offset,
            location: location,
            debug: false
        )

        do {
            let response: ForYouFeedResponse = try await supabase.functions
                .invoke(
                    "for-you-feed",
                    options: .init(body: payload)
                )
            Self.responseCache.set(response, for: key)
            applyResponse(response, append: append)
        } catch {
            // TODO-minam: 추천 호출 실패 분류 (401 → 재로그인, 406 → 콜드스타트 온보딩, 그 외 → fallback 메시지)
            print("⚠️ ForYouFeed 호출 실패: \(error)")
            errorMessage = friendlyMessage(for: error)
            if !append {
                // 첫 페이지 실패 시 비우지 않고 기존 결과를 유지 (백오프 후 재시도 사용자 경험)
            }
        }
    }

    private func applyResponse(_ response: ForYouFeedResponse, append: Bool) {
        coldStart = response.coldStart
        lastMetrics = response.metrics

        if append {
            // 중복 제거
            let existingIds = Set(items.map { $0.feedId })
            let newItems = response.items.filter { !existingIds.contains($0.feedId) }
            items.append(contentsOf: newItems)
        } else {
            items = response.items
        }
        // 응답 개수가 pageSize 미만이면 더 이상 페이지 없음
        hasMorePages = response.items.count >= pageSize
    }

    private func friendlyMessage(for error: Error) -> String {
        let raw = "\(error)"
        if raw.contains("COLDSTART_PROFILE_MISSING") {
            return "온보딩 정보가 부족해서 추천을 만들 수 없어요. 차종이나 지역을 등록해주세요."
        }
        if raw.contains("INVALID_LIMIT") || raw.contains("INVALID_OFFSET") {
            return "요청 파라미터가 잘못됐어요. 잠시 후 다시 시도해주세요."
        }
        if raw.contains("INVALID_LOCATION") {
            return "위치 정보가 유효하지 않아요."
        }
        if raw.contains("401") {
            return "로그인이 만료됐어요. 다시 로그인해주세요."
        }
        return "추천 피드를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
    }
}
