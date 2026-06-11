import SwiftUI

/// v2 메인 탭 컨테이너 — 5탭(홈/세차장/+/세차용품/내차) + 좌상단 햄버거 드로어
///
/// P2-012 IA 개편:
/// - 탭 태그: 0 홈, 1 세차장, 2 = 중앙 FAB(가상), 3 세차용품, 4 내차
/// - 좌상단 ☰ → HamburgerDrawerView (현재 홈 화면에서 진입, 타 탭은 후속 태스크)
struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var uiState = AppUIState.shared
    @ObservedObject private var coachmark = CoachmarkController.shared
    @State private var selectedTab = 0
    @State private var showLoginAlert = false
    @State private var showCreateFeed = false

    // v2 — 햄버거 드로어 / 드로어에서 진입하는 화면들
    @State private var showDrawer = false
    @State private var showMyPage = false
    @State private var showNotifications = false
    /// v2 — 드로어 검색 / 전용 설정 화면 / 로그아웃 확인
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showLogoutConfirm = false
    /// 피드 작성 완료 플래그 — 작성 화면이 닫힌 뒤 피드 목록으로 이동시키기 위함
    @State private var feedJustCreated = false

    /// iPad 판별 (Regular width)
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    /// 드로어/홈 상단바에 노출할 사용자명
    private var userName: String {
        authManager.currentUser?.displayName ?? "세차러"
    }

    var body: some View {
        ZStack {
            Group {
                if isWideLayout {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            // v2 — 드로어/홈 진입 화면은 풀스크린 + 좌상단 백버튼 (sheet 카드 아님)
            .fullScreenCover(isPresented: $showCreateFeed, onDismiss: {
                // 피드 등록 완료 시 → 피드 목록으로 이동
                if feedJustCreated {
                    feedJustCreated = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pushToHome(.feedList)
                    }
                }
            }) {
                CreateFeedView(onFeedCreated: { _ in feedJustCreated = true })
                    .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $showMyPage) {
                NavigationStack {
                    MyPageView(isModal: true)
                        .environmentObject(authManager)
                        .environmentObject(navCoordinator)
                }
            }
            .fullScreenCover(isPresented: $showNotifications) {
                NavigationStack {
                    NotificationListView()
                        .environmentObject(authManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { showNotifications = false }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.theme.textPrimary)
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showSearch) {
                NavigationStack {
                    SearchView()
                        .environmentObject(authManager)
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(onClose: { showSettings = false })
                        .environmentObject(authManager)
                }
            }
            .alert("로그아웃", isPresented: $showLogoutConfirm) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    Task { try? await authManager.signOut() }
                }
            } message: {
                Text("로그아웃 하시겠어요?")
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") {
                    authManager.exitGuestMode()
                }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("이 기능을 사용하려면 로그인이 필요해요.\n소셜 로그인으로 간편하게 가입하고 사용해보세요!")
            }
            .collectCoachmarkAnchors(coachmark)
            .onAppear { triggerCoachmarkIfNeeded() }
            // 탭 전환 시 스크롤 기반 자동 숨김은 항상 초기화 (다른 탭의 잔존 상태 차단)
            .onChange(of: selectedTab) { _, _ in
                if uiState.scrollHidesBottom {
                    uiState.scrollHidesBottom = false
                }
            }

            // 햄버거 드로어 — 탭바 위, 코치마크 아래
            HamburgerDrawerView(
                isOpen: showDrawer,
                userName: userName,
                isGuest: authManager.isGuest,
                onClose: { showDrawer = false },
                onGo: handleDrawer
            )

            // 코치마크 오버레이 — 최상단
            CoachmarkOverlay(controller: coachmark)
        }
    }

    /// 첫 진입 시 코치마크 자동 시작 — anchor 좌표 등록 시간을 위해 약간 대기
    private func triggerCoachmarkIfNeeded() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            // sheet/alert/drawer 가 떠 있으면 진행하지 않음
            guard !showCreateFeed, !showLoginAlert, !showDrawer else { return }
            coachmark.startIfNeeded(
                version: CoachmarkVersion.homeV1,
                steps: HomeCoachmark.v1Steps
            )
        }
    }

    /// 햄버거 드로어 진입 액션 라우팅 (REDESIGN_BRIEF 6.2 / 6.3)
    private func handleDrawer(_ dest: DrawerDestination) {
        showDrawer = false
        switch dest {
        case .washIndex:
            // 세차 예측 — 홈 스택 푸시 (스와이프 뒤로가기 지원)
            pushToHome(.forecast)
        case .map:
            selectedTab = 1
        case .equipment:
            selectedTab = 3
        case .myCarRecord, .myCarManage, .nextWash:
            selectedTab = 4
        case .badges:
            // 내 뱃지 — 홈 스택 푸시
            pushToHome(.badges)
        case .feed, .liked, .following:
            pushToHome(.feedList)
        case .routines:
            // 추천 루틴 — 홈 스택 푸시
            pushToHome(.routines)
        case .settings:
            // 설정 — 전용 설정 화면
            showSettings = true
        case .help:
            // 도움말 — 온보딩 코치마크 재생. 홈 탭으로 전환 후,
            // 드로어 닫힘 애니메이션이 끝난 뒤 시작한다.
            selectedTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                coachmark.forceStart(steps: HomeCoachmark.v1Steps)
            }
        case .search:
            // 통합 검색 화면
            showSearch = true
        case .logout:
            if authManager.isGuest {
                // TODO-minam: 둘러보기 끝내기 선택 시 로그인 화면으로 바로 이동하는지 확인해 주세요.
                authManager.exitGuestMode()
            } else {
                showLogoutConfirm = true
            }
        }
    }

    /// 지정한 화면을 홈 NavigationStack 에 push — 드로어/바로가기 등 외부 진입점 공용.
    /// 홈 탭으로 전환한 뒤 기존 경로를 비우고 대상 화면을 푸시한다.
    private func pushToHome(_ target: FeedNavTarget) {
        selectedTab = 0
        if navCoordinator.feedPath.count > 0 {
            navCoordinator.feedPath.removeLast(navCoordinator.feedPath.count)
        }
        navCoordinator.feedPath.append(target)
    }

    private func openMyPage() {
        guard authManager.isAuthenticated, !authManager.isGuest else {
            showLoginAlert = true
            return
        }

        // TODO-minam: 둘러보기 모드에서 홈 프로필 아이콘을 눌렀을 때 로그인 안내만 노출되는지 확인해야 합니다.
        showMyPage = true
    }

    /// 하단 UI 숨김 여부 — 강제(댓글/루틴) 또는 스크롤 기반 자동 숨김 둘 중 하나라도 true 면 숨김
    private var shouldHideBottom: Bool { uiState.shouldHideBottom }

    // MARK: - 탭 콘텐츠 (iPhone/iPad 공용)
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            // v2 — 홈 탭은 NavigationStack 으로 감싸 피드 목록·상세를 푸시 화면으로 표시.
            // 푸시 화면이라 iOS 기본 뒤로가기 스와이프가 그대로 동작한다(차량 상세와 동일).
            NavigationStack(path: $navCoordinator.feedPath) {
                HomeView(
                    userName: userName,
                    onMenu: { showDrawer = true },
                    onNotifications: { showNotifications = true },
                    onMyPage: openMyPage,
                    onSelectTab: { selectedTab = $0 },
                    onRoutines: { pushToHome(.routines) },
                    onOpenFeed: { pushToHome(.feedList) }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: FeedNavTarget.self) { target in
                    switch target {
                    case .feedList:
                        FeedListView()
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .feedDetail(let feedId):
                        FeedDetailView(feedId: feedId)
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .myPage:
                        MyPageView()
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .forYou:
                        ForYouFeedView()
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .routines:
                        RoutineListView(embedInNavigation: false)
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .routineDetail(let routineId):
                        RoutineDetailView(routineId: routineId)
                            .environmentObject(authManager)
                            .environmentObject(navCoordinator)
                    case .forecast:
                        WashForecastView(embedInNavigation: false)
                    case .badges:
                        BadgeCollectionView()
                            .environmentObject(authManager)
                    }
                }
            }
        case 1:
            CarWashTabView(onMenu: { showDrawer = true })
        case 3:
            EquipmentListView()
        case 4:
            MyCarListView(onMenu: { showDrawer = true })
        default:
            Color.theme.surface.ignoresSafeArea()
        }
    }

    // MARK: - iPhone 레이아웃 (커스텀 탭바 + 중앙 FAB)
    /// 콘텐츠는 ZStack 의 base 레이어로 항상 풀스크린(탭바 영역까지 차지).
    /// 탭바/FAB 은 그 위 overlay. 자식 수를 일정하게 유지해 ScrollView 안정화.
    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 커스텀 하단 탭바 — 항상 자식 + 시각만 숨김 (ScrollView 안정화)
            customTabBar
                .offset(y: shouldHideBottom ? 120 : 0)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)

            // 중앙 FAB — 댓글/루틴 따라하기/스크롤 다운 시 숨김
            createFloatingButton
                .offset(y: shouldHideBottom ? 120 : 6)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)
        }
    }

    // MARK: - iPad 레이아웃 (커스텀 탭바 + 우측 하단 FAB)
    private var iPadLayout: some View {
        ZStack(alignment: .bottomTrailing) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
                .frame(maxWidth: .infinity)
                .offset(y: shouldHideBottom ? 120 : 0)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)

            createFloatingButton
                .padding(.trailing, 28)
                .padding(.bottom, 80)
                .offset(y: shouldHideBottom ? 120 : 0)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)
        }
    }

    // MARK: - 커스텀 탭바 (홈/세차장/+/세차용품/내차)
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house", filledIcon: "house.fill", tag: 0)
                .coachmarkAnchor(CoachmarkAnchorID.tabHome)
            tabButton(icon: "map", filledIcon: "map.fill", tag: 1)
                .coachmarkAnchor(CoachmarkAnchorID.tabCarWash)

            // 가운데 FAB 공간
            Spacer().frame(width: 96)

            tabButton(icon: "drop.circle", filledIcon: "drop.circle.fill", tag: 3)
                .coachmarkAnchor(CoachmarkAnchorID.tabEquipment)
            tabButton(icon: "car", filledIcon: "car.fill", tag: 4)
                .coachmarkAnchor(CoachmarkAnchorID.tabMyCar)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: -1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// 탭 라벨 — 라벨 없는 아이콘 금지 (DESIGN.md 7.4 발견성 규칙)
    private func tabLabel(_ tag: Int) -> String {
        switch tag {
        case 0:  return "홈"
        case 1:  return "세차장"
        case 3:  return "세차용품"
        case 4:  return "내차"
        default: return ""
        }
    }

    private func tabButton(icon: String, filledIcon: String, tag: Int) -> some View {
        Button {
            if authManager.isGuest && tag == 4 {
                showLoginAlert = true
                return
            }
            // 동일 탭 재탭 → NavigationStack pop-to-root + 스크롤 최상단
            if selectedTab == tag {
                navCoordinator.popAndScrollToTop(tab: tag)
            } else {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selectedTab == tag ? filledIcon : icon)
                    .font(.system(size: 24))
                Text(tabLabel(tag))
                    .font(.system(size: 11, weight: selectedTab == tag ? .bold : .medium))
            }
            .foregroundColor(
                selectedTab == tag
                    ? Color.theme.textPrimary   // Carbon #18181B — 활성
                    : Color.theme.outline        // Zinc 300 #D4D4D8 — 비활성
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 작성 FAB
    private var createFloatingButton: some View {
        Button(action: handleCreateTap) {
            ZStack {
                Circle()
                    .fill(Color.theme.primary)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.theme.textPrimary.opacity(0.16), radius: 12, x: 0, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.theme.onPrimary)
            }
            .frame(width: 96, height: 96)
        }
        .buttonStyle(FABPressStyle())
        .coachmarkAnchor(CoachmarkAnchorID.fabCreate)
        // TODO-minam: 홈과 피드 화면에서 Carbon FAB가 탭바와 충분히 구분되는지 확인해 주세요.
    }

    private func handleCreateTap() {
        if authManager.isGuest {
            showLoginAlert = true
            return
        }
        // 가운데 FAB = 핵심 액션(피드 작성) — 탭과 무관하게 항상 동일 동작
        showCreateFeed = true
    }
}

// MARK: - FAB 프레스 애니메이션
private struct FABPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
