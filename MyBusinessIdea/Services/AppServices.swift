import Foundation
import StoreKit
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

extension Notification.Name {
    static let didTapSuggestedIdeaNotification = Notification.Name("didTapSuggestedIdeaNotification")
}

final class AppBootstrapDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let title = userInfo["idea_title"] as? String ?? ""
        let description = userInfo["idea_description"] as? String ?? ""
        NotificationCenter.default.post(
            name: .didTapSuggestedIdeaNotification,
            object: nil,
            userInfo: ["title": title, "description": description]
        )
        completionHandler()
    }
}

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func bootstrap() async {
        await refreshProducts()
        await refreshEntitlements()
    }

    func refreshProducts() async {
        do {
            products = try await Product.products(for: Array(AppConfig.premiumProductIDs))
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            errorMessage = "Subscription product not configured yet."
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                AnalyticsService.log("purchase_success", params: ["product_id": productID])
            case .pending:
                errorMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            AnalyticsService.log("restore_success", params: [:])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var hasPremium = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(entitlement),
               AppConfig.premiumProductIDs.contains(transaction.productID) {
                hasPremium = true
            }
        }
        isPremium = hasPremium
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                if let transaction = try? self.checkVerified(update) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw AppError.message("Unable to verify App Store transaction.")
        case .verified(let value):
            return value
        }
    }
}

final class NotificationScheduler {
    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func cancelAllIdeaNotifications(ownerKey: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("idea_\(ownerKey.normalizedOwnerKey)_") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func sync(ownerKey: String, preferences: NotificationPreferences, pack: [NotificationIdeaItem]) {
        cancelAllIdeaNotifications(ownerKey: ownerKey)
        guard preferences.frequency != .none, !pack.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let baseHour = 10

        for (index, item) in pack.enumerated() {
            guard let scheduledDate = calendar.date(
                byAdding: .day,
                value: preferences.frequency.intervalDays * index + 1,
                to: Date()
            ) else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
            components.hour = baseHour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.description
            content.sound = .default
            content.userInfo = [
                "idea_title": item.title,
                "idea_description": item.description
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "idea_\(ownerKey.normalizedOwnerKey)_\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}

enum AnalyticsService {
    static func log(_ event: String, params: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event, parameters: params)
        #endif
    }
}

