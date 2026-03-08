import StoreKit
import SwiftUI

@main
struct MyBusinessIdeaApp: App {
    @UIApplicationDelegateAdaptor(AppBootstrapDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Group {
            if appState.isBootstrapping {
                NavigationStack {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.background.ignoresSafeArea())
                }
            } else if appState.user == nil {
                NavigationStack {
                    AuthFlowView()
                }
            } else {
                MainTabView()
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $appState.showPremiumSheet) {
            PremiumView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showNotificationPrompt) {
            NotificationPreferenceSheet()
                .environmentObject(appState)
        }
        .sheet(item: $appState.notificationEditorSeed) { seed in
            NavigationStack {
                IdeaEditorView(
                    seed: seed,
                    title: "New draft",
                    primaryActionTitle: "Generate plan",
                    secondaryActionTitle: "Save draft",
                    onSaveDraft: { updatedSeed in
                        appState.saveDraft(seed: updatedSeed)
                        appState.notificationEditorSeed = nil
                    },
                    onGenerate: { updatedSeed in
                        _ = await appState.generateIdea(from: updatedSeed)
                        appState.notificationEditorSeed = nil
                    }
                )
            }
        }
        .onChange(of: appState.reviewRequestNonce) { _, newValue in
            if newValue > 0 {
                requestReview()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapSuggestedIdeaNotification)) { note in
            let title = note.userInfo?["title"] as? String ?? note.userInfo?["idea_title"] as? String ?? ""
            let description = note.userInfo?["description"] as? String ?? note.userInfo?["idea_description"] as? String ?? ""
            appState.handleNotificationTap(title: title, description: description)
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.activeTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                IdeasHubView()
            }
            .tabItem {
                Label("Ideas", systemImage: "list.bullet.clipboard")
            }
            .tag(AppTab.ideas)

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label("Favorites", systemImage: "star")
            }
            .tag(AppTab.favorites)

            NavigationStack {
                AccountView()
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle")
            }
            .tag(AppTab.account)
        }
        .tint(AppColors.accentStart)
    }
}
