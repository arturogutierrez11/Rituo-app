import Foundation

enum CoreAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case timedOut
    case networkUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del core-api no es valida."
        case .invalidResponse:
            return "La respuesta del core-api no es valida."
        case let .serverError(statusCode, message):
            return "core-api respondio \(statusCode): \(message)"
        case .timedOut:
            return "La request a core-api vencio."
        case let .networkUnavailable(message):
            return "No se pudo conectar con core-api: \(message)"
        }
    }
}

final class CoreApiService {
    static let shared = CoreApiService()

    private let baseURLString = "http://159.89.37.132"
    private let requestTimeout: TimeInterval = 12
    private let tokenStore = KeychainTokenStore.shared
    private var refreshedAccessToken: String?

    private init() {}

    func listRituals(accessToken: String) async throws -> [RitualResponse] {
        let request = try makeRequest(path: "/rituals", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([RitualResponse].self, from: data)
    }

    func getRitual(accessToken: String, ritualId: String) async throws -> RitualResponse {
        let request = try makeRequest(path: "/rituals/\(ritualId)", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualResponse.self, from: data)
    }

    func createRitual(accessToken: String, body: CreateRitualRequest) async throws -> RitualResponse {
        var request = try makeRequest(path: "/rituals", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualResponse.self, from: data)
    }


    func deleteRitual(
        accessToken: String,
        ritualId: String,
        password: String? = nil
    ) async throws {
        var request = try makeRequest(path: "/rituals/\(ritualId)", method: "DELETE", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeleteRitualRequest(password: password))
        _ = try await send(request)
    }


    func listRitualBlockedItems(accessToken: String, ritualId: String) async throws -> [RitualBlockedItemResponse] {
        let request = try makeRequest(path: "/rituals/\(ritualId)/blocked-items?platform=ios", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([RitualBlockedItemResponse].self, from: data)
    }

    func replaceRitualBlockedItems(
        accessToken: String,
        ritualId: String,
        body: ReplaceRitualBlockedItemsRequest
    ) async throws -> [RitualBlockedItemResponse] {
        var request = try makeRequest(path: "/rituals/\(ritualId)/blocked-items", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode([RitualBlockedItemResponse].self, from: data)
    }


    func startRitualSession(accessToken: String, body: StartRitualSessionRequest) async throws -> RitualSessionResponse {
        var request = try makeRequest(path: "/ritual-sessions/start", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func getActiveRitualSession(accessToken: String) async throws -> RitualSessionResponse? {
        let request = try makeRequest(path: "/ritual-sessions/active", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)

        if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
            return nil
        }

        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func getRitualSessionSummary(accessToken: String) async throws -> RitualSessionSummaryResponse {
        let request = try makeRequest(path: "/ritual-sessions/summary", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionSummaryResponse.self, from: data)
    }

    func listRitualSessionsByRitual(accessToken: String, ritualId: String) async throws -> [RitualSessionResponse] {
        let request = try makeRequest(path: "/ritual-sessions/ritual/\(ritualId)", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([RitualSessionResponse].self, from: data)
    }

    func recordRitualSession(accessToken: String, body: RecordRitualSessionRequest) async throws -> RitualSessionResponse {
        var request = try makeRequest(path: "/ritual-sessions/record", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func finishRitualSession(
        accessToken: String,
        sessionId: String,
        body: FinishRitualSessionRequest
    ) async throws -> RitualSessionResponse {
        var request = try makeRequest(path: "/ritual-sessions/\(sessionId)/finish", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func listNfcTagClaims(accessToken: String) async throws -> [NfcTagClaimResponse] {
        let request = try makeRequest(path: "/nfc-tags/me", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([NfcTagClaimResponse].self, from: data)
    }

    func claimNfcTag(accessToken: String, body: ClaimNfcTagRequest) async throws -> NfcTagClaimResponse {
        var request = try makeRequest(path: "/nfc-tags/claim", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(NfcTagClaimResponse.self, from: data)
    }

    func verifyNfcTag(accessToken: String, body: VerifyNfcTagRequest) async throws -> VerifyNfcTagResponse {
        var request = try makeRequest(path: "/nfc-tags/verify", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(VerifyNfcTagResponse.self, from: data)
    }

    func updateNfcTagClaim(
        accessToken: String,
        claimId: String,
        body: UpdateNfcTagClaimRequest
    ) async throws -> NfcTagClaimResponse {
        var request = try makeRequest(
            path: "/nfc-tags/\(claimId)",
            method: "PATCH",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(NfcTagClaimResponse.self, from: data)
    }

    func revokeNfcTagClaim(accessToken: String, claimId: String) async throws {
        let request = try makeRequest(
            path: "/nfc-tags/\(claimId)",
            method: "DELETE",
            accessToken: accessToken
        )
        _ = try await send(request)
    }

    private func makeRequest(path: String, method: String, accessToken: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURLString)\(path)") else {
            throw CoreAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(refreshedAccessToken ?? accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result = try await perform(request)

        if result.response.statusCode == 401,
           let retryRequest = try await refreshedRequest(from: request) {
            let retryResult = try await perform(retryRequest)

            guard 200 ..< 300 ~= retryResult.response.statusCode else {
                let message = String(data: retryResult.data, encoding: .utf8) ?? "Unknown error"
                throw CoreAPIError.serverError(retryResult.response.statusCode, message)
            }

            return (retryResult.data, retryResult.response)
        }

        guard 200 ..< 300 ~= result.response.statusCode else {
            let message = String(data: result.data, encoding: .utf8) ?? "Unknown error"
            throw CoreAPIError.serverError(result.response.statusCode, message)
        }

        return (result.data, result.response)
    }

    private func perform(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoreAPIError.invalidResponse
        }

        print("\(request.httpMethod ?? "GET") \(request.url?.path ?? "") status:", httpResponse.statusCode)
        return (data, httpResponse)
    }

    private func refreshedRequest(from request: URLRequest) async throws -> URLRequest? {
        guard let refreshToken = tokenStore.loadRefreshToken() else {
            return nil
        }

        let tokens = try await AuthAPIClient.shared.refreshTokens(refreshToken: refreshToken)
        try tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        refreshedAccessToken = tokens.accessToken

        var retryRequest = request
        retryRequest.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        print("core-api token refreshed; retrying \(request.url?.path ?? "request")")
        return retryRequest
    }

    private func mapNetworkError(_ error: Error) -> CoreAPIError {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return .timedOut
        }

        return .networkUnavailable(error.localizedDescription)
    }
}
