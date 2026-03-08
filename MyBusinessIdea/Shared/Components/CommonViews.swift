import SwiftUI

struct LoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppColors.ink)
            Text(subtitle)
                .foregroundStyle(AppColors.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct InlineErrorCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppColors.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? .yellow : AppColors.inkMuted)
                .font(.title3)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryActionButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(AppGradientButtonStyle(disabled: disabled))
            .disabled(disabled)
    }
}

struct SecondaryPillButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct IdeaSummaryCard: View {
    let title: String
    let subtitle: String
    let footnote: String?
    let systemImage: String
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(AppColors.accentStart)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.inkMuted)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    FavoriteButton(isFavorite: isFavorite, action: onFavorite)
                }
                if let footnote, !footnote.isEmpty {
                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
        .buttonStyle(.plain)
    }
}

