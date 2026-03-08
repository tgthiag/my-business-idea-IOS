import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedIdea: Idea?
    @State private var editorSeed: IdeaEditorSeed?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Favorite ideas")

                if appState.favoriteIdeas.isEmpty && appState.favoriteDrafts.isEmpty {
                    EmptyStateCard(
                        title: "No favorites yet",
                        subtitle: "Tap the star on ideas and drafts to keep them here."
                    )
                } else {
                    ForEach(appState.favoriteIdeas) { idea in
                        IdeaSummaryCard(
                            title: idea.title,
                            subtitle: idea.description,
                            footnote: CurrencySupport.format(amount: idea.investment, currencyCode: idea.currencyCode),
                            systemImage: "star.fill",
                            isFavorite: true,
                            onTap: { selectedIdea = idea },
                            onFavorite: { appState.toggleIdeaFavorite(idea) }
                        )
                    }

                    ForEach(appState.favoriteDrafts) { draft in
                        IdeaSummaryCard(
                            title: draft.title,
                            subtitle: draft.description,
                            footnote: CurrencySupport.format(amount: draft.investment, currencyCode: draft.currencyCode),
                            systemImage: "star.fill",
                            isFavorite: true,
                            onTap: {
                                editorSeed = IdeaEditorSeed(
                                    sourceDraftID: draft.id,
                                    sourceIdeaID: nil,
                                    title: draft.title,
                                    description: draft.description,
                                    investment: draft.investment,
                                    currencyCode: draft.currencyCode
                                )
                            },
                            onFavorite: { appState.toggleDraftFavorite(draft) }
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Favorites")
        .sheet(item: $selectedIdea) { idea in
            NavigationStack {
                IdeaDetailView(idea: idea)
                    .environmentObject(appState)
            }
        }
        .sheet(item: $editorSeed) { seed in
            NavigationStack {
                IdeaEditorView(
                    seed: seed,
                    title: "Edit draft",
                    primaryActionTitle: "Generate plan",
                    secondaryActionTitle: "Save draft",
                    onSaveDraft: { updatedSeed in
                        appState.saveDraft(seed: updatedSeed)
                        editorSeed = nil
                    },
                    onGenerate: { updatedSeed in
                        _ = await appState.generateIdea(from: updatedSeed)
                        editorSeed = nil
                    }
                )
            }
        }
    }
}

