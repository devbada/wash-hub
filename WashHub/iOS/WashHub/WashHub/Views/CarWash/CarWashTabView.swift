import SwiftUI

/// v2 세차장 탭 — 지도가 메인, 좌상단 ☰ / 우상단 "목록" 토글
///
/// P2-012 IA 개편: 세차장이 메인 탭으로 승격(REDESIGN_BRIEF 3.1).
/// 실제 MapKit 지도(`CarWashMapView`)를 기본 화면으로 올리고,
/// 우상단 "목록"으로 리스트 뷰(`CarWashListView`)를 시트로 전환한다.
struct CarWashTabView: View {
    @EnvironmentObject var authManager: AuthManager
    /// 좌상단 ☰ — HomeTabView 의 햄버거 드로어를 연다
    var onMenu: () -> Void = {}

    @State private var showList = false

    var body: some View {
        NavigationStack {
            CarWashMapView()
                .navigationTitle("세차장")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onMenu) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.theme.textPrimary)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showList = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                Text("목록")
                            }
                            .font(.appLabel)
                            .foregroundColor(.theme.textPrimary)
                        }
                    }
                }
        }
        .fullScreenCover(isPresented: $showList) {
            CarWashListView()
                .environmentObject(authManager)
        }
    }
}
