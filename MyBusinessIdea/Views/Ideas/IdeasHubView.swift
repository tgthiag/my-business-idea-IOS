import SwiftUI

struct IdeasHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editorSeed: IdeaEditorSeed?
    @State private var searchSheet = false
    @State private var selectedIdea: Idea?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "My ideas")

                if appState.ideas.isEmpty {
                    EmptyStateCard(
                        title: "No generated ideas yet",
                        subtitle: "Generate a plan from the Home tab or from the search sheet."
                    )
                } else {
                    ForEach(appState.ideas) { idea in
                        IdeaSummaryCard(
                            title: idea.title,
                            subtitle: idea.description,
                            footnote: CurrencySupport.format(amount: idea.investment, currencyCode: idea.currencyCode),
                            systemImage: "doc.text.magnifyingglass",
                            isFavorite: idea.isFavorite,
                            onTap: { selectedIdea = idea },
                            onFavorite: { appState.toggleIdeaFavorite(idea) }
                        )
                        .contextMenu {
                            Button("Open details") { selectedIdea = idea }
                            Button("Edit idea") {
                                editorSeed = IdeaEditorSeed(
                                    sourceDraftID: nil,
                                    sourceIdeaID: idea.id,
                                    title: idea.title,
                                    description: idea.description,
                                    investment: idea.investment,
                                    currencyCode: idea.currencyCode
                                )
                            }
                            Button(role: .destructive) {
                                Task { await appState.deleteIdea(idea) }
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                }

                SectionHeader(title: "Drafts")

                if appState.drafts.isEmpty {
                    EmptyStateCard(
                        title: "No drafts",
                        subtitle: "Save ideas locally before generating plans."
                    )
                } else {
                    ForEach(appState.drafts) { draft in
                        IdeaSummaryCard(
                            title: draft.title,
                            subtitle: draft.description,
                            footnote: CurrencySupport.format(amount: draft.investment, currencyCode: draft.currencyCode),
                            systemImage: "square.and.pencil",
                            isFavorite: draft.isFavorite,
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
                        .contextMenu {
                            Button("Edit draft") {
                                editorSeed = IdeaEditorSeed(
                                    sourceDraftID: draft.id,
                                    sourceIdeaID: nil,
                                    title: draft.title,
                                    description: draft.description,
                                    investment: draft.investment,
                                    currencyCode: draft.currencyCode
                                )
                            }
                            Button(role: .destructive) {
                                appState.deleteDraft(draft)
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    searchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
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
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editorSeed) { seed in
            NavigationStack {
                IdeaEditorView(
                    seed: seed,
                    title: seed.sourceIdeaID == nil ? "Edit draft" : "Update idea",
                    primaryActionTitle: seed.sourceIdeaID == nil ? "Generate plan" : "Regenerate plan",
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
        .sheet(isPresented: $searchSheet) {
            NavigationStack {
                IdeaSearchSheet { seed in
                    searchSheet = false
                    editorSeed = seed
                }
                .environmentObject(appState)
            }
        }
        .sheet(item: $selectedIdea) { idea in
            NavigationStack {
                IdeaDetailView(idea: idea)
                    .environmentObject(appState)
            }
        }
        .task {
            try? await appState.refreshIdeas()
        }
    }
}

