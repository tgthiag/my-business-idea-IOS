import SwiftUI

enum AppColors {
    static let background = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let surface = Color.white
    static let mutedSurface = Color(red: 0.92, green: 0.95, blue: 0.99)
    static let ink = Color(red: 0.18, green: 0.24, blue: 0.35)
    static let inkMuted = Color(red: 0.42, green: 0.49, blue: 0.61)
    static let accentStart = Color(red: 0.97, green: 0.39, blue: 0.17)
    static let accentEnd = Color(red: 0.45, green: 0.21, blue: 0.86)
    static let premium = Color(red: 0.54, green: 0.28, blue: 0.95)
    static let success = Color.green
    static let warning = Color.orange
    static let border = Color.black.opacity(0.08)
}

struct AppGradientButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: disabled ? [Color.gray.opacity(0.45), Color.gray.opacity(0.45)] : [AppColors.accentStart, AppColors.accentEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(disabled ? 0.7 : 1)
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

