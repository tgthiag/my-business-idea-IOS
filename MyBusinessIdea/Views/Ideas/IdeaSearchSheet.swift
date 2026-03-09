import SwiftUI

struct IdeaSearchSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onSelect: (IdeaEditorSeed) -> Void

    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Search ideas")
                    .font(.largeTitle.bold())
                Text("Generate 6 suggestions and tap the pencil to open in the editor.")
                    .foregroundStyle(AppColors.inkMuted)

                HStack(spacing: 12) {
                    TextField("Search topic", text: $query)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppColors.accentStart.opacity(0.25), lineWidth: 1)
                        )

                    Button {
                        Task { await appState.searchSuggestions(for: query) }
                    } label: {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(
                                Circle().fill(
                                    LinearGradient(colors: [AppColors.accentStart, AppColors.accentEnd], startPoint: .leading, endPoint: .trailing)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }

                if appState.isSearching {
                    LoadingCard(title: "Searching ideas…")
                } else if let error = appState.globalError {
                    InlineErrorCard(message: error)
                } else if !appState.searchSuggestions.isEmpty {
                    Text("Suggestions")
                        .font(.title3.bold())
                    ForEach(appState.searchSuggestions) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.title3.bold())
                                Text(item.description)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .lineLimit(5)
                            }
                            Spacer()
                            Button {
                                onSelect(
                                    IdeaEditorSeed(
                                        sourceDraftID: nil,
                                        sourceIdeaID: nil,
                                        title: item.title,
                                        description: item.description,
                                        investment: 0,
                                        currencyCode: CurrencySupport.detectFromDevice()
                                    )
                                )
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(AppColors.accentStart)
                            }
                            .buttonStyle(.plain)
                        }
                        .appCard()
                    }

                    Button("Generate more ideas") {
                        Task {
                            if appState.purchaseManager.isPremium {
                                await appState.loadMoreSearchSuggestions(query: query)
                            } else {
                                RewardedGate.shared.show(
                                    onReward: {
                                        Task { await appState.loadMoreSearchSuggestions(query: query) }
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
                }

                Button("Close") {
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

