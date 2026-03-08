import SwiftUI

struct NotificationPreferenceSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var frequency: NotificationFrequency = .none
    @State private var mode: NotificationMode = .random

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Receive idea notifications?")
                        .font(.largeTitle.bold())
                    Text("Choose how often you want to receive local business idea suggestions.")
                        .foregroundStyle(AppColors.inkMuted)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How often?")
                            .font(.headline)
                        ForEach(NotificationFrequency.allCases) { option in
                            Button {
                                frequency = option
                            } label: {
                                HStack {
                                    Image(systemName: frequency == option ? "largecircle.fill.circle" : "circle")
                                    Text(option.title)
                                    Spacer()
                                }
                                .foregroundStyle(AppColors.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .appCard()

                    if frequency != .none {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What type of ideas?")
                                .font(.headline)
                            ForEach(NotificationMode.allCases) { option in
                                Button {
                                    mode = option
                                } label: {
                                    HStack {
                                        Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(option.title)
                                            Text(option == .random ? "Uses the random discover flow." : "Uses your existing idea titles as interest signals.")
                                                .font(.caption)
                                                .foregroundStyle(AppColors.inkMuted)
                                        }
                                        Spacer()
                                    }
                                    .foregroundStyle(AppColors.ink)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .appCard()
                    }

                    HStack(spacing: 12) {
                        Button("Later") {
                            appState.dismissNotificationPrompt()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 1)
                        )

                        PrimaryActionButton(title: "Save") {
                            Task {
                                await appState.syncNotificationPreferences(frequency: frequency, mode: mode)
                                appState.showNotificationPrompt = false
                                dismiss()
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .onAppear {
                frequency = appState.notificationPreferences.frequency
                mode = appState.notificationPreferences.mode
            }
        }
    }
}
