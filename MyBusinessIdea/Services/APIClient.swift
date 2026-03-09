import Foundation

struct APIClient {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func register(
        name: String,
        email: String,
        password: String,
        languageCode: String,
        birthDate: String,
        securityQuestionId: String,
        securityAnswer: String
    ) async throws -> AuthSession {
        let response: AuthResponseDTO = try await request(
            path: "/auth/register",
            method: "POST",
            body: RegisterRequestDTO(
                name: name,
                email: email,
                password: password,
                languageCode: languageCode,
                birthDate: birthDate,
                securityQuestionId: securityQuestionId,
                securityAnswer: securityAnswer
            ),
            token: nil
        )
        return AuthSession(token: response.token, user: AppUser(dto: response.user))
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let response: AuthResponseDTO = try await request(
            path: "/auth/login",
            method: "POST",
            body: LoginRequestDTO(email: email, password: password),
            token: nil
        )
        return AuthSession(token: response.token, user: AppUser(dto: response.user))
    }

    func startRecovery(email: String, birthDate: String) async throws -> PasswordRecoveryQuestion {
        let response: PasswordRecoveryStartResponseDTO = try await request(
            path: "/auth/recovery/start",
            method: "POST",
            body: PasswordRecoveryStartRequestDTO(email: email, birthDate: birthDate),
            token: nil
        )
        return PasswordRecoveryQuestion(questionID: response.questionId, questionText: response.questionText)
    }

    func verifyRecovery(email: String, birthDate: String, answer: String) async throws -> String {
        let response: MessageResponseDTO = try await request(
            path: "/auth/recovery/verify",
            method: "POST",
            body: PasswordRecoveryVerifyRequestDTO(email: email, birthDate: birthDate, answer: answer),
            token: nil
        )
        return response.message
    }

    func resetRecovery(email: String, birthDate: String, answer: String, newPassword: String) async throws -> String {
        let response: MessageResponseDTO = try await request(
            path: "/auth/recovery/reset",
            method: "POST",
            body: PasswordRecoveryResetRequestDTO(
                email: email,
                birthDate: birthDate,
                answer: answer,
                newPassword: newPassword
            ),
            token: nil
        )
        return response.message
    }

    func fetchMe(token: String) async throws -> AppUser {
        let response: UserDTO = try await request(path: "/auth/me", method: "GET", body: Optional<Int>.none, token: token)
        return AppUser(dto: response)
    }

    func updateLanguage(token: String, languageCode: String) async throws -> AppUser {
        let response: UserDTO = try await request(
            path: "/auth/me/language",
            method: "PATCH",
            body: UpdateLanguageRequestDTO(languageCode: languageCode),
            token: token
        )
        return AppUser(dto: response)
    }

    func fetchIdeas(token: String, favoriteIDs: Set<Int>) async throws -> [Idea] {
        let response: [IdeaDTO] = try await request(path: "/ideas", method: "GET", body: Optional<Int>.none, token: token)
        return response.map { Idea(dto: $0, isFavorite: favoriteIDs.contains($0.id)) }
    }

    func createIdea(token: String, title: String, description: String, investment: Int, currencyCode: String, favoriteIDs: Set<Int>) async throws -> Idea {
        let response: IdeaDTO = try await request(
            path: "/ideas",
            method: "POST",
            body: IdeaMutationRequestDTO(
                title: title,
                description: description,
                investment: investment,
                currencyCode: currencyCode,
                regeneratePlan: nil
            ),
            token: token
        )
        return Idea(dto: response, isFavorite: favoriteIDs.contains(response.id))
    }

    func updateIdea(token: String, id: Int, title: String, description: String, investment: Int, currencyCode: String, favoriteIDs: Set<Int>) async throws -> Idea {
        let response: IdeaDTO = try await request(
            path: "/ideas/\(id)",
            method: "PUT",
            body: IdeaMutationRequestDTO(
                title: title,
                description: description,
                investment: investment,
                currencyCode: currencyCode,
                regeneratePlan: true
            ),
            token: token
        )
        return Idea(dto: response, isFavorite: favoriteIDs.contains(response.id))
    }

    func deleteIdea(token: String, id: Int) async throws {
        _ = try await rawRequest(path: "/ideas/\(id)", method: "DELETE", body: nil, token: token)
    }

    func searchIdeas(token: String, query: String, limit: Int = 6) async throws -> [IdeaSuggestion] {
        let response: IdeaSearchResponseDTO = try await request(
            path: "/ideas/search",
            method: "POST",
            body: IdeaSearchRequestDTO(query: query, limit: limit),
            token: token
        )
        return response.items.map { IdeaSuggestion(title: $0.title, description: $0.description) }
    }

    func discoverIdeas(token: String, limit: Int = 7) async throws -> [IdeaSuggestion] {
        let response: IdeaSearchResponseDTO = try await request(
            path: "/ideas/discover?limit=\(max(3, min(limit, 12)))",
            method: "GET",
            body: Optional<Int>.none,
            token: token
        )
        return response.items.map { IdeaSuggestion(title: $0.title, description: $0.description) }
    }

