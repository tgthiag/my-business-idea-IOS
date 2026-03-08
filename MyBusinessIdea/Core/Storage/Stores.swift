import Foundation
import Security

protocol JSONStoring {
    func load<T: Decodable>(_ type: T.Type, key: String) -> T?
    func save<T: Encodable>(_ value: T, key: String)
    func remove(key: String)
}

final class UserDefaultsJSONStore: JSONStoring {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load<T>(_ type: T.Type, key: String) -> T? where T: Decodable {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T>(_ value: T, key: String) where T: Encodable {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func remove(key: String) {
        defaults.removeObject(forKey: key)
    }
}

final class TokenStore {
    private let service = "com.mybusinessidea.ios.token"
    private let account = "auth_token"

    func load() -> String? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func save(_ token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class DraftStore {
    private let store = UserDefaultsJSONStore()

    func load(ownerKey: String) -> [DraftIdea] {
        store.load([DraftIdea].self, key: key(ownerKey)) ?? []
    }

    func save(_ drafts: [DraftIdea], ownerKey: String) {
        store.save(drafts, key: key(ownerKey))
    }

    private func key(_ ownerKey: String) -> String {
        "drafts_\(ownerKey.normalizedOwnerKey)"
    }
}

final class FavoriteStore {
    private let store = UserDefaults.standard

    func load(ownerKey: String) -> Set<Int> {
        let raw = store.array(forKey: key(ownerKey)) as? [Int] ?? []
        return Set(raw)
    }

    func save(_ favoriteIDs: Set<Int>, ownerKey: String) {
        store.set(Array(favoriteIDs), forKey: key(ownerKey))
    }

    private func key(_ ownerKey: String) -> String {
        "idea_favorites_\(ownerKey.normalizedOwnerKey)"
    }
}

final class GenerationLimitStore {
    private let defaults = UserDefaults.standard
    private let countKey = "generation_limit_count"
    private let dateKey = "generation_limit_date"

    func countToday() -> Int {
        syncDateIfNeeded()
        return defaults.integer(forKey: countKey)
    }

    func increment() {
        syncDateIfNeeded()
        defaults.set(countToday() + 1, forKey: countKey)
    }

    func isLimitReached(limit: Int) -> Bool {
        countToday() >= limit
    }

    private func syncDateIfNeeded() {
        let today = ISO8601DateFormatter.shortDate.string(from: Date())
        if defaults.string(forKey: dateKey) != today {
            defaults.set(today, forKey: dateKey)
            defaults.set(0, forKey: countKey)
        }
    }
}

final class NotificationPreferencesStore {
    private let store = UserDefaultsJSONStore()

    func load(ownerKey: String) -> NotificationPreferences {
        store.load(NotificationPreferences.self, key: prefsKey(ownerKey)) ?? NotificationPreferences()
    }

    func save(_ preferences: NotificationPreferences, ownerKey: String) {
        store.save(preferences, key: prefsKey(ownerKey))
    }

    func loadPack(ownerKey: String) -> [NotificationIdeaItem] {
        store.load([NotificationIdeaItem].self, key: packKey(ownerKey)) ?? []
    }

    func savePack(_ pack: [NotificationIdeaItem], ownerKey: String) {
        store.save(pack, key: packKey(ownerKey))
    }

    private func prefsKey(_ ownerKey: String) -> String {
        "notification_preferences_\(ownerKey.normalizedOwnerKey)"
    }

    private func packKey(_ ownerKey: String) -> String {
        "notification_pack_\(ownerKey.normalizedOwnerKey)"
    }
}

final class ReviewPromptStore {
    private let defaults = UserDefaults.standard

    func hasPrompted(ownerKey: String) -> Bool {
        defaults.bool(forKey: key(ownerKey))
    }

    func markPrompted(ownerKey: String) {
        defaults.set(true, forKey: key(ownerKey))
    }

    private func key(_ ownerKey: String) -> String {
        "review_prompted_\(ownerKey.normalizedOwnerKey)"
    }
}

extension String {
    var normalizedOwnerKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }
}
