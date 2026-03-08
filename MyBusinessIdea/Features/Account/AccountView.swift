import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLanguageSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My account")
                        .font(.largeTitle.bold())
                    if let user = appState.user {
                        Text(user.name)
                            .font(.title3.bold())
                        Text(user.email)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                }

                Button {
                    showLanguageSheet = true
                } label: {
                    accountRow(
                        title: "Language",
                        subtitle: LanguageOption.supported.first(where: { $0.code == appState.currentLanguageCode })?.title ?? appState.currentLanguageCode,
                        systemImage: "globe"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.showPremiumSheet = true
                } label: {
                    accountRow(
                        title: appState.purchaseManager.isPremium ? "Premium active" : "Premium",
                        subtitle: appState.purchaseManager.isPremium ? "Ads removed and premium features enabled." : "Unlock no ads, unlimited generation, and PDF export.",
                        systemImage: "crown.fill"
                    )
                }
                .buttonStyle(.plain)

                Link(destination: AppConfig.privacyPolicyURL) {
                    accountRow(
                        title: "Privacy policy",
                        subtitle: "How we use your data.",
                        systemImage: "hand.raised.fill"
                    )
                }
                .buttonStyle(.plain)

                Link(destination: AppConfig.accountDeletionURL) {
                    accountRow(
                        title: "Delete account",
                        subtitle: "Open the account deletion page.",
                        systemImage: "trash.fill"
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    appState.signOut()
                } label: {
                    accountRow(
                        title: "Logout",
                        subtitle: "Sign out from this device.",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .buttonStyle(.plain)

                if let globalError = appState.globalError {
                    InlineErrorCard(message: globalError)
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Account")
        .sheet(isPresented: $showLanguageSheet) {
            NavigationStack {
                List(LanguageOption.supported) { option in
                    Button {
                        Task {
                            await appState.updateLanguage(to: option)
                            showLanguageSheet = false
                        }
                    } label: {
                        HStack {
                            Text(option.title)
                            Spacer()
                            if option.code == appState.currentLanguageCode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(AppColors.ink)
                }
                .navigationTitle("Language")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            showLanguageSheet = false
                        }
                    }
                }
            }
        }
    }

    private func accountRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.accentStart)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

