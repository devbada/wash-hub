import Foundation
import Combine
import Supabase

/// 검색 결과 타입
enum SearchResultType: String, CaseIterable {
    case all = "전체"
    case feed = "피드"
    case equipment = "케미컬"
    case carWash = "세차장"
    case routine = "루틴"
}

/// 통합 검색 결과
struct SearchResults {
    var feeds: [Feed] = []
    var equipments: [Equipment] = []
    var carWashes: [CarWash] = []
    var routines: [Routine] = []

    var totalCount: Int {
        feeds.count + equipments.count + carWashes.count + routines.count
    }

    var isEmpty: Bool { totalCount == 0 }
}

/// 검색 이력 모델
struct SearchHistory: Codable, Identifiable {
    let id: String
    let userId: String
    let query: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case query
        case createdAt = "created_at"
    }
}

@MainActor
final class SearchService: ObservableObject {
    @Published var results = SearchResults()
    @Published var searchHistories: [SearchHistory] = []
    @Published var isLoading = false

    private let pageSize = 10

    // MARK: - 통합 검색
    /// 모든 타입을 동시에 검색한다
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = SearchResults()
            return
        }

        isLoading = true
        let pattern = "%\(trimmed)%"

        async let feedsTask = searchFeeds(pattern: pattern)
        async let equipmentsTask = searchEquipments(pattern: pattern)
        async let carWashesTask = searchCarWashes(pattern: pattern)
        async let routinesTask = searchRoutines(pattern: pattern)

        let (feeds, equipments, carWashes, routines) = await (feedsTask, equipmentsTask, carWashesTask, routinesTask)

        results = SearchResults(
            feeds: feeds,
            equipments: equipments,
            carWashes: carWashes,
            routines: routines
        )
        isLoading = false
    }

    // MARK: - 타입별 검색 (더보기용)
    func searchMore(query: String, type: SearchResultType, offset: Int) async {
        let pattern = "%\(query.trimmingCharacters(in: .whitespacesAndNewlines))%"
        guard !pattern.isEmpty else { return }

        switch type {
        case .feed:
            let more = await searchFeeds(pattern: pattern, offset: offset)
            results.feeds.append(contentsOf: more)
        case .equipment:
            let more = await searchEquipments(pattern: pattern, offset: offset)
            results.equipments.append(contentsOf: more)
        case .carWash:
            let more = await searchCarWashes(pattern: pattern, offset: offset)
            results.carWashes.append(contentsOf: more)
        case .routine:
            let more = await searchRoutines(pattern: pattern, offset: offset)
            results.routines.append(contentsOf: more)
        case .all:
            break
        }
    }

    // MARK: - 피드 검색
    private func searchFeeds(pattern: String, offset: Int = 0) async -> [Feed] {
        do {
            let persistFeeds: [Feed] = try await supabase
                .from("feeds")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official), my_cars(id, car_model, car_color, car_year, nickname)")
                .eq("status", value: "ACTIVE")
                .or("content.ilike.\(pattern)")
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            return persistFeeds
        } catch {
            print("Search feeds error: \(error)")
            return []
        }
    }

    // MARK: - 케미컬 검색
    private func searchEquipments(pattern: String, offset: Int = 0) async -> [Equipment] {
        do {
            let persistEquipments: [Equipment] = try await supabase
                .from("equipments")
                .select()
                .eq("status", value: "ACTIVE")
                .or("name.ilike.\(pattern),description.ilike.\(pattern)")
                .order("name")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            return persistEquipments
        } catch {
            print("Search equipments error: \(error)")
            return []
        }
    }

    // MARK: - 세차장 검색
    private func searchCarWashes(pattern: String, offset: Int = 0) async -> [CarWash] {
        do {
            let persistCarWashes: [CarWash] = try await supabase
                .from("car_washes")
                .select()
                .eq("status", value: "ACTIVE")
                .or("name.ilike.\(pattern),address.ilike.\(pattern)")
                .order("name")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            return persistCarWashes
        } catch {
            print("Search car_washes error: \(error)")
            return []
        }
    }

    // MARK: - 루틴 검색
    private func searchRoutines(pattern: String, offset: Int = 0) async -> [Routine] {
        do {
            let persistRoutines: [Routine] = try await supabase
                .from("routines")
                .select("*, profiles!user_id(id, nickname, avatar_url, is_official), routine_steps(*)")
                .eq("status", value: "ACTIVE")
                .or("title.ilike.\(pattern),description.ilike.\(pattern)")
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            return persistRoutines
        } catch {
            print("Search routines error: \(error)")
            return []
        }
    }

    // MARK: - 검색 이력 저장
    func saveHistory(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let session = try await supabase.auth.session

            // 동일 검색어 중복 제거 (최신으로 갱신)
            try await supabase
                .from("search_history")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("query", value: trimmed)
                .execute()

            // 새로 저장
            try await supabase
                .from("search_history")
                .insert([
                    "user_id": session.user.id.uuidString,
                    "query": trimmed
                ])
                .execute()
        } catch {
            print("Save search history error: \(error)")
        }
    }

    // MARK: - 검색 이력 로드
    func loadHistory() async {
        do {
            let session = try await supabase.auth.session
            let persistHistories: [SearchHistory] = try await supabase
                .from("search_history")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .order("created_at", ascending: false)
                .range(from: 0, to: 19)
                .execute()
                .value
            searchHistories = persistHistories
        } catch {
            print("Load search history error: \(error)")
        }
    }

    // MARK: - 검색 이력 단건 삭제
    func deleteHistory(id: String) async {
        do {
            try await supabase
                .from("search_history")
                .delete()
                .eq("id", value: id)
                .execute()
            searchHistories.removeAll { $0.id == id }
        } catch {
            print("Delete search history error: \(error)")
        }
    }

    // MARK: - 검색 이력 전체 삭제
    func deleteAllHistory() async {
        do {
            let session = try await supabase.auth.session
            try await supabase
                .from("search_history")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            searchHistories = []
        } catch {
            print("Delete all search history error: \(error)")
        }
    }

    // MARK: - 검색 결과 초기화
    func clearResults() {
        results = SearchResults()
    }
}
