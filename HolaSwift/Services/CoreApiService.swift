import Foundation

enum CoreAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String, String?)
    case timedOut
    case networkUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del core-api no es valida."
        case .invalidResponse:
            return "La respuesta del core-api no es valida."
        case let .serverError(statusCode, message, code):
            switch code {
            case "ACTIVE_FOCUS_SESSION_EXISTS":
                return "Ya tenés una sesión de foco activa."
            case "NFC_TAG_REQUIRED":
                return "Necesitás vincular un tag NFC para continuar."
            case "INVALID_NFC_TAG":
                return "El tag NFC no pertenece a esta cuenta."
            case "NFC_TAG_IN_USE":
                return "No podés desvincular el tag mientras haya una sesión activa."
            case "NFC_TAG_ALREADY_CLAIMED":
                return "Este tag NFC ya está vinculado a otra cuenta."
            case "NFC_TAG_LOST":
                return "Este tag fue marcado como perdido y ya no puede volver a utilizarse."
            case "NFC_REQUIRED_TO_FINISH":
                return "Esta sesión solo puede finalizarse con el tag NFC."
            case "ACTIVE_FOCUS_SESSION_REQUIRED":
                return "No hay una sesión activa para desbloquear."
            case "EMERGENCY_UNLOCK_COOLDOWN":
                return message
            case "IDEMPOTENCY_KEY_REUSED":
                return "Esta operación ya fue utilizada para otra solicitud. Volvé a intentarlo."
            case "MODE_BLOCKED_ITEMS_REQUIRED", "RITUAL_BLOCKED_ITEMS_REQUIRED":
                return "Primero seleccioná las apps que querés bloquear."
            case "MODE_NOT_ACTIVE", "RITUAL_NOT_ACTIVE":
                return "Esta configuración ya no está activa."
            default:
                return "core-api respondió \(statusCode): \(message)"
            }
        case .timedOut:
            return "La request a core-api vencio."
        case let .networkUnavailable(message):
            return "No se pudo conectar con core-api: \(message)"
        }
    }
}

private struct CoreAPIErrorResponse: Decodable {
    let code: String?
    let message: String?
    let nextAvailableAt: String?
}

final class CoreApiService {
    static let shared = CoreApiService()

    private let baseURLString = AppEnvironment.coreAPIBaseURL
    private let requestTimeout: TimeInterval = 12
    private let tokenStore = KeychainTokenStore.shared
    private var refreshedAccessToken: String?

    private init() {}

    func getAppUpdateStatus() async throws -> AppUpdateStatusResponse {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        guard var components = URLComponents(
            string: "\(baseURLString)/app-updates/status"
        ) else {
            throw CoreAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "build", value: build),
            URLQueryItem(name: "version", value: version)
        ]
        guard let url = components.url else {
            throw CoreAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(AppUpdateStatusResponse.self, from: data)
    }

