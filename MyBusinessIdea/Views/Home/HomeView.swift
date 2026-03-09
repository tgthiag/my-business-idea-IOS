import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editorSeed: IdeaEditorSeed?
    @State private var showSearchSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                actionCards

                if !appState.purchaseManager.isPremium {
                    premiumCTA
                }

                InlineBannerAdView(unitID: AppConfig.homeBannerAdUnitID, minimumHeight: 120)

                SectionHeader(title: "See if you like one of these")

                if appState.isHomeLoading {
                    LoadingCard(title: "Loading random ideas…")
                } else if let globalError = appState.globalError {
                    InlineErrorCard(message: globalError)
                } else if appState.homeSuggestions.isEmpty {
                    EmptyStateCard(
                        title: "No suggestions available right now",
                        subtitle: "Pull to refresh or try again later."
                    )
                } else {
                    ForEach(appState.homeSuggestions) { suggestion in
                        IdeaSummaryCard(
                            title: suggestion.title,
                            subtitle: suggestion.description,
                            footnote: "Tap to open it in the draft editor.",
                            systemImage: "sparkles",
                            isFavorite: false,
                            onTap: {
                                editorSeed = IdeaEditorSeed(
                                    sourceDraftID: nil,
                                    sourceIdeaID: nil,
                                    title: suggestion.title,
                                    description: suggestion.description,
                                    investment: 0,
                                    currencyCode: CurrencySupport.detectFromDevice()
                                )
                            },
                            onFavorite: {}
                        )
                    }

                    Button("Generate more ideas") {
                        Task {
                            if appState.purchaseManager.isPremium {
                                await appState.loadMoreHomeSuggestions()
                            } else {
                                RewardedGate.shared.show(
                                    onReward: {
                                        Task { await appState.loadMoreHomeSuggestions() }
                                    },
                                    onFailure: {
                                        appState.showPremiumSheet = true
                                    }
                                )
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(AppColors.accentStart)
                    .frame(maxWidth: .infinity, alignment: .center)

                    InlineBannerAdView(unitID: AppConfig.detailBannerAdUnitID, minimumHeight: 120)
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Home")
        .sheet(item: $editorSeed) { seed in
            NavigationStack {
                IdeaEditorView(
                    seed: seed,
                    title: "New draft",
                    primaryActionTitle: "Generate plan",
                    secondaryActionTitle: "Save draft",
                    onSaveDraft: { updatedSeed in
                        appState.saveDraft(seed: updatedSeed)
                        editorSeed = nil
                    },
                    onGenerate: { updatedSeed in
                        _ = await appState.generateIdea(from: updatedSeed)
                        editorSeed = nil
                        InterstitialGate.shared.showIfAvailable {}
                    }
                )
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            NavigationStack {
                IdeaSearchSheet { seed in
                    editorSeed = seed
                }
                .environmentObject(appState)
            }
        }
        .task {
            await appState.loadHomeSuggestions(force: false)
            RewardedGate.shared.preload()
            InterstitialGate.shared.preload()
        }
        .refreshable {
            await appState.loadHomeSuggestions(force: true)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transform ideas into action")
                .font(.title.bold())
                .foregroundStyle(AppColors.ink)
            Text("\(appState.ideas.count) ideas | \(appState.drafts.count) drafts | \(appState.favoriteIdeas.count + appState.favoriteDrafts.count) favorites")
                .foregroundStyle(AppColors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var actionCards: some View {
        VStack(spacing: 12) {
            Button {
                editorSeed = IdeaEditorSeed(
                    sourceDraftID: nil,
                    sourceIdeaID: nil,
                    title: "",
                    description: "",
                    investment: 0,
                    currencyCode: CurrencySupport.detectFromDevice()
                )
            } label: {
                actionCard(
                    title: "Add manually",
                    subtitle: "Write your business idea from scratch and save it as a draft.",
                    systemImage: "square.and.pencil"
                )
            }
            .buttonStyle(.plain)

            Button {
                showSearchSheet = true
            } label: {
                actionCard(
                    title: "Search ideas",
                    subtitle: "Search topics and turn the best suggestion into a draft or plan.",
                    systemImage: "magnifyingglass"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var premiumCTA: some View {
        Button {
            appState.showPremiumSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Go Premium")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("No ads, unlimited idea generation, faster load more, and premium PDF export.")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [AppColors.accentStart, AppColors.accentEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppColors.accentStart)
                .frame(width: 34, height: 34)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.inkMuted)
            }
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(AppColors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