    func fetchNotificationRandomPack(token: String, limit: Int = 7) async throws -> [NotificationIdeaItem] {
        do {
            let response: IdeaSearchResponseDTO = try await request(
                path: "/ideas/discover/notifications?limit=\(max(4, min(limit, 12)))",
                method: "GET",
                body: Optional<Int>.none,
                token: token
            )
            return response.items.map { NotificationIdeaItem(title: $0.title, description: $0.description) }
        } catch {
            return try await discoverIdeas(token: token, limit: limit).map {
                NotificationIdeaItem(title: $0.title, description: $0.description)
            }
        }
    }

    func fetchNotificationInterestPack(token: String, interests: [String], limit: Int = 7) async throws -> [NotificationIdeaItem] {
        let cleanInterests = interests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanInterests.isEmpty else {
            return try await fetchNotificationRandomPack(token: token, limit: limit)
        }

        do {
            let response: IdeaSearchResponseDTO = try await request(
                path: "/ideas/discover/interests",
                method: "POST",
                body: IdeaInterestPackRequestDTO(interests: cleanInterests, limit: limit),
                token: token
            )
            return response.items.map { NotificationIdeaItem(title: $0.title, description: $0.description) }
        } catch {
            return try await searchIdeas(
                token: token,
                query: "Create different and more creative business ideas inspired by \(cleanInterests[0])",
                limit: limit
            ).map {
                NotificationIdeaItem(title: $0.title, description: $0.description)
            }
        }
    }

    func searchRelatedVideos(query: String, limit: Int = 8) async throws -> [RelatedVideo] {
        let safeQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeQuery.isEmpty else { return [] }

        guard var components = URLComponents(string: "https://www.youtube.com/results") else {
            return []
        }
        components.queryItems = [URLQueryItem(name: "search_query", value: safeQuery)]
        guard let url = components.url else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AppError.api("Error communicating with YouTube.")
        }
        let html = String(data: data, encoding: .utf8) ?? ""
        return YouTubeParser.parseResults(html: html, limit: max(3, min(limit, 12)))
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        token: String?
    ) async throws -> Response {
        let result = try await rawRequest(path: path, method: method, body: body, token: token)
        guard !result.data.isEmpty else {
            throw AppError.invalidResponse
        }
        return try decoder.decode(Response.self, from: result.data)
    }

    private func rawRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        token: String?
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        guard let url = URL(string: path.hasPrefix("/") ? String(path.dropFirst()) : path, relativeTo: AppConfig.apiBaseURL) else {
            throw AppError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 70
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }
            guard 200..<300 ~= http.statusCode else {
                if let apiError = try? decoder.decode(ErrorResponseDTO.self, from: data) {
                    throw AppError.api(apiError.error)
                }
                throw AppError.api("Server returned status \(http.statusCode).")
            }
            return (data, http)
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw AppError.timeout
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                throw AppError.networkUnavailable
            case .cancelled:
                throw AppError.cancelled
            default:
                throw AppError.message(error.localizedDescription)
            }
        } catch {
            throw AppError.message(error.localizedDescription)
        }
    }
}

private struct AuthResponseDTO: Decodable {
    let token: String
    let user: UserDTO
}

private struct UserDTO: Codable {
    let id: Int
    let name: String
    let email: String
    let languageCode: String
    let createdAt: String?
}

private struct IdeaDTO: Codable {
    let id: Int
    let title: String
    let description: String
    let investment: Int
    let currencyCode: String
    let actionPlan: String
    let createdAt: String
    let updatedAt: String?
}

private struct ErrorResponseDTO: Decodable {
    let error: String
}

private struct MessageResponseDTO: Decodable {
    let message: String
}

private struct RegisterRequestDTO: Encodable {
    let name: String
    let email: String
    let password: String
    let languageCode: String
    let birthDate: String
    let securityQuestionId: String
    let securityAnswer: String
}

private struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

private struct UpdateLanguageRequestDTO: Encodable {
    let languageCode: String
}

private struct PasswordRecoveryStartRequestDTO: Encodable {
    let email: String
    let birthDate: String
}

private struct PasswordRecoveryStartResponseDTO: Decodable {
    let questionId: String
    let questionText: String
}

private struct PasswordRecoveryVerifyRequestDTO: Encodable {
    let email: String
    let birthDate: String
    let answer: String
}

private struct PasswordRecoveryResetRequestDTO: Encodable {
    let email: String
    let birthDate: String
    let answer: String
    let newPassword: String
}

private struct IdeaMutationRequestDTO: Encodable {
    let title: String
    let description: String
    let investment: Int
    let currencyCode: String
    let regeneratePlan: Bool?
}

private struct IdeaSearchRequestDTO: Encodable {
    let query: String
    let limit: Int?
}

private struct IdeaInterestPackRequestDTO: Encodable {
    let interests: [String]
    let limit: Int?
}

private struct IdeaSearchResponseDTO: Decodable {
    let items: [IdeaSuggestionDTO]
}

private struct IdeaSuggestionDTO: Decodable {
    let title: String
    let description: String
}

private extension AppUser {
    init(dto: UserDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            email: dto.email,
            languageCode: dto.languageCode,
            createdAt: dto.createdAt
        )
    }
}

private extension Idea {
    init(dto: IdeaDTO, isFavorite: Bool) {
        self.init(
            id: dto.id,
            title: dto.title,
            description: dto.description,
            investment: dto.investment,
            currencyCode: dto.currencyCode,
            actionPlan: dto.actionPlan,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            isFavorite: isFavorite
        )
    }
}