    func getPendingSupportReset(accessToken: String) async throws -> SupportResetResponse? {
        let request = try makeRequest(
            path: "/support-resets/pending",
            method: "GET",
            accessToken: accessToken
        )
        let (data, _) = try await send(request)
        if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
            return nil
        }
        return try JSONDecoder().decode(SupportResetResponse.self, from: data)
    }

    func acknowledgeSupportReset(
        accessToken: String,
        requestId: String
    ) async throws {
        var request = try makeRequest(
            path: "/support-resets/\(requestId)/acknowledge",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AcknowledgeSupportResetRequest(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            )
        )
        _ = try await send(request)
    }

    func getLegalRequirements(accessToken: String) async throws -> LegalRequirementsResponse {
        let request = try makeRequest(
            path: "/legal/requirements",
            method: "GET",
            accessToken: accessToken
        )
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(LegalRequirementsResponse.self, from: data)
    }

    func acceptLegalDocuments(
        accessToken: String,
        body: AcceptLegalDocumentsRequest
    ) async throws -> LegalRequirementsResponse {
        var request = try makeRequest(
            path: "/legal/acceptances",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(LegalRequirementsResponse.self, from: data)
    }

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

    func createRitual(
        accessToken: String,
        body: CreateRitualRequest,
        idempotencyKey: String? = nil
    ) async throws -> RitualResponse {
        var request = try makeRequest(path: "/rituals", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualResponse.self, from: data)
    }


    func deleteRitual(
        accessToken: String,
        ritualId: String,
        password: String? = nil,
        idempotencyKey: String? = nil
    ) async throws {
        var request = try makeRequest(path: "/rituals/\(ritualId)", method: "DELETE", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
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
        body: ReplaceRitualBlockedItemsRequest,
        idempotencyKey: String? = nil
    ) async throws -> [RitualBlockedItemResponse] {
        var request = try makeRequest(path: "/rituals/\(ritualId)/blocked-items", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode([RitualBlockedItemResponse].self, from: data)
    }

    func listModes(accessToken: String) async throws -> [ModeResponse] {
        let request = try makeRequest(path: "/modes", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([ModeResponse].self, from: data)
    }

    func updateMode(
        accessToken: String,
        modeId: String,
        body: UpdateModeRequest,
        idempotencyKey: String? = nil
    ) async throws -> ModeResponse {
        var request = try makeRequest(path: "/modes/\(modeId)", method: "PATCH", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ModeResponse.self, from: data)
    }

    func renameMode(
        accessToken: String,
        modeId: String,
        body: RenameModeRequest,
        idempotencyKey: String? = nil
    ) async throws -> ModeResponse {
        var request = try makeRequest(path: "/modes/\(modeId)/name", method: "PATCH", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ModeResponse.self, from: data)
    }

    func listModeBlockedItems(accessToken: String, modeId: String) async throws -> [ModeBlockedItemResponse] {
        let request = try makeRequest(path: "/modes/\(modeId)/blocked-items?platform=ios", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([ModeBlockedItemResponse].self, from: data)
    }

    func replaceModeBlockedItems(
        accessToken: String,
        modeId: String,
        body: ReplaceModeBlockedItemsRequest,
        idempotencyKey: String? = nil
    ) async throws -> [ModeBlockedItemResponse] {
        var request = try makeRequest(path: "/modes/\(modeId)/blocked-items", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode([ModeBlockedItemResponse].self, from: data)
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

    func recordRitualSession(
        accessToken: String,
        body: RecordRitualSessionRequest,
        idempotencyKey: String? = nil
    ) async throws -> RitualSessionResponse {
        var request = try makeRequest(path: "/ritual-sessions/record", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func finishRitualSession(
        accessToken: String,
        sessionId: String,
        body: FinishRitualSessionRequest,
        idempotencyKey: String? = nil
    ) async throws -> RitualSessionResponse {
        var request = try makeRequest(path: "/ritual-sessions/\(sessionId)/finish", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(RitualSessionResponse.self, from: data)
    }

    func startModeSession(accessToken: String, body: StartModeSessionRequest) async throws -> ModeSessionResponse {
        var request = try makeRequest(path: "/mode-sessions/start", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ModeSessionResponse.self, from: data)
    }

    func getActiveModeSession(accessToken: String) async throws -> ModeSessionResponse? {
        let request = try makeRequest(path: "/mode-sessions/active", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)

        if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
            return nil
        }

        return try JSONDecoder().decode(ModeSessionResponse.self, from: data)
    }

    func getActiveFocusSession(accessToken: String) async throws -> ActiveFocusSessionResponse? {
        let request = try makeRequest(path: "/focus-sessions/active", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)

        if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
            return nil
        }

        return try JSONDecoder().decode(ActiveFocusSessionResponse.self, from: data)
    }

    func getEmergencyUnlockStatus(accessToken: String) async throws -> EmergencyUnlockStatusResponse {
        let request = try makeRequest(
            path: "/focus-sessions/emergency-unlock",
            method: "GET",
            accessToken: accessToken
        )
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(EmergencyUnlockStatusResponse.self, from: data)
    }

    func useEmergencyUnlock(
        accessToken: String,
        reason: EmergencyUnlockReason
    ) async throws -> EmergencyUnlockResponse {
        var request = try makeRequest(
            path: "/focus-sessions/emergency-unlock",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            UseEmergencyUnlockRequest(reason: reason)
        )

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(EmergencyUnlockResponse.self, from: data)
    }

    func getModeSessionSummary(accessToken: String) async throws -> ModeSessionSummaryResponse {
        let request = try makeRequest(path: "/mode-sessions/summary", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ModeSessionSummaryResponse.self, from: data)
    }

    func getFocusMetricsSummary(accessToken: String) async throws -> FocusMetricsSummaryResponse {
        let request = try makeRequest(path: "/focus-metrics/summary", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(FocusMetricsSummaryResponse.self, from: data)
    }

    func listModeSessionsByMode(accessToken: String, modeId: String) async throws -> [ModeSessionResponse] {
        let request = try makeRequest(path: "/mode-sessions/mode/\(modeId)", method: "GET", accessToken: accessToken)
        let (data, _) = try await send(request)
        return try JSONDecoder().decode([ModeSessionResponse].self, from: data)
    }

    func finishModeSession(
        accessToken: String,
        sessionId: String,
        body: FinishModeSessionRequest,
        idempotencyKey: String? = nil
    ) async throws -> ModeSessionResponse {
        var request = try makeRequest(path: "/mode-sessions/\(sessionId)/finish", method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ModeSessionResponse.self, from: data)
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

    func prepareReviewDemoTag(accessToken: String) async throws -> ReviewDemoTagResponse {
        let request = try makeRequest(
            path: "/nfc-tags/review-demo/prepare",
            method: "POST",
            accessToken: accessToken
        )
        let (data, _) = try await send(request)
        return try JSONDecoder().decode(ReviewDemoTagResponse.self, from: data)
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
                throw makeServerError(
                    statusCode: retryResult.response.statusCode,
                    data: retryResult.data
                )
            }

            return (retryResult.data, retryResult.response)
        }

        guard 200 ..< 300 ~= result.response.statusCode else {
            throw makeServerError(
                statusCode: result.response.statusCode,
                data: result.data
            )
        }

        return (result.data, result.response)
    }

    private func makeServerError(statusCode: Int, data: Data) -> CoreAPIError {
        let payload = try? JSONDecoder().decode(CoreAPIErrorResponse.self, from: data)
        let fallbackMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        let message: String
        if payload?.code == "EMERGENCY_UNLOCK_COOLDOWN",
           let rawDate = payload?.nextAvailableAt,
           let date = ISO8601DateFormatter().date(from: rawDate) {
            message = "El desbloqueo de emergencia vuelve a estar disponible el \(date.formatted(date: .long, time: .omitted))."
        } else {
            message = payload?.message ?? fallbackMessage
        }
        return .serverError(
            statusCode,
            message,
            payload?.code
        )
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
