import StoreKit
import SwiftUI

struct PremiumView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Premium subscription")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColors.ink)

                    Text("Remove ads and unlock the full idea generation flow, exports, and premium actions.")
                        .foregroundStyle(AppColors.inkMuted)

                    VStack(spacing: 12) {
                        ForEach(appState.purchaseManager.products, id: \.id) { product in
                            Button {
                                Task {
                                    await appState.purchaseManager.purchase(productID: product.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline.bold())
                                }
                                .padding(16)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.accentStart, AppColors.accentEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.purchaseManager.isBusy)
                        }
                    }

                    if appState.purchaseManager.products.isEmpty {
                        EmptyStateCard(
                            title: "Subscriptions not loaded yet",
                            subtitle: "Configure the real App Store product ids in AppConfig and refresh on device."
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Benefits")
                            .font(.title3.bold())
                        Label("No ads", systemImage: "checkmark.seal")
                        Label("Unlimited idea generation", systemImage: "checkmark.seal")
                        Label("Premium PDF export", systemImage: "checkmark.seal")
                        Label("Frictionless search and load more ideas", systemImage: "checkmark.seal")
                    }
                    .foregroundStyle(AppColors.ink)
                    .appCard()

                    if let errorMessage = appState.purchaseManager.errorMessage {
                        InlineErrorCard(message: errorMessage)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Premium")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore purchases") {
                        Task {
                            await appState.purchaseManager.restorePurchases()
                        }
                    }
                    .disabled(appState.purchaseManager.isBusy)
                }
            }
        }
    }
}

