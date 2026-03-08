import Foundation

enum AppConfig {
    static let appName = "My Business Idea"
    static let apiBaseURL = URL(string: "https://instrutores.tgapps.dev")!
    static let playStorePromoURL = URL(string: "https://play.google.com/store/apps/details?id=com.mybusinessidea")!
    static let privacyPolicyURL = URL(string: "https://tgapps.dev/my_business_idea_privacy")!
    static let accountDeletionURL = URL(string: "https://tgapps.dev/my_business_idea_account_deletion")!
    static let supportEmail = "support@tgapps.dev"

    // Replace these with the real iOS subscription ids in App Store Connect.
    static let monthlyPremiumProductID = "com.mybusinessidea.premium.monthly"
    static let yearlyPremiumProductID = "com.mybusinessidea.premium.yearly"
    static let premiumProductIDs: Set<String> = [
        monthlyPremiumProductID,
        yearlyPremiumProductID
    ]

    // Replace with real iOS ad unit ids before release.
    static let homeBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let detailBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    static let dailyFreeGenerationLimit = 6
    static let paywallTriggerAfterGenerations = 6
    static let reviewPromptAfterIdeaCount = 2
    static let notificationPromptAfterIdeaCount = 3
}
