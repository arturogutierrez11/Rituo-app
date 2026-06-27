import Combine
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    private let tokenStore = KeychainTokenStore.shared

    @Published var isLoading = false
    @Published var authUser: AuthUser?
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var profileDisplayName: String?
    @Published var profileImageURL: URL?
    @Published var authProvider: AuthProvider?
    @Published var isRestoringSession = true

    init() {
        Task {
            await restoreSession()
        }
    }

    var isAuthenticated: Bool {
        accessToken != nil && authUser != nil
    }

    func signOut() {
        let tokenToRevoke = refreshToken ?? tokenStore.loadRefreshToken()
        clearLocalSession()

        if let tokenToRevoke {
            Task {
                try? await AuthAPIClient.shared.logout(refreshToken: tokenToRevoke)
            }
        }
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        displayName: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        if let displayName, !displayName.isEmpty {
            profileDisplayName = displayName
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-device"
        let deviceLabel = UIDevice.current.name

        do {
            let response = try await AuthAPIClient.shared.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                deviceId: deviceId,
                deviceLabel: deviceLabel,
                displayName: displayName
            )

            persistSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user,
                provider: .apple
            )
            successMessage = "Login correcto con Apple."

            print("accessToken:", response.accessToken)
            print("refreshToken:", response.refreshToken)
            print("user:", response.user)

            await getCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
            print("Apple backend auth error:", error)
        }
    }

    func signInWithGoogle() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            errorMessage = "No se encontro rootViewController para Google Sign-In."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.isLoading = false
                    self.errorMessage = "Google sign-in fallo: \(error.localizedDescription)"
                    print("Google sign-in error:", error)
                    return
                }

                guard let result else {
                    self.isLoading = false
                    self.errorMessage = "Google no devolvio resultado de login."
                    return
                }

                self.profileDisplayName = result.user.profile?.name
                self.profileImageURL = result.user.profile?.imageURL(withDimension: 160)

                guard let idToken = result.user.idToken?.tokenString else {
                    self.isLoading = false
                    self.errorMessage = "Google no devolvio idToken."
                    return
                }

                await self.signInWithGoogleBackend(identityToken: idToken)
            }
        }
    }

    private func signInWithGoogleBackend(identityToken: String) async {
        defer { isLoading = false }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-device"
        let deviceLabel = UIDevice.current.name

        do {
            let response = try await AuthAPIClient.shared.signInWithGoogle(
                identityToken: identityToken,
                deviceId: deviceId,
                deviceLabel: deviceLabel
            )

            persistSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user,
                provider: .google
            )
            successMessage = "Login correcto con Google."

            print("accessToken:", response.accessToken)
            print("refreshToken:", response.refreshToken)
            print("user:", response.user)

            await getCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
            print("Google backend auth error:", error)
        }
    }

    func restoreSession() async {
        defer { isRestoringSession = false }

        guard let storedAccessToken = tokenStore.loadAccessToken(),
              let storedRefreshToken = tokenStore.loadRefreshToken() else {
            return
        }

        accessToken = storedAccessToken
        refreshToken = storedRefreshToken
        authProvider = tokenStore.loadAuthProvider()
        profileDisplayName = tokenStore.loadProfileDisplayName()
        profileImageURL = tokenStore.loadProfileImageURL()

        do {
            let user = try await AuthAPIClient.shared.getCurrentUser(accessToken: storedAccessToken)
            authUser = user
        } catch {
            await refreshSessionAndLoadUser(refreshToken: storedRefreshToken)
        }
    }

    private func refreshSessionAndLoadUser(refreshToken: String) async {
        do {
            let tokens = try await AuthAPIClient.shared.refreshTokens(refreshToken: refreshToken)
            accessToken = tokens.accessToken
            self.refreshToken = tokens.refreshToken
            try? tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)

            let user = try await AuthAPIClient.shared.getCurrentUser(accessToken: tokens.accessToken)
            authUser = user
        } catch {
            clearLocalSession()
            print("Session restore failed:", error)
        }
    }

    private func persistSession(
        accessToken: String,
        refreshToken: String,
        user: AuthUser,
        provider: AuthProvider
    ) {
        self.authUser = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.authProvider = provider

        if profileDisplayName == nil || profileDisplayName?.isEmpty == true {
            profileDisplayName = user.displayName
        }

        do {
            try tokenStore.saveSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                provider: provider,
                profileDisplayName: profileDisplayName,
                profileImageURL: profileImageURL
            )
        } catch {
            errorMessage = error.localizedDescription
            print("Keychain save error:", error)
        }
    }

    private func clearLocalSession() {
        GIDSignIn.sharedInstance.signOut()
        tokenStore.clear()
        authUser = nil
        accessToken = nil
        refreshToken = nil
        errorMessage = nil
        successMessage = nil
        profileDisplayName = nil
        profileImageURL = nil
        authProvider = nil
    }

    func getCurrentUser() async {
        guard let accessToken, !accessToken.isEmpty else {
            errorMessage = "No hay accessToken para llamar GET /auth/me."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let user = try await AuthAPIClient.shared.getCurrentUser(accessToken: accessToken)
            authUser = user
            successMessage = "GET /auth/me OK."

            print("Current user id:", user.id)
            print("Current user email:", user.email ?? "nil")
            print("Current user displayName:", user.displayName ?? "nil")
            print("Current user emailVerified:", user.emailVerified)
            print("Current user status:", user.status)
        } catch {
            errorMessage = error.localizedDescription
            print("GET /auth/me error:", error)
        }
    }

    func runHealthCheck() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let result = try await AuthAPIClient.shared.healthCheck()
            successMessage = "Health OK: \(result)"
            print(result)
        } catch {
            errorMessage = error.localizedDescription
            print("Health check error:", error)
        }
    }

    func showEmailLoginUnavailable() {
        errorMessage = "Login con mail todavia no esta disponible en auth-api. Swagger solo expone Apple y Google."
        successMessage = nil
    }

    func signInWithEmail(email: String, password: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        successMessage = nil

        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            errorMessage = "Ingresa un email valido."
            return
        }

        guard cleanPassword.count >= 6 else {
            errorMessage = "La password tiene que tener al menos 6 caracteres."
            return
        }

        errorMessage = "Login con mail/password todavia no esta disponible en auth-api."
    }
}
