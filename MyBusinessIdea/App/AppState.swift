import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isBootstrapping = true
    @Published var activeTab: AppTab = .home
    @Published var user: AppUser?
    @Published var token: String?

    @Published var ideas: [Idea] = []
    @Published var drafts: [DraftIdea] = []
    @Published var homeSuggestions: [IdeaSuggestion] = []
    @Published var searchSuggestions: [IdeaSuggestion] = []
    @Published var relatedVideos: [Int: [RelatedVideo]] = [:]

    @Published var authError: String?
    @Published var globalError: String?
    @Published var isAuthenticating = false
    @Published var isIdeasLoading = false
    @Published var isGenerating = false
    @Published var isHomeLoading = false
    @Published var isSearching = false

    @Published var showPremiumSheet = false
    @Published var showNotificationPrompt = false
    @Published var notificationPreferences = NotificationPreferences()
    @Published var reviewRequestNonce = 0
    @Published var notificationEditorSeed: IdeaEditorSeed?
    @Published var recovery = RecoveryContext()
    @Published var currentLanguageCode = LanguageOption.supported.first?.code ?? "en_us"

    let purchaseManager = PurchaseManager()
    private let api = APIClient()
    private let tokenStore = TokenStore()
    private let draftStore = DraftStore()
    private let favoriteStore = FavoriteStore()
    private let generationLimitStore = GenerationLimitStore()
    private let notificationStore = NotificationPreferencesStore()
    private let notificationScheduler = NotificationScheduler()
    private let reviewPromptStore = ReviewPromptStore()

    var ownerKey: String? {
        user?.email
    }

    var favoriteIdeas: [Idea] {
        ideas.filter(\.isFavorite)
    }

    var favoriteDrafts: [DraftIdea] {
        drafts.filter(\.isFavorite)
    }

    var generationCountToday: Int {
        generationLimitStore.countToday()
    }

    var canGenerateForFree: Bool {
        purchaseManager.isPremium || !generationLimitStore.isLimitReached(limit: AppConfig.dailyFreeGenerationLimit)
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        await purchaseManager.bootstrap()

        currentLanguageCode = detectDefaultLanguageCode()
        guard let savedToken = tokenStore.load() else { return }
        token = savedToken

        do {
            let me = try await api.fetchMe(token: savedToken)
            user = me
            currentLanguageCode = me.languageCode
            hydrateLocalStores()
            if let ownerKey, notificationPreferences.frequency != .none {
                let storedPack = notificationStore.loadPack(ownerKey: ownerKey)
                notificationScheduler.sync(ownerKey: ownerKey, preferences: notificationPreferences, pack: storedPack)
            }
            try await refreshIdeas()
            await loadHomeSuggestions(force: false)
        } catch {
            tokenStore.clear()
            token = nil
            user = nil
        }
    }

    func authenticate(
        mode: AuthMode,
        name: String,
        email: String,
        password: String,
        birthDate: String,
        securityQuestionID: String,
        securityAnswer: String
    ) async {
        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        do {
            let session: AuthSession
            switch mode {
            case .login:
                session = try await api.login(email: email, password: password)
            case .register:
                session = try await api.register(
                    name: name,
                    email: email,
                    password: password,
                    languageCode: currentLanguageCode,
                    birthDate: birthDate,
                    securityQuestionId: securityQuestionID,
                    securityAnswer: securityAnswer.normalizedSecurityAnswer()
                )
            }

            token = session.token
            user = session.user
            currentLanguageCode = session.user.languageCode
            tokenStore.save(session.token)
            hydrateLocalStores()
            try await refreshIdeas()
            await loadHomeSuggestions(force: true)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        if let ownerKey {
            notificationScheduler.cancelAllIdeaNotifications(ownerKey: ownerKey)
        }
        tokenStore.clear()
        token = nil
        user = nil
        ideas = []
        drafts = []
        homeSuggestions = []
        searchSuggestions = []
        relatedVideos = [:]
        activeTab = .home
        authError = nil
        globalError = nil
        recovery = RecoveryContext()
    }

    func refreshIdeas() async throws {
        guard let token, let ownerKey else { return }
        isIdeasLoading = true
        defer { isIdeasLoading = false }
        let favoriteIDs = favoriteStore.load(ownerKey: ownerKey)
        ideas = try await api.fetchIdeas(token: token, favoriteIDs: favoriteIDs)
    }

    func loadHomeSuggestions(force: Bool) async {
        guard let token else { return }
        if !force, !homeSuggestions.isEmpty { return }
        isHomeLoading = true
        globalError = nil
        defer { isHomeLoading = false }

        do {
            homeSuggestions = try await api.discoverIdeas(token: token, limit: 7)
            AnalyticsService.log("native_impression_home", params: [:])
        } catch {
            globalError = error.localizedDescription
        }
    }

    func loadMoreHomeSuggestions() async {
        guard let token else { return }
        do {
            let more = try await api.discoverIdeas(token: token, limit: 7)
            homeSuggestions = dedupeSuggestions(homeSuggestions + more)
            generationLimitStore.increment()
            AnalyticsService.log("home_load_more_click", params: [:])
            if shouldOpenPaywallAfterFreeGenerations {
                showPremiumSheet = true
            }
        } catch {
            globalError = error.localizedDescription
        }
    }

    func searchSuggestions(for query: String) async {
        guard let token else { return }
        let safeQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeQuery.isEmpty else {
            searchSuggestions = []
            return
        }

        isSearching = true
        globalError = nil
        defer { isSearching = false }

        do {
            searchSuggestions = try await api.searchIdeas(token: token, query: safeQuery, limit: 6)
        } catch {
            globalError = error.localizedDescription
        }
    }

    func loadMoreSearchSuggestions(query: String) async {
        guard let token else { return }
        do {
            let more = try await api.searchIdeas(token: token, query: query, limit: 6)
            searchSuggestions = dedupeSuggestions(searchSuggestions + more)
            generationLimitStore.increment()
            AnalyticsService.log("search_load_more_click", params: [:])
            if shouldOpenPaywallAfterFreeGenerations {
                showPremiumSheet = true
            }
        } catch {
            globalError = error.localizedDescription
        }
    }

    func saveDraft(seed: IdeaEditorSeed) {
        guard let ownerKey else { return }

        if let sourceDraftID = seed.sourceDraftID,
           let index = drafts.firstIndex(where: { $0.id == sourceDraftID }) {
            drafts[index].title = seed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            drafts[index].description = seed.description.trimmingCharacters(in: .whitespacesAndNewlines)
            drafts[index].investment = seed.investment
            drafts[index].currencyCode = CurrencySupport.normalize(seed.currencyCode)
        } else {
            drafts.insert(
                DraftIdea(
                    id: UUID().uuidString,
                    title: seed.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: seed.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    investment: seed.investment,
                    currencyCode: CurrencySupport.normalize(seed.currencyCode),
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    isFavorite: false
                ),
                at: 0
            )
        }

        draftStore.save(drafts, ownerKey: ownerKey)
        activeTab = .ideas
    }

    func deleteDraft(_ draft: DraftIdea) {
        guard let ownerKey else { return }
        drafts.removeAll { $0.id == draft.id }
        draftStore.save(drafts, ownerKey: ownerKey)
    }

    func toggleDraftFavorite(_ draft: DraftIdea) {
        guard let ownerKey, let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }
        drafts[index].isFavorite.toggle()
        draftStore.save(drafts, ownerKey: ownerKey)
    }

    func toggleIdeaFavorite(_ idea: Idea) {
        guard let ownerKey, let index = ideas.firstIndex(where: { $0.id == idea.id }) else { return }
        ideas[index].isFavorite.toggle()
        let favoriteIDs = Set(ideas.filter(\.isFavorite).map(\.id))
        favoriteStore.save(favoriteIDs, ownerKey: ownerKey)
    }

    func generateIdea(from seed: IdeaEditorSeed) async -> Idea? {
        guard let token, let ownerKey else { return nil }
        guard canGenerateForFree else {
            showPremiumSheet = true
            return nil
        }

        isGenerating = true
        globalError = nil
        defer { isGenerating = false }

        do {
            let favoriteIDs = favoriteStore.load(ownerKey: ownerKey)
            let generated: Idea
            if let sourceIdeaID = seed.sourceIdeaID {
                generated = try await api.updateIdea(
                    token: token,
                    id: sourceIdeaID,
                    title: seed.title,
                    description: seed.description,
                    investment: seed.investment,
                    currencyCode: seed.currencyCode,
                    favoriteIDs: favoriteIDs
                )
            } else {
                generated = try await api.createIdea(
                    token: token,
                    title: seed.title,
                    description: seed.description,
                    investment: seed.investment,
                    currencyCode: seed.currencyCode,
                    favoriteIDs: favoriteIDs
                )
            }

            replaceOrInsertIdea(generated)
            if let sourceDraftID = seed.sourceDraftID {
                drafts.removeAll { $0.id == sourceDraftID }
                draftStore.save(drafts, ownerKey: ownerKey)
            }
            generationLimitStore.increment()
            AnalyticsService.log("idea_generated", params: [:])
            handlePromptThresholds(afterGeneratedIdea: generated)
            activeTab = .ideas
            return generated
        } catch {
            globalError = error.localizedDescription
            return nil
        }
    }

    func deleteIdea(_ idea: Idea) async {
        guard let token else { return }
        do {
            try await api.deleteIdea(token: token, id: idea.id)
            ideas.removeAll { $0.id == idea.id }
        } catch {
            globalError = error.localizedDescription
        }
    }

    func fetchRelatedVideos(for idea: Idea) async {
        if relatedVideos[idea.id] != nil { return }
        do {
            relatedVideos[idea.id] = try await api.searchRelatedVideos(query: idea.title, limit: 8)
        } catch {
            relatedVideos[idea.id] = []
        }
    }

    func startRecovery() async {
        recovery.error = nil
        recovery.message = nil
        let email = recovery.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            recovery.error = "Enter the registered email."
            return
        }
        guard !recovery.birthDate.isEmpty else {
            recovery.error = "Select the birth date."
            return
        }

        do {
            let response = try await api.startRecovery(email: email, birthDate: recovery.birthDate)
            recovery.questionText = response.questionText
            recovery.step = .question
        } catch {
            recovery.error = error.localizedDescription
        }
    }

    func verifyRecovery() async {
        recovery.error = nil
        do {
            let message = try await api.verifyRecovery(
                email: recovery.email.trimmingCharacters(in: .whitespacesAndNewlines),
                birthDate: recovery.birthDate,
                answer: recovery.answer.normalizedSecurityAnswer()
            )
            recovery.message = message
            recovery.step = .reset
        } catch {
            recovery.error = error.localizedDescription
        }
    }

    func resetRecovery() async {
        recovery.error = nil
        guard !recovery.newPassword.isEmpty, !recovery.confirmPassword.isEmpty else {
            recovery.error = "Fill the new password fields."
            return
        }
        guard recovery.newPassword == recovery.confirmPassword else {
            recovery.error = "Passwords do not match."
            return
        }
        guard recovery.newPassword.count >= 6 else {
            recovery.error = "Password must have at least 6 characters."
            return
        }

        do {
            let message = try await api.resetRecovery(
                email: recovery.email.trimmingCharacters(in: .whitespacesAndNewlines),
                birthDate: recovery.birthDate,
                answer: recovery.answer.normalizedSecurityAnswer(),
                newPassword: recovery.newPassword
            )
            recovery.message = message
            recovery.step = .done
        } catch {
            recovery.error = error.localizedDescription
        }
    }

    func resetRecoveryFlow(prefilledEmail: String = "") {
        recovery = RecoveryContext()
        recovery.email = prefilledEmail
    }

    func updateLanguage(to option: LanguageOption) async {
        guard let token else { return }
        do {
            let updated = try await api.updateLanguage(token: token, languageCode: option.code)
            user = updated
            currentLanguageCode = updated.languageCode
        } catch {
            globalError = error.localizedDescription
        }
    }

    func syncNotificationPreferences(frequency: NotificationFrequency, mode: NotificationMode) async {
        guard let token, let ownerKey else { return }
        var updatedPreferences = notificationPreferences
        updatedPreferences.frequency = frequency
        updatedPreferences.mode = mode
        updatedPreferences.hasSeenPrompt = true
        notificationPreferences = updatedPreferences
        notificationStore.save(updatedPreferences, ownerKey: ownerKey)

        do {
            let granted = try await notificationScheduler.requestPermission()
            if !granted {
                globalError = "Notification permission was not granted."
                return
            }
        } catch {
            globalError = error.localizedDescription
            return
        }

        do {
            let pack: [NotificationIdeaItem]
            switch mode {
            case .random:
                pack = try await api.fetchNotificationRandomPack(token: token)
            case .interestBased:
                pack = try await api.fetchNotificationInterestPack(token: token, interests: ideas.map(\.title))
            }
            notificationStore.savePack(pack, ownerKey: ownerKey)
            notificationScheduler.sync(ownerKey: ownerKey, preferences: updatedPreferences, pack: pack)
        } catch {
            globalError = error.localizedDescription
        }
    }

    func dismissNotificationPrompt() {
        guard let ownerKey else {
            showNotificationPrompt = false
            return
        }
        notificationPreferences.hasSeenPrompt = true
        notificationStore.save(notificationPreferences, ownerKey: ownerKey)
        showNotificationPrompt = false
    }

    func handleNotificationTap(title: String, description: String) {
        notificationEditorSeed = IdeaEditorSeed(
            sourceDraftID: nil,
            sourceIdeaID: nil,
            title: title,
            description: description,
            investment: 0,
            currencyCode: CurrencySupport.detectFromDevice()
        )
        activeTab = .ideas
    }

    private func hydrateLocalStores() {
        guard let ownerKey else { return }
        drafts = draftStore.load(ownerKey: ownerKey)
        notificationPreferences = notificationStore.load(ownerKey: ownerKey)
    }

    private func replaceOrInsertIdea(_ idea: Idea) {
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index] = idea
        } else {
            ideas.insert(idea, at: 0)
        }
    }

    private func dedupeSuggestions(_ items: [IdeaSuggestion]) -> [IdeaSuggestion] {
        var seen: Set<String> = []
        return items.filter { item in
            seen.insert(item.id).inserted
        }
    }

    private var shouldOpenPaywallAfterFreeGenerations: Bool {
        !purchaseManager.isPremium && generationCountToday >= AppConfig.paywallTriggerAfterGenerations
    }

    private func handlePromptThresholds(afterGeneratedIdea generated: Idea) {
        guard let ownerKey else { return }
        let totalIdeas = ideas.count
        if totalIdeas >= AppConfig.reviewPromptAfterIdeaCount && !reviewPromptStore.hasPrompted(ownerKey: ownerKey) {
            reviewPromptStore.markPrompted(ownerKey: ownerKey)
            reviewRequestNonce += 1
        }

        if totalIdeas >= AppConfig.notificationPromptAfterIdeaCount && !notificationPreferences.hasSeenPrompt {
            showNotificationPrompt = true
        }
    }

    private func detectDefaultLanguageCode() -> String {
        let identifier = Locale.preferredLanguages.first?.lowercased() ?? "en-us"
        return identifier.replacingOccurrences(of: "-", with: "_")
    }
}
