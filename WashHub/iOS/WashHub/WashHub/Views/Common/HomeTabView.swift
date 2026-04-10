import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var showLoginAlert = false
    @State private var showCreateFeed = false

    init() {
        // 탭바 배경을 밝게 — Pristine White + Subtle Top Border
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.shadowColor = UIColor(white: 0, alpha: 0.06) // 얇은 상단 구분선
        appearance.shadowImage = nil

        // 선택/비선택 아이템 색상 (Citrus Olive / Zinc)
        let olive = UIColor(red: 101/255, green: 163/255, blue: 13/255, alpha: 1.0)
        let zinc = UIColor(red: 113/255, green: 113/255, blue: 122/255, alpha: 1.0)

        appearance.stackedLayoutAppearance.selected.iconColor = olive
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: olive]
        appearance.stackedLayoutAppearance.normal.iconColor = zinc
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: zinc]

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // 1. 피드 탭 (게스트 허용)
                FeedListView()
                    .tabItem {
                        Image(systemName: "photo.stack")
                        Text("피드")
                    }
                    .tag(0)

                // 2. 루틴 탭 (게스트 허용)
                RoutineListView()
                    .tabItem {
                        Image(systemName: "list.bullet.clipboard")
                        Text("루틴")
                    }
                    .tag(2)

                // 3. 가운데 플레이스홀더 — FAB 공간 확보용 (비활성)
                Color.clear
                    .tabItem {
                        Text(" ")
                    }
                    .tag(1)

                // 4. 케미컬 탭 (게스트 허용) — 세차장 진입점은 툴바에서 제공
                EquipmentListView()
                    .tabItem {
                        Image(systemName: "drop.circle")
                        Text("케미컬")
                    }
                    .tag(3)

                // 5. 내차 탭 (로그인 필요)
                MyCarListView()
                    .tabItem {
                        Image(systemName: "car.fill")
                        Text("내차")
                    }
                    .tag(4)
            }
            .tint(.theme.secondary)
            .onChange(of: selectedTab, perform: { newTab in
                if newTab == 1 {
                    // 플레이스홀더 탭은 선택되지 않도록 되돌림 — FAB이 실제 액션 담당
                    selectedTab = 0
                } else if authManager.isGuest && newTab == 4 {
                    selectedTab = 0
                    showLoginAlert = true
                }
            })

            // 가운데 떠 있는 작성 FAB — Hero 액션
            createFloatingButton
                .offset(y: -2)
                .allowsHitTesting(true)
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

    // MARK: - 작성 FAB
    private var createFloatingButton: some View {
        Button(action: handleCreateTap) {
            ZStack {
                // 외곽 글로우 링
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

                // 메인 원
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 132/255, green: 204/255, blue: 22/255), // #84CC16
                                Color(red: 101/255, green: 163/255, blue: 13/255)  // #65A30D
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

                // 플러스 아이콘
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

