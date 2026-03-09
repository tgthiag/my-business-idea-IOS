import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct InlineBannerAdView: View {
    let unitID: String
    let minimumHeight: CGFloat

    var body: some View {
        Group {
            #if canImport(GoogleMobileAds)
            BannerContainerView(unitID: unitID)
                .frame(minHeight: minimumHeight)
            #else
            PlaceholderAdCard(minimumHeight: minimumHeight)
            #endif
        }
        .appCard()
    }
}

struct PlaceholderAdCard: View {
    let minimumHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sponsored")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.inkMuted)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.mutedSurface)
                .frame(maxWidth: .infinity, minHeight: minimumHeight)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "megaphone")
                            .font(.title2)
                        Text("Ad space ready for AdMob")
                            .font(.subheadline.weight(.semibold))
                        Text("Inline banner/native slot placeholder for iOS.")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                )
        }
    }
}

@MainActor
final class RewardedGate: ObservableObject {
    static let shared = RewardedGate()

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    #endif

    func preload() {
        #if canImport(GoogleMobileAds)
        RewardedAd.load(with: AppConfig.rewardedAdUnitID, request: Request()) { ad, error in
            if error == nil {
                self.rewardedAd = ad
            }
        }
        #endif
    }

    func show(onReward: @escaping () -> Void, onFailure: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            onFailure()
            return
        }
        if let ad = rewardedAd {
            ad.present(from: root) {
                onReward()
            }
            rewardedAd = nil
            preload()
        } else {
            preload()
            onFailure()
        }
        #else
        onFailure()
        #endif
    }
}

@MainActor
final class InterstitialGate: ObservableObject {
    static let shared = InterstitialGate()

    #if canImport(GoogleMobileAds)
    private var interstitialAd: InterstitialAd?
    #endif

    func preload() {
        #if canImport(GoogleMobileAds)
        InterstitialAd.load(with: AppConfig.interstitialAdUnitID, request: Request()) { ad, error in
            if error == nil {
                self.interstitialAd = ad
            }
        }
        #endif
    }

    func showIfAvailable(onDismiss: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController,
              let ad = interstitialAd else {
            onDismiss()
            return
        }

        ad.present(from: root)
        interstitialAd = nil
        preload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onDismiss()
        }
        #else
        onDismiss()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct BannerContainerView: UIViewRepresentable {
    let unitID: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let banner = BannerView(adSize: currentAdSize())
        banner.adUnitID = unitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        banner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        banner.load(Request())
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func currentAdSize() -> AdSize {
        let width = UIScreen.main.bounds.width - 32
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }
}
#endif

