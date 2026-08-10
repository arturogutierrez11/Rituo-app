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
            return "No pudimos iniciar sesión. Intentá nuevamente."
        case .invalidResponse:
            return "No pudimos procesar la respuesta. Intentá nuevamente."
        case .serverError:
            return "No pudimos completar la solicitud. Intentá nuevamente."
        case .timedOut:
            return "La conexión tardó demasiado. Intentá nuevamente."
        case .networkUnavailable:
            return "Sin conexión. Revisá tu internet e intentá nuevamente."
        }
    }

    var isSessionRevoked: Bool {
        guard case let .serverError(statusCode, message) = self else {
            return false
        }

        return statusCode == 401 &&
            message.localizedCaseInsensitiveContains("session")
    }

    var isConnectivityProblem: Bool {
        switch self {
        case .timedOut, .networkUnavailable:
            return true
        default:
            return false
        }
    }

    func containsServerMessage(_ expectedMessage: String) -> Bool {
        guard case let .serverError(_, message) = self else {
            return false
        }

        return message.localizedCaseInsensitiveContains(expectedMessage)
    }
}

final class AuthAPIClient {
    static let shared = AuthAPIClient()

    private let baseURLString = AppEnvironment.authAPIBaseURL
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
            throw serverError(statusCode: httpResponse.statusCode, data: data)
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
            throw serverError(statusCode: httpResponse.statusCode, data: data)
        }

        return try JSONDecoder().decode(GoogleAuthResponse.self, from: data)
    }

    func registerWithEmail(
        email: String,
        firstName: String,
        lastName: String,
        dateOfBirth: String,
        password: String,
        passwordConfirmation: String,
        deviceId: String,
        deviceLabel: String
    ) async throws -> EmailRegisterResponse {
        guard let url = URL(string: "\(baseURLString)/auth/email/register") else {
            throw AuthAPIError.invalidURL
        }

        let body = EmailRegisterRequest(
            email: email,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            password: password,
            passwordConfirmation: passwordConfirmation,
            deviceId: deviceId,
            deviceLabel: deviceLabel
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(EmailRegisterResponse.self, from: data)
    }

    func signInWithEmail(
        email: String,
        password: String,
        deviceId: String,
        deviceLabel: String
    ) async throws -> EmailAuthResponse {
        guard let url = URL(string: "\(baseURLString)/auth/email/login") else {
            throw AuthAPIError.invalidURL
        }

        let body = EmailLoginRequest(
            email: email,
            password: password,
            deviceId: deviceId,
            deviceLabel: deviceLabel
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await send(request)
        return try JSONDecoder().decode(EmailAuthResponse.self, from: data)
    }

    func forgotPassword(email: String) async throws {
        guard let url = URL(string: "\(baseURLString)/auth/email/forgot-password") else {
            throw AuthAPIError.invalidURL
        }

        let body = ForgotPasswordRequest(email: email)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await send(request)
    }

    func resendEmailVerification(email: String) async throws {
        guard let url = URL(string: "\(baseURLString)/auth/email/resend-verification") else {
            throw AuthAPIError.invalidURL
        }

        let body = ResendEmailVerificationRequest(email: email)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        _ = try await send(request)
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
            throw serverError(statusCode: httpResponse.statusCode, data: data)
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

    func deleteAccount(accessToken: String) async throws {
        guard let url = URL(string: "\(baseURLString)/auth/account") else {
            throw AuthAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = requestTimeout
        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("rituo-ios", forHTTPHeaderField: "User-Agent")

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
            throw serverError(statusCode: httpResponse.statusCode, data: data)
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

    private func serverError(statusCode: Int, data: Data) -> AuthAPIError {
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        return .serverError(statusCode, message)
    }
}
