import Foundation

enum AuthAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case timedOut
    case networkUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del auth-api no es valida."
        case .invalidResponse:
            return "La respuesta del auth-api no es valida."
        case let .serverError(statusCode, message):
            return "auth-api respondio \(statusCode): \(message)"
        case .timedOut:
            return "La request a auth-api vencio. Revisa que el iPhone este en la misma Wi-Fi y que pueda abrir http://192.168.1.37:3001/health."
        case let .networkUnavailable(message):
            return "No se pudo conectar con auth-api: \(message)"
        }
    }
}

final class AuthAPIClient {
    static let shared = AuthAPIClient()

    private let baseURLString = "http://167.172.226.62"
    private let requestTimeout: TimeInterval = 12

    private init() {}

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        deviceId: String,
        deviceLabel: String,
        displayName: String?
    ) async throws -> AppleAuthResponse {
        guard let url = URL(string: "\(baseURLString)/auth/apple") else {
            throw AuthAPIError.invalidURL
        }

        let body = AppleAuthRequest(
            identityToken: identityToken,
            deviceId: deviceId,
            authorizationCode: authorizationCode,
            deviceLabel: deviceLabel,
            displayName: displayName
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthAPIError.serverError(httpResponse.statusCode, message)
        }

        return try JSONDecoder().decode(AppleAuthResponse.self, from: data)
    }

    func signInWithGoogle(
        identityToken: String,
        deviceId: String,
        deviceLabel: String
    ) async throws -> GoogleAuthResponse {
        guard let url = URL(string: "\(baseURLString)/auth/google") else {
            throw AuthAPIError.invalidURL
        }

        let body = GoogleAuthRequest(
            identityToken: identityToken,
            deviceId: deviceId,
            deviceLabel: deviceLabel
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse
        }

        print("POST /auth/google status:", httpResponse.statusCode)

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthAPIError.serverError(httpResponse.statusCode, message)
        }

        return try JSONDecoder().decode(GoogleAuthResponse.self, from: data)
    }

    func getCurrentUser(accessToken: String) async throws -> AuthUser {
        guard let url = URL(string: "\(baseURLString)/auth/me") else {
            throw AuthAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse
        }

        print("GET /auth/me status:", httpResponse.statusCode)

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthAPIError.serverError(httpResponse.statusCode, message)
        }

        return try JSONDecoder().decode(AuthUser.self, from: data)
    }


    func refreshTokens(refreshToken: String) async throws -> TokenResponse {
        guard let url = URL(string: "\(baseURLString)/auth/refresh") else {
            throw AuthAPIError.invalidURL
        }

        let body = RefreshTokenRequest(refreshToken: refreshToken)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    func logout(refreshToken: String) async throws {
        guard let url = URL(string: "\(baseURLString)/auth/logout") else {
            throw AuthAPIError.invalidURL
        }

        let body = RefreshTokenRequest(refreshToken: refreshToken)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await send(request, acceptsNoContent: true)
    }

    func healthCheck() async throws -> String {
        guard let url = URL(string: "\(baseURLString)/health") else {
            throw AuthAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw AuthAPIError.invalidResponse
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func send(_ request: URLRequest, acceptsNoContent: Bool = false) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse
        }

        if acceptsNoContent && httpResponse.statusCode == 204 {
            return (data, httpResponse)
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthAPIError.serverError(httpResponse.statusCode, message)
        }

        return (data, httpResponse)
    }

    private func mapNetworkError(_ error: Error) -> AuthAPIError {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return .timedOut
        }

        return .networkUnavailable(error.localizedDescription)
    }
}
