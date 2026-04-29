import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var uiState = AppUIState.shared
    @ObservedObject private var coachmark = CoachmarkController.shared
    @State private var selectedTab = 0
    @State private var showLoginAlert = false
    @State private var showCreateFeed = false

    /// iPad 판별 (Regular width)
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
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
            .sheet(isPresented: $showCreateFeed) {
                CreateFeedView()
                    .environmentObject(authManager)
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") {
                    authManager.exitGuestMode()
                }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("이 기능을 사용하려면 로그인이 필요합니다.\n소셜 로그인으로 간편하게 가입하고 사용해보세요!")
            }
            .collectCoachmarkAnchors(coachmark)
            .onAppear { triggerCoachmarkIfNeeded() }
            // 탭 전환 시 스크롤 기반 자동 숨김은 항상 초기화 (다른 탭의 잔존 상태 차단)
            .onChange(of: selectedTab) { _, _ in
                if uiState.scrollHidesBottom {
                    uiState.scrollHidesBottom = false
                }
            }

            // 코치마크 오버레이 — 최상단
            CoachmarkOverlay(controller: coachmark)
        }
    }

    /// 첫 진입 시 코치마크 자동 시작 — anchor 좌표 등록 시간을 위해 약간 대기
    private func triggerCoachmarkIfNeeded() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            // sheet/alert 가 떠 있으면 진행하지 않음
            guard !showCreateFeed, !showLoginAlert else { return }
            coachmark.startIfNeeded(
                version: CoachmarkVersion.homeV1,
                steps: HomeCoachmark.v1Steps
            )
        }
    }

    /// 하단 UI 숨김 여부 — 강제(댓글/루틴) 또는 스크롤 기반 자동 숨김 둘 중 하나라도 true 면 숨김
    private var shouldHideBottom: Bool { uiState.shouldHideBottom }

    // MARK: - iPhone 레이아웃 (커스텀 탭바 + 중앙 FAB)
    /// 콘텐츠는 ZStack 의 base 레이어로 항상 풀스크린(탭바 영역까지 차지).
    /// 탭바/FAB 은 그 위 overlay — 숨김/표시되어도 콘텐츠 영역은 변화 없음.
    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            // 콘텐츠 — 항상 풀스크린 (탭바 영역 포함). 스크롤 시 layout 변화 없음
            Group {
                switch selectedTab {
                case 0:  FeedListView()
                case 2:  RoutineListView()
                case 3:  EquipmentListView()
                case 4:  MyCarListView()
                default: FeedListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 커스텀 하단 탭바 — overlay (콘텐츠 위에 떠있음). 숨김 시 슬라이드 다운
            if !shouldHideBottom {
                customTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 중앙 FAB — 댓글/루틴 따라하기/스크롤 다운 시 숨김
            createFloatingButton
                .offset(y: shouldHideBottom ? 120 : 6)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)
        }
        .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
    }

    // MARK: - iPad 레이아웃 (커스텀 탭바 + 우측 하단 FAB)
    private var iPadLayout: some View {
        ZStack(alignment: .bottomTrailing) {
            // 콘텐츠 — 항상 풀스크린 (제스처 충돌 방지로 활성 탭만 렌더링)
            Group {
                switch selectedTab {
                case 0:  FeedListView()
                case 2:  RoutineListView()
                case 3:  EquipmentListView()
                case 4:  MyCarListView()
                default: FeedListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 커스텀 하단 탭바 — overlay
            if !shouldHideBottom {
                customTabBar
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 우측 하단 FAB — overlay
            createFloatingButton
                .padding(.trailing, 28)
                .padding(.bottom, 80)
                .offset(y: shouldHideBottom ? 120 : 0)
                .opacity(shouldHideBottom ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
                .allowsHitTesting(!shouldHideBottom)
        }
        .animation(.easeInOut(duration: 0.3), value: shouldHideBottom)
    }

    // MARK: - 커스텀 탭바 (iPhone + iPad 공용)
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "photo.stack", filledIcon: "photo.stack.fill", tag: 0)
                .coachmarkAnchor(CoachmarkAnchorID.tabFeed)
            tabButton(icon: "list.bullet.clipboard", filledIcon: "list.bullet.clipboard.fill", tag: 2)
                .coachmarkAnchor(CoachmarkAnchorID.tabRoutine)

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

    private func tabButton(icon: String, filledIcon: String, tag: Int) -> some View {
        Button {
            if authManager.isGuest && tag == 4 {
                showLoginAlert = true
                return
            }
            // 동일 탭 재탭 → 스크롤 최상단 이동 / 다른 탭 → 일반 전환
            if selectedTab == tag {
                NotificationCenter.default.post(
                    name: .requestScrollToTop,
                    object: nil,
                    userInfo: ["tab": tag]
                )
            } else {
                selectedTab = tag
            }
        } label: {
            Image(systemName: selectedTab == tag ? filledIcon : icon)
                .font(.system(size: 24))
                .foregroundColor(
                    selectedTab == tag
                        ? Color.theme.textPrimary   // Carbon #18181B — 활성
                        : Color.theme.outline        // Zinc 300 #D4D4D8 — 비활성
                )
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 작성 FAB
    private var createFloatingButton: some View {
        Button(action: handleCreateTap) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 132/255, green: 204/255, blue: 22/255).opacity(0.35),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 50
                        )
                    )
                    .frame(width: 96, height: 96)
                    .blur(radius: 6)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 132/255, green: 204/255, blue: 22/255),
                                Color(red: 101/255, green: 163/255, blue: 13/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    )
                    .shadow(color: Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.5), radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(FABPressStyle())
        .coachmarkAnchor(CoachmarkAnchorID.fabCreate)
    }

    private func handleCreateTap() {
        if authManager.isGuest {
            showLoginAlert = true
            return
        }
        // 가운데 FAB = 핵심 액션(피드 작성) — 탭과 무관하게 항상 동일 동작
        // 루틴/케미컬/내차 추가는 각 화면의 우측 상단 + 버튼으로 분리됨
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
