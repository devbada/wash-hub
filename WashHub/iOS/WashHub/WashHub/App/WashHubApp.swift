import SwiftUI
import Supabase

@main
struct WashHubApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    Task {
                        await authManager.handleDeepLink(url: url)
                    }
                }
        }
    }
}
