import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject private var uiState = AppUIState.shared
    @State private var selectedTab = 0
    @State private var showLoginAlert = false
    @State private var showCreateFeed = false

    /// iPad 판별 (Regular width)
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.shadowColor = UIColor(white: 0, alpha: 0.06)
        appearance.shadowImage = nil

        let olive = UIColor(red: 101/255, green: 163/255, blue: 13/255, alpha: 1.0)
        let zinc = UIColor(red: 113/255, green: 113/255, blue: 122/255, alpha: 1.0)

        appearance.stackedLayoutAppearance.selected.iconColor = olive
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: olive]
        appearance.stackedLayoutAppearance.normal.iconColor = zinc
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: zinc]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
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
            Text("이 기능을 사용하려면 로그인이 필요합니다.\n간편하게 Google로 시작해보세요!")
        }
    }

    // MARK: - iPhone 레이아웃 (기존 TabView + 중앙 FAB)
    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedListView()
                    .tabItem {
                        Image(systemName: "photo.stack")
                        Text("피드")
                    }
                    .tag(0)

                RoutineListView()
                    .tabItem {
                        Image(systemName: "list.bullet.clipboard")
                        Text("루틴")
                    }
                    .tag(2)

                // 플레이스홀더 — FAB이 덮음
                Color.clear
                    .tabItem { Text(" ") }
                    .tag(1)

                EquipmentListView()
                    .tabItem {
                        Image(systemName: "drop.circle")
                        Text("케미컬")
                    }
                    .tag(3)

                MyCarListView()
                    .tabItem {
                        Image(systemName: "car.fill")
                        Text("내차")
                    }
                    .tag(4)
            }
            .tint(.theme.secondary)
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 1 {
                    selectedTab = 0
                    handleCreateTap()
                } else if authManager.isGuest && newTab == 4 {
                    selectedTab = 0
                    showLoginAlert = true
                }
            }

            // 중앙 FAB — 댓글/루틴 따라하기 시 숨김
            createFloatingButton
                .offset(y: uiState.hideBottomUI ? 120 : -2)
                .opacity(uiState.hideBottomUI ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: uiState.hideBottomUI)
                .allowsHitTesting(!uiState.hideBottomUI)
        }
    }

    // MARK: - iPad 레이아웃 (커스텀 하단 탭바 + 우측 하단 FAB)
    private var iPadLayout: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // 콘텐츠 영역 — 활성 탭만 렌더링 (제스처 충돌 방지)
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

                // 커스텀 하단 탭바
                iPadTabBar
            }

            // 우측 하단 FAB — 댓글/루틴 따라하기 시 숨김
            createFloatingButton
                .padding(.trailing, 28)
                .padding(.bottom, 80)
                .offset(y: uiState.hideBottomUI ? 120 : 0)
                .opacity(uiState.hideBottomUI ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: uiState.hideBottomUI)
                .allowsHitTesting(!uiState.hideBottomUI)
        }
    }

    // MARK: - iPad 커스텀 탭바
    private var iPadTabBar: some View {
        HStack(spacing: 0) {
            iPadTabButton(title: "피드", icon: "photo.stack", tag: 0)
            iPadTabButton(title: "루틴", icon: "list.bullet.clipboard", tag: 2)

            // 가운데 FAB 공간
            Spacer().frame(width: 96)

            iPadTabButton(title: "케미컬", icon: "drop.circle", tag: 3)
            iPadTabButton(title: "내차", icon: "car.fill", tag: 4)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: -1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func iPadTabButton(title: String, icon: String, tag: Int) -> some View {
        Button {
            if authManager.isGuest && tag == 4 {
                showLoginAlert = true
            } else {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(
                selectedTab == tag
                    ? Color(red: 101/255, green: 163/255, blue: 13/255) // olive
                    : Color(red: 113/255, green: 113/255, blue: 122/255) // zinc
            )
            .frame(maxWidth: .infinity)
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
    }

    private func handleCreateTap() {
        if authManager.isGuest {
            showLoginAlert = true
        } else {
            showCreateFeed = true
        }
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
