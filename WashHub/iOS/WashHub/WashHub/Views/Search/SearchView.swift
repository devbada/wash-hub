import SwiftUI

/// 통합 검색 화면
struct SearchView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var searchService = SearchService()
    @ObservedObject private var blockService = BlockService.shared
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedTab: SearchResultType = .all
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // 검색 바
                searchBar

                if isSearching {
                    // 검색 결과
                    searchResultContent
                } else {
                    // 검색 전: 최근 검색어
                    historyContent
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            if !authManager.isGuest {
                await searchService.loadHistory()
            }
        }
    }

    // MARK: - 검색 바
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.theme.textDisabled)

                TextField("피드, 케미컬, 세차장, 루틴 검색", text: $searchText)
                    .font(.appBody)
                    .foregroundColor(.theme.textPrimary)
                    .focused($isTextFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearching = false
                        searchService.clearResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.theme.surfaceHigh)
            .cornerRadius(12)

            Button("취소") {
                dismiss()
            }
            .font(.appBody)
            .foregroundColor(.theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 최근 검색어 (검색 전)
    private var historyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !searchService.searchHistories.isEmpty {
                    // 헤더
                    HStack {
                        Text("최근 검색")
                            .font(.appBodyBold)
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                        Button(action: {
                            Task { await searchService.deleteAllHistory() }
                        }) {
                            Text("전체 삭제")
                                .font(.appSmall)
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // 검색어 칩
                    FlowLayout(spacing: 8) {
                        ForEach(searchService.searchHistories) { history in
                            historyChip(history)
                        }
                    }
                    .padding(.horizontal, 16)
                } else if !authManager.isGuest {
                    // 빈 상태
                    VStack(spacing: 12) {
                        Spacer().frame(height: 60)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.theme.textDisabled)
                        Text("검색어를 입력하세요")
                            .font(.appBody)
                            .foregroundColor(.theme.textDisabled)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - 검색어 칩
    private func historyChip(_ history: SearchHistory) -> some View {
        HStack(spacing: 4) {
            Button(action: {
                searchText = history.query
                performSearch()
            }) {
                Text(history.query)
                    .font(.appCaption)
                    .foregroundColor(.theme.textPrimary)
            }

            Button(action: {
                Task { await searchService.deleteHistory(id: history.id) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.theme.textDisabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.theme.surfaceLow)
        .cornerRadius(16)
    }

    // MARK: - 검색 결과 컨텐츠
    private var searchResultContent: some View {
        VStack(spacing: 0) {
            // 탭 선택
            resultTabBar

            // 결과 목록
            if searchService.isLoading {
                Spacer()
                ProgressView().tint(.theme.secondary)
                Spacer()
            } else if searchService.results.isEmpty {
                emptyResult
            } else {
                resultList
            }
        }
    }

    // MARK: - 결과 탭 바
    private var resultTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SearchResultType.allCases, id: \.self) { tab in
                    let count = countForTab(tab)
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .theme.surface : .theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.theme.secondary : Color.theme.surfaceHigh)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 결과 목록
    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selectedTab {
                case .all:
                    allResultsSection
                case .feed:
                    feedResultsSection
                case .equipment:
                    equipmentResultsSection
                case .carWash:
                    carWashResultsSection
                case .routine:
                    routineResultsSection
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - 전체 결과 (섹션별)
    private var allResultsSection: some View {
        VStack(spacing: 0) {
            if !searchService.results.feeds.isEmpty {
                sectionHeader(title: "피드", count: searchService.results.feeds.count, tab: .feed)
                ForEach(searchService.results.feeds.prefix(3)) { feed in
                    NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                        FeedSearchRow(feed: feed)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !searchService.results.equipments.isEmpty {
                sectionHeader(title: "케미컬", count: searchService.results.equipments.count, tab: .equipment)
                ForEach(searchService.results.equipments.prefix(3)) { equipment in
                    NavigationLink(destination: EquipmentDetailView(equipment: equipment, onChanged: { })) {
                        EquipmentSearchRow(equipment: equipment)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !searchService.results.carWashes.isEmpty {
                sectionHeader(title: "세차장", count: searchService.results.carWashes.count, tab: .carWash)
                ForEach(searchService.results.carWashes.prefix(3)) { carWash in
                    NavigationLink(destination: CarWashDetailView(carWash: carWash, onChanged: { })) {
                        CarWashSearchRow(carWash: carWash)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !searchService.results.routines.isEmpty {
                sectionHeader(title: "루틴", count: searchService.results.routines.count, tab: .routine)
                ForEach(searchService.results.routines.prefix(3)) { routine in
                    NavigationLink(destination: RoutineDetailView(routineId: routine.id)) {
                        RoutineSearchRow(routine: routine)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 타입별 전체 결과
    private var feedResultsSection: some View {
        ForEach(searchService.results.feeds) { feed in
            NavigationLink(destination: FeedDetailView(feedId: feed.id)) {
                FeedSearchRow(feed: feed)
            }
            .buttonStyle(.plain)
        }
    }

    private var equipmentResultsSection: some View {
        ForEach(searchService.results.equipments) { equipment in
            NavigationLink(destination: EquipmentDetailView(equipment: equipment, onChanged: { })) {
                EquipmentSearchRow(equipment: equipment)
            }
            .buttonStyle(.plain)
        }
    }

    private var carWashResultsSection: some View {
        ForEach(searchService.results.carWashes) { carWash in
            NavigationLink(destination: CarWashDetailView(carWash: carWash, onChanged: { })) {
                CarWashSearchRow(carWash: carWash)
            }
            .buttonStyle(.plain)
        }
    }

    private var routineResultsSection: some View {
        ForEach(searchService.results.routines) { routine in
            NavigationLink(destination: RoutineDetailView(routineId: routine.id)) {
                RoutineSearchRow(routine: routine)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 섹션 헤더
    private func sectionHeader(title: String, count: Int, tab: SearchResultType) -> some View {
        HStack {
            Text(title)
                .font(.appBodyBold)
                .foregroundColor(.theme.textPrimary)
            Text("\(count)")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
            Spacer()
            if count > 3 {
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 2) {
                        Text("더보기")
                            .font(.appSmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.theme.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - 빈 결과
    private var emptyResult: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.theme.textDisabled)
            Text("'\(searchText)' 검색 결과가 없습니다")
                .font(.appBody)
                .foregroundColor(.theme.textSecondary)
            Text("다른 검색어를 입력해보세요")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
            Spacer()
        }
    }

    // MARK: - Helpers
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        isTextFieldFocused = false
        selectedTab = .all
        Task {
            await searchService.search(query: query)
            if !authManager.isGuest {
                await searchService.saveHistory(query: query)
                await searchService.loadHistory()
            }
        }
    }

    private func countForTab(_ tab: SearchResultType) -> Int {
        switch tab {
        case .all: return searchService.results.totalCount
        case .feed: return searchService.results.feeds.count
        case .equipment: return searchService.results.equipments.count
        case .carWash: return searchService.results.carWashes.count
        case .routine: return searchService.results.routines.count
        }
    }
}

// MARK: - FlowLayout (검색어 칩용 래핑 레이아웃)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
