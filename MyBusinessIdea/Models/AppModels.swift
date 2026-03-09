import Foundation

enum AppTab: Hashable {
    case home
    case ideas
    case favorites
    case account
}

enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String { rawValue }
}

enum RecoveryStep {
    case identify
    case question
    case reset
    case done
}

enum NotificationFrequency: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case every3Days
    case weekly

    var id: String { rawValue }

    var intervalDays: Int {
        switch self {
        case .none: return 0
        case .daily: return 1
        case .every3Days: return 3
        case .weekly: return 7
        }
    }

    var title: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .every3Days: return "Every 3 days"
        case .weekly: return "Weekly"
        }
    }
}

enum NotificationMode: String, CaseIterable, Identifiable, Codable {
    case random
    case interestBased

    var id: String { rawValue }

    var title: String {
        switch self {
        case .random: return "Random ideas"
        case .interestBased: return "Ideas based on my interests"
        }
    }
}

struct AppUser: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let languageCode: String
    let createdAt: String?
}

struct Idea: Codable, Equatable, Identifiable {
    let id: Int
    var title: String
    var description: String
    var investment: Int
    var currencyCode: String
    var actionPlan: String
    var createdAt: String
    var updatedAt: String?
    var isFavorite: Bool
}

struct DraftIdea: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var description: String
    var investment: Int
    var currencyCode: String
    var createdAt: String
    var isFavorite: Bool
}

struct IdeaSuggestion: Codable, Equatable, Identifiable {
    let title: String
    let description: String

    var id: String {
        let suffix = String(description.prefix(32))
        return "\(title)|\(suffix)"
    }
}

struct RelatedVideo: Equatable, Identifiable {
    let videoId: String
    let title: String
    let url: URL

    var id: String { videoId }
}

struct NotificationIdeaItem: Codable, Equatable, Identifiable {
    let title: String
    let description: String

    var id: String {
        let suffix = String(description.prefix(32))
        return "\(title)|\(suffix)"
    }
}

struct NotificationPreferences: Codable, Equatable {
    var frequency: NotificationFrequency = .none
    var mode: NotificationMode = .random
    var hasSeenPrompt: Bool = false
}

struct SecurityQuestion: Identifiable, Equatable {
    let id: String
    let title: String

    static let all: [SecurityQuestion] = [
        SecurityQuestion(id: "pet_name", title: "What was the name of your first pet?"),
        SecurityQuestion(id: "birth_city", title: "In which city were you born?"),
        SecurityQuestion(id: "first_school", title: "What was the name of your first school?"),
        SecurityQuestion(id: "mother_last_name", title: "What is your mother's last name?"),
        SecurityQuestion(id: "first_job", title: "What was your first job?")
    ]
}

struct LanguageOption: Identifiable, Hashable {
    let code: String
    let title: String

    var id: String { code }

    static let supported: [LanguageOption] = [
        .init(code: "en_us", title: "English (US)"),
        .init(code: "pt_br", title: "Português (Brasil)"),
        .init(code: "es_es", title: "Español"),
        .init(code: "fr_fr", title: "Français"),
        .init(code: "de_de", title: "Deutsch"),
        .init(code: "it_it", title: "Italiano"),
        .init(code: "nl_nl", title: "Nederlands"),
        .init(code: "pl_pl", title: "Polski"),
        .init(code: "ru_ru", title: "Русский"),
        .init(code: "tr_tr", title: "Türkçe"),
        .init(code: "ar", title: "العربية"),
        .init(code: "hi_in", title: "हिन्दी"),
        .init(code: "ja_jp", title: "日本語"),
        .init(code: "ko_kr", title: "한국어"),
        .init(code: "zh_cn", title: "简体中文")
    ]
}

struct IdeaEditorSeed: Identifiable, Equatable {
    let id = UUID()
    var sourceDraftID: String?
    var sourceIdeaID: Int?
    var title: String
    var description: String
    var investment: Int
    var currencyCode: String
}

struct RecoveryContext {
    var step: RecoveryStep = .identify
    var email = ""
    var birthDate = ""
    var questionText: String?
    var answer = ""
    var newPassword = ""
    var confirmPassword = ""
    var message: String?
    var error: String?
}

struct AuthSession {
    let token: String
    let user: AppUser
}

struct PasswordRecoveryQuestion {
    let questionID: String
    let questionText: String
}

struct GeneratedPlanSections: Equatable {
    struct Section: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let lines: [String]
    }

    let sections: [Section]
}
