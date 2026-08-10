import Combine
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    private let tokenStore = KeychainTokenStore.shared
    private let networkMonitor = NetworkConnectivityMonitor()

    @Published var isLoading = false
    @Published var authUser: AuthUser?
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingVerificationEmail: String?
    @Published var profileDisplayName: String?
    @Published var profileImageURL: URL?
    @Published var authProvider: AuthProvider?
    @Published var isRestoringSession = true
    @Published var isUsingOfflineSession = false
    @Published var legalRequirements: LegalRequirementsResponse?
    @Published var isLoadingLegalRequirements = false
    @Published var hasCheckedLegalRequirements = false
    @Published var legalRequirementsError: String?
    @Published var isAcceptingLegalDocuments = false

    init() {
        networkMonitor.start { [weak self] in
            Task { @MainActor in
                guard let self, self.isUsingOfflineSession else { return }
                await self.restoreSession()
            }
        }

        Task {
            await restoreSession()
        }
    }

    var isAuthenticated: Bool {
        accessToken != nil && authUser != nil
    }

    var canEnterAuthenticatedApp: Bool {
        isAuthenticated &&
            hasCheckedLegalRequirements &&
            legalRequirements?.requiresAcceptance == false
    }

    var legalAccessTaskID: String {
        "\(accessToken ?? "signed-out"):\(canEnterAuthenticatedApp)"
    }

    func loadLegalRequirements() async {
        guard let accessToken, !accessToken.isEmpty else {
            resetLegalState()
            return
        }

        isLoadingLegalRequirements = true
        hasCheckedLegalRequirements = false
        legalRequirementsError = nil
        defer { isLoadingLegalRequirements = false }

        do {
            legalRequirements = try await CoreApiService.shared.getLegalRequirements(
                accessToken: accessToken
            )
            hasCheckedLegalRequirements = true
        } catch is CancellationError {
            return
        } catch {
            legalRequirementsError = "Necesitamos conexión para verificar los términos vigentes. Revisá internet y volvé a intentar."
            print("Legal requirements error:", error)
        }
    }

    func acceptLegalDocuments() async {
        guard let accessToken,
              let legalRequirements else {
            legalRequirementsError = "No pudimos identificar los documentos pendientes."
            return
        }

        isAcceptingLegalDocuments = true
        legalRequirementsError = nil
        defer { isAcceptingLegalDocuments = false }

        do {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            let appVersion = [version, build.map { "(\($0))" }]
                .compactMap { $0 }
                .joined(separator: " ")

            self.legalRequirements = try await CoreApiService.shared.acceptLegalDocuments(
                accessToken: accessToken,
                body: AcceptLegalDocumentsRequest(
                    documentIds: legalRequirements.documents.map(\.id),
                    platform: "ios",
                    appVersion: appVersion.isEmpty ? nil : appVersion,
                    locale: Locale.current.identifier
                )
            )
            hasCheckedLegalRequirements = true
        } catch {
            legalRequirementsError = error.localizedDescription
            print("Legal acceptance error:", error)
        }
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

    func deleteAccount() async -> Bool {
        guard let accessToken, !accessToken.isEmpty else {
            errorMessage = "No hay una sesión activa para eliminar."
            return false
        }

        let deletedProvider = authProvider
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            try await AuthAPIClient.shared.deleteAccount(
                accessToken: accessToken
            )

            if deletedProvider == .google {
                try? await GIDSignIn.sharedInstance.disconnect()
            }

            clearLocalSession()
            successMessage = deletedProvider == .apple
                ? "Cuenta eliminada. Para revocar también el acceso de Apple: Configuración > tu nombre > Inicio de sesión y seguridad > Iniciar sesión con Apple > Rituo."
                : "Cuenta eliminada definitivamente."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
        authUser = tokenStore.loadAuthUser()
        profileDisplayName = tokenStore.loadProfileDisplayName()
        profileImageURL = tokenStore.loadProfileImageURL()

        do {
            let user = try await AuthAPIClient.shared.getCurrentUser(accessToken: storedAccessToken)
            authUser = user
            isUsingOfflineSession = false
        } catch {
            if isConnectivityProblem(error) {
                restoreCachedSessionAfterConnectivityFailure(error)
                return
            }
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
            isUsingOfflineSession = false
            try? tokenStore.saveSession(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                user: user,
                provider: authProvider ?? .email,
                profileDisplayName: profileDisplayName,
                profileImageURL: profileImageURL
            )
        } catch {
            if isConnectivityProblem(error) {
                restoreCachedSessionAfterConnectivityFailure(error)
                return
            }

            clearLocalSession()
            if let authError = error as? AuthAPIError,
               authError.isSessionRevoked {
                errorMessage = "Tu cuenta se abrió en otro dispositivo. Volvé a iniciar sesión para continuar."
            }
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
        isUsingOfflineSession = false

        if profileDisplayName == nil || profileDisplayName?.isEmpty == true {
            profileDisplayName = user.displayName
        }

        do {
            try tokenStore.saveSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                user: user,
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
        isUsingOfflineSession = false
        resetLegalState()
    }

    private func resetLegalState() {
        legalRequirements = nil
        isLoadingLegalRequirements = false
        hasCheckedLegalRequirements = false
        legalRequirementsError = nil
        isAcceptingLegalDocuments = false
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
            isUsingOfflineSession = false
            successMessage = "GET /auth/me OK."

            print("Current user id:", user.id)
            print("Current user email:", user.email ?? "nil")
            print("Current user displayName:", user.displayName ?? "nil")
            print("Current user emailVerified:", user.emailVerified)
            print("Current user status:", user.status)
        } catch {
            handleAuthRequestError(error)
            print("GET /auth/me error:", error)
        }
    }

    private func handleAuthRequestError(_ error: Error) {
        if let authError = error as? AuthAPIError,
           authError.isSessionRevoked {
            clearLocalSession()
            errorMessage = "Tu cuenta se abrió en otro dispositivo. Volvé a iniciar sesión para continuar."
            return
        }

        errorMessage = error.localizedDescription
    }

    private func restoreCachedSessionAfterConnectivityFailure(_ error: Error) {
        guard authUser != nil else {
            errorMessage = "Sin conexión. Conectate a internet para validar tu sesión."
            return
        }

        isUsingOfflineSession = true
        errorMessage = nil
        successMessage = nil
        print("Using cached session while offline:", error)
    }

    private func isConnectivityProblem(_ error: Error) -> Bool {
        (error as? AuthAPIError)?.isConnectivityProblem == true
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

    func signInWithEmail(email: String, password: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password

        errorMessage = nil
        successMessage = nil
        pendingVerificationEmail = nil

        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            errorMessage = "Ingresa un email valido."
            return
        }

        guard cleanPassword.count >= 8 else {
            errorMessage = "La contraseña tiene que tener al menos 8 caracteres."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await AuthAPIClient.shared.signInWithEmail(
                email: cleanEmail,
                password: cleanPassword,
                deviceId: currentDeviceId(),
                deviceLabel: currentDeviceLabel()
            )

            profileDisplayName = response.user.displayName
            profileImageURL = nil
            persistSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user,
                provider: .email
            )
            successMessage = "Sesión iniciada."
            await getCurrentUser()
        } catch {
            handleEmailSignInError(error)
            print("Email login error:", error)
        }
    }

    private func handleEmailSignInError(_ error: Error) {
        guard let authError = error as? AuthAPIError else {
            errorMessage = error.localizedDescription
            return
        }

        if authError.containsServerMessage("Email account not found") {
            errorMessage = "No encontramos una cuenta con ese correo. Revisalo o creá una cuenta nueva."
            return
        }

        if authError.containsServerMessage("Email is not verified") {
            errorMessage = "Necesitás verificar tu email antes de entrar. Revisá tu correo y abrí el link de rituo."
            return
        }

        if authError.containsServerMessage("Invalid password") ||
            authError.containsServerMessage("Invalid email or password") {
            errorMessage = "La contraseña no coincide con ese correo."
            return
        }

        handleAuthRequestError(authError)
    }

    func registerWithEmail(
        email: String,
        firstName: String,
        lastName: String,
        dateOfBirth: Date?,
        password: String,
        passwordConfirmation: String
    ) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        successMessage = nil
        pendingVerificationEmail = nil

        guard !cleanFirstName.isEmpty else {
            errorMessage = "Ingresá tu nombre."
            return
        }

        guard !cleanLastName.isEmpty else {
            errorMessage = "Ingresá tu apellido."
            return
        }

        guard let dateOfBirth else {
            errorMessage = "Ingresá tu fecha de nacimiento."
            return
        }

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let normalizedDateOfBirth = calendar.startOfDay(for: dateOfBirth)

        guard normalizedDateOfBirth <= today else {
            errorMessage = "La fecha de nacimiento no puede ser futura."
            return
        }

        guard let sixteenthBirthday = calendar.date(
            byAdding: .year,
            value: 16,
            to: normalizedDateOfBirth
        ), sixteenthBirthday <= today else {
            errorMessage = "Tenés que tener al menos 16 años para crear una cuenta."
            return
        }

        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            errorMessage = "Ingresá un email válido."
            return
        }

        guard password.count >= 8 else {
            errorMessage = "La contraseña tiene que tener al menos 8 caracteres."
            return
        }

        guard password == passwordConfirmation else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await AuthAPIClient.shared.registerWithEmail(
                email: cleanEmail,
                firstName: cleanFirstName,
                lastName: cleanLastName,
                dateOfBirth: Self.apiDateFormatter.string(from: normalizedDateOfBirth),
                password: password,
                passwordConfirmation: passwordConfirmation,
                deviceId: currentDeviceId(),
                deviceLabel: currentDeviceLabel()
            )

            successMessage = response.emailVerificationRequired
                ? "Cuenta creada. Te enviamos un mail para verificarla. Después de abrir el link, iniciá sesión."
                : "Cuenta creada. Ya podés iniciar sesión."
            pendingVerificationEmail = response.emailVerificationRequired ? cleanEmail : nil
        } catch {
            if let authError = error as? AuthAPIError,
               authError.containsServerMessage("at least 16 years old") {
                errorMessage = "Tenés que tener al menos 16 años para crear una cuenta."
                return
            }

            handleAuthRequestError(error)
            print("Email register error:", error)
        }
    }

    func resendEmailVerification() async {
        guard let email = pendingVerificationEmail ?? authUser?.email else {
            errorMessage = "No encontramos el email de tu cuenta."
            return
        }

        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthAPIClient.shared.resendEmailVerification(email: email)
            successMessage = "Te enviamos un nuevo link de verificación."
        } catch {
            handleAuthRequestError(error)
            print("Resend email verification error:", error)
        }
    }

    func clearPendingEmailVerification() {
        pendingVerificationEmail = nil
        successMessage = nil
        errorMessage = nil
    }

    func forgotPassword(email: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        successMessage = nil
        pendingVerificationEmail = nil

        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            errorMessage = "Ingresá un email válido."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthAPIClient.shared.forgotPassword(email: cleanEmail)
            successMessage = "Si el email existe, te enviamos un link para recuperar tu contraseña."
        } catch {
            handleAuthRequestError(error)
            print("Forgot password error:", error)
        }
    }

    private func currentDeviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-device"
    }

    private func currentDeviceLabel() -> String {
        UIDevice.current.name
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
