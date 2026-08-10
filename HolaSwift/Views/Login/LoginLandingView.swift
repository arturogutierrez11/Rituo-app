import AuthenticationServices
import Combine
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

struct LoginLandingView: View {
    private enum PresentedSheet: String, Identifiable {
        case support

        var id: String { rawValue }
    }

    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var keyboard = LoginKeyboardObserver()
    @State private var showsLoginOptions = false
    @State private var sheetDragOffset: CGFloat = 0
    @State private var logoAppeared = false
    @State private var textAppeared = false
    @State private var buttonAppeared = false
    @State private var glows = false
    @State private var rotates = false
    @State private var presentedSheet: PresentedSheet?

    var body: some View {
        GeometryReader { proxy in
            let keyboardIsVisible = keyboard.height > 0
            let sheetHeight = keyboardIsVisible
                ? min(max(proxy.size.height * 0.76, 620), proxy.size.height - 28)
                : min(max(proxy.size.height * 0.68, 590), 720)
            let keyboardLift = keyboardIsVisible ? min(keyboard.height * 0.42, 170) : 0

            ZStack(alignment: .bottom) {
                RituoAnimatedBackground()

                // Glow central fuerte
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                RituoPalette.white.opacity(glows ? 0.38 : 0.18),
                                RituoPalette.lightBlue.opacity(glows ? 0.20 : 0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 50)
                    .scaleEffect(glows ? 1.10 : 0.90)
                    .offset(y: -proxy.size.height * 0.10)
                    .allowsHitTesting(false)

                // Arco giratorio decorativo
                Circle()
                    .trim(from: 0.0, to: 0.28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                RituoPalette.white.opacity(0.34),
                                RituoPalette.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: min(proxy.size.width * 0.84, 340))
                    .rotationEffect(.degrees(rotates ? 360 : 0))
                    .offset(y: -proxy.size.height * 0.10)
                    .opacity(logoAppeared ? 1 : 0)
                    .allowsHitTesting(false)

                Circle()
                    .trim(from: 0.55, to: 0.75)
                    .stroke(
                        RituoPalette.mistBlue.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .frame(width: min(proxy.size.width * 1.0, 410))
                    .rotationEffect(.degrees(rotates ? -360 : 0))
                    .offset(y: -proxy.size.height * 0.10)
                    .opacity(logoAppeared ? 1 : 0)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 32) {
                        // Logo con glow y anillo
                        ZStack {
                            Circle()
                                .stroke(RituoPalette.white.opacity(glows ? 0.22 : 0.10), lineWidth: 1)
                                .frame(width: min(proxy.size.width * 0.68, 280))
                                .scaleEffect(glows ? 1.03 : 0.97)

                            Image("RituoLogoWhite")
                                .resizable()
                                .scaledToFit()
                                .frame(width: min(proxy.size.width * 0.56, 260))
                                .shadow(color: RituoPalette.white.opacity(0.50), radius: 32, x: 0, y: 0)
                                .shadow(color: RituoPalette.white.opacity(0.20), radius: 60, x: 0, y: 0)
                        }
                        .opacity(logoAppeared ? 1 : 0)
                        .scaleEffect(logoAppeared ? 1 : 0.82)

                        Text("Tus hábitos construyen\nla persona en la que te conviertes.")
                            .font(.custom("Helvetica", size: 15).weight(.medium))
                            .foregroundStyle(RituoPalette.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 44)
                            .opacity(textAppeared ? 1 : 0)
                            .offset(y: textAppeared ? 0 : 18)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                showsLoginOptions = true
                                sheetDragOffset = 0
                            }
                        } label: {
                            Text("Comenzar")
                                .font(.custom("Helvetica", size: 18).weight(.bold))
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(RituoPalette.white)
                                .clipShape(Capsule())
                                .shadow(color: RituoPalette.white.opacity(0.45), radius: 24, x: 0, y: 8)
                                .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
                        }
                        .buttonStyle(LoginPressButtonStyle())

                        Button {
                            presentedSheet = .support
                        } label: {
                            Label("¿Necesitás ayuda? Soporte", systemImage: "questionmark.circle")
                                .font(.custom("Helvetica", size: 13).weight(.semibold))
                                .foregroundStyle(RituoPalette.white.opacity(0.72))
                                .frame(minHeight: 34)
                        }
                        .buttonStyle(LoginPressButtonStyle())
                        .accessibilityHint("Abre los canales de contacto de rituo")
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 44)
                    .opacity(showsLoginOptions ? 0 : (buttonAppeared ? 1 : 0))
                    .offset(y: buttonAppeared ? 0 : 24)
                    .allowsHitTesting(!showsLoginOptions)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, showsLoginOptions ? sheetHeight : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.70, dampingFraction: 0.78).delay(0.15)) {
                        logoAppeared = true
                    }
                    withAnimation(.easeOut(duration: 0.60).delay(0.55)) {
                        textAppeared = true
                    }
                    withAnimation(.easeOut(duration: 0.50).delay(0.85)) {
                        buttonAppeared = true
                    }
                    withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.3)) {
                        glows = true
                    }
                    withAnimation(.linear(duration: 18).repeatForever(autoreverses: false).delay(0.5)) {
                        rotates = true
                    }
                }

                if showsLoginOptions {
                    LoginBottomSheet(
                        authViewModel: authViewModel
                    )
                    .frame(height: sheetHeight)
                    .offset(y: sheetDragOffset - keyboardLift)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                sheetDragOffset = max(-14, value.translation.height)
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    if value.translation.height > 105 || value.predictedEndTranslation.height > 175 {
                                        showsLoginOptions = false
                                    }

                                    sheetDragOffset = 0
                                }
                            }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.34, dampingFraction: 0.88), value: keyboardIsVisible)
                }
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .support:
                LoginSupportView()
            }
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authViewModel.errorMessage = "No se pudo leer la credencial de Apple."
                return
            }

            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                authViewModel.errorMessage = "Apple no devolvio identityToken."
                return
            }

            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }

            let displayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())

            Task {
                await authViewModel.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            }

        case let .failure(error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }

            authViewModel.errorMessage = "Inicio de sesión con Apple falló. Volvé a intentar."
        }
    }

}

struct LoginBottomSheet: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedMode: LoginMode = .signIn

    private var isWaitingForEmailVerification: Bool {
        authViewModel.pendingVerificationEmail != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(RituoPalette.white.opacity(0.16))
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            Text(isWaitingForEmailVerification ? "Revisá tu email" : "Entrá a rituo")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(RituoPalette.white)
                .padding(.top, 28)

            Text(isWaitingForEmailVerification ? "Falta confirmar que ese correo es tuyo." : "Usá tu email y contraseña para continuar.")
                .font(.system(size: 14))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
                .padding(.top, 6)

            if selectedMode != .forgotPassword && !isWaitingForEmailVerification {
                LoginModeSelector(selectedMode: $selectedMode)
                    .padding(.top, 22)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let pendingEmail = authViewModel.pendingVerificationEmail {
                        EmailVerificationPendingView(
                            email: pendingEmail,
                            isLoading: authViewModel.isLoading,
                            resend: {
                                Task {
                                    await authViewModel.resendEmailVerification()
                                }
                            },
                            goToSignIn: {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                    authViewModel.clearPendingEmailVerification()
                                    selectedMode = .signIn
                                }
                            }
                        )
                    } else if selectedMode == .signIn {
                        EmailSignInForm(
                            isLoading: authViewModel.isLoading,
                            forgotPassword: {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                    authViewModel.errorMessage = nil
                                    authViewModel.successMessage = nil
                                    selectedMode = .forgotPassword
                                }
                            },
                            submit: { email, password in
                                Task {
                                    await authViewModel.signInWithEmail(
                                        email: email,
                                        password: password
                                    )
                                }
                            }
                        )
                    } else if selectedMode == .forgotPassword {
                        ForgotPasswordForm(
                            isLoading: authViewModel.isLoading,
                            goBack: {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                    authViewModel.errorMessage = nil
                                    authViewModel.successMessage = nil
                                    selectedMode = .signIn
                                }
                            },
                            submit: { email in
                                Task {
                                    await authViewModel.forgotPassword(email: email)
                                }
                            }
                        )
                    } else {
                        EmailSignUpForm(
                            isLoading: authViewModel.isLoading,
                            submit: { firstName, lastName, dateOfBirth, email, password, passwordConfirmation in
                                Task {
                                    await authViewModel.registerWithEmail(
                                        email: email,
                                        firstName: firstName,
                                        lastName: lastName,
                                        dateOfBirth: dateOfBirth,
                                        password: password,
                                        passwordConfirmation: passwordConfirmation
                                    )
                                }
                            }
                        )
                    }

                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(RituoPalette.white)
                            .padding(.vertical, 2)
                    }

                    if let successMessage = authViewModel.successMessage {
                        LoginAuthNotice(text: successMessage, style: .success)
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        LoginAuthNotice(text: errorMessage, style: .error)
                    }
                }
                .padding(.top, selectedMode == .forgotPassword || isWaitingForEmailVerification ? 22 : 18)
                .padding(.bottom, 170)
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            TopRoundedRectangle(radius: 32)
                .fill(Color(red: 0.09, green: 0.12, blue: 0.20))
                .overlay {
                    TopRoundedRectangle(radius: 32)
                        .stroke(RituoPalette.white.opacity(0.07), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.40), radius: 30, x: 0, y: -8)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct LoginAuthNotice: View {
    enum Style {
        case success
        case error
    }

    let text: String
    let style: Style

    private var symbolName: String {
        switch style {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch style {
        case .success:
            return RituoPalette.success
        case .error:
            return RituoPalette.mistBlue
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint.opacity(0.92))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.66))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.055))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}

enum LoginMode {
    case signIn
    case signUp
    case forgotPassword
}

struct EmailVerificationPendingView: View {
    let email: String
    let isLoading: Bool
    let resend: () -> Void
    let goToSignIn: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RituoPalette.white.opacity(0.07))
                    .frame(width: 86, height: 86)

                Circle()
                    .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 86, height: 86)

                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
            }
            .padding(.top, 2)

            VStack(spacing: 8) {
                Text("Te mandamos un link de validación")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                    .multilineTextAlignment(.center)

                Text(email)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RituoPalette.lightBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Abrí el link desde tu correo para activar la cuenta. Después volvé a rituo e iniciá sesión.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }

            VStack(spacing: 10) {
                EmailVerificationStep(
                    number: "1",
                    title: "Buscá el mail de rituo",
                    detail: "Puede tardar unos segundos en llegar."
                )

                EmailVerificationStep(
                    number: "2",
                    title: "Tocá Confirmar email",
                    detail: "Ese link marca tu cuenta como verificada."
                )

                EmailVerificationStep(
                    number: "3",
                    title: "Volvé e iniciá sesión",
                    detail: "Ya no vas a poder entrar sin verificarlo."
                )
            }

            Button(action: goToSignIn) {
                HStack(spacing: 10) {
                    Text("Ya verifiqué mi email")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RituoPalette.white)
                .clipShape(Capsule())
                .shadow(color: RituoPalette.white.opacity(0.20), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.65 : 1)

            Button(action: resend) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane")
                    Text("Reenviar link")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RituoPalette.white.opacity(0.64))
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RituoPalette.white.opacity(0.055))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct EmailVerificationStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(width: 26, height: 26)
                .background(Circle().fill(RituoPalette.white.opacity(0.92)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.86))

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.44))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.045))
        )
    }
}

struct LoginModeSelector: View {
    @Binding var selectedMode: LoginMode

    var body: some View {
        HStack(spacing: 6) {
            LoginModeButton(
                title: "Iniciar sesión",
                isSelected: selectedMode == .signIn
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedMode = .signIn
                }
            }

            LoginModeButton(
                title: "Crear cuenta",
                isSelected: selectedMode == .signUp
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedMode = .signUp
                }
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(RituoPalette.white.opacity(0.06))
        )
        .overlay {
            Capsule()
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct LoginModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? RituoPalette.deepOceanBlue : RituoPalette.white.opacity(0.58))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    Capsule()
                        .fill(isSelected ? RituoPalette.white : Color.clear)
                )
        }
        .buttonStyle(LoginPressButtonStyle())
    }
}

struct EmailSignInForm: View {
    let isLoading: Bool
    let forgotPassword: () -> Void
    let submit: (String, String) -> Void

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                LoginTextFieldChrome(systemImage: "envelope", placeholder: "Correo") {
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                }

                LoginTextFieldChrome(systemImage: "lock", placeholder: "Contraseña") {
                    SecureField("Contraseña", text: $password)
                        .textContentType(.password)
                }
            }

            Button {
                submit(email, password)
            } label: {
                HStack(spacing: 10) {
                    Text("Iniciar sesión")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RituoPalette.white)
                .clipShape(Capsule())
                .shadow(color: RituoPalette.white.opacity(0.20), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.65 : 1)

            Button(action: forgotPassword) {
                Text("Olvidé mi contraseña")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.62))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
        }
    }
}

struct ForgotPasswordForm: View {
    let isLoading: Bool
    let goBack: () -> Void
    let submit: (String) -> Void

    @State private var email = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RituoPalette.white.opacity(0.72))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(RituoPalette.white.opacity(0.07)))
                }
                .buttonStyle(LoginPressButtonStyle())
                .disabled(isLoading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Recuperar contraseña")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RituoPalette.white)

                    Text("Te enviamos un link a tu correo.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.42))
                }

                Spacer(minLength: 0)
            }

            LoginTextFieldChrome(systemImage: "envelope", placeholder: "Correo") {
                TextField("Correo", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
            }

            Button {
                submit(email)
            } label: {
                HStack(spacing: 10) {
                    Text("Enviar link")
                    Image(systemName: "paperplane.fill")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RituoPalette.white)
                .clipShape(Capsule())
                .shadow(color: RituoPalette.white.opacity(0.20), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.65 : 1)
        }
    }
}

struct EmailSignUpForm: View {
    let isLoading: Bool
    let submit: (String, String, Date?, String, String, String) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth: Date?
    @State private var draftDateOfBirth = Date()
    @State private var showsDateOfBirthPicker = false
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                LoginTextFieldChrome(systemImage: "person", placeholder: "Nombre") {
                    TextField("Nombre", text: $firstName)
                        .textContentType(.givenName)
                }

                LoginTextFieldChrome(systemImage: "person.text.rectangle", placeholder: "Apellido") {
                    TextField("Apellido", text: $lastName)
                        .textContentType(.familyName)
                }

                Button {
                    draftDateOfBirth = dateOfBirth ?? Calendar.current.date(
                        byAdding: .year,
                        value: -16,
                        to: Date()
                    ) ?? Date()
                    showsDateOfBirthPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.36))
                            .frame(width: 22)

                        Text(
                            dateOfBirth.map {
                                Self.displayDateFormatter.string(from: $0)
                            } ?? "Fecha de nacimiento"
                        )
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                dateOfBirth == nil
                                    ? RituoPalette.white.opacity(0.36)
                                    : RituoPalette.white
                            )

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RituoPalette.white.opacity(0.28))
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(RituoPalette.white.opacity(0.06))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(LoginPressButtonStyle())
                .disabled(isLoading)

                LoginTextFieldChrome(systemImage: "envelope", placeholder: "Correo") {
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }

                LoginTextFieldChrome(systemImage: "lock", placeholder: "Contraseña") {
                    SecureField("Contraseña", text: $password)
                        .textContentType(.newPassword)
                }

                LoginTextFieldChrome(systemImage: "lock.shield", placeholder: "Repetir contraseña") {
                    SecureField("Repetir contraseña", text: $passwordConfirmation)
                        .textContentType(.newPassword)
                }
            }

            Button {
                submit(firstName, lastName, dateOfBirth, email, password, passwordConfirmation)
            } label: {
                HStack(spacing: 10) {
                    Text("Crear cuenta")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RituoPalette.white)
                .clipShape(Capsule())
                .shadow(color: RituoPalette.white.opacity(0.20), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.65 : 1)
        }
        .sheet(isPresented: $showsDateOfBirthPicker) {
            NavigationStack {
                DatePicker(
                    "Fecha de nacimiento",
                    selection: $draftDateOfBirth,
                    in: Self.earliestDateOfBirth ... Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "es_AR"))
                .padding()
                .navigationTitle("Fecha de nacimiento")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            showsDateOfBirthPicker = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirmar") {
                            dateOfBirth = draftDateOfBirth
                            showsDateOfBirthPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private static let earliestDateOfBirth = Calendar.current.date(
        byAdding: .year,
        value: -120,
        to: Date()
    ) ?? Date.distantPast

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct LoginTextFieldChrome<Content: View>: View {
    let systemImage: String
    let placeholder: String
    let content: () -> Content

    init(
        systemImage: String,
        placeholder: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.systemImage = systemImage
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.36))
                .frame(width: 22)

            content()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RituoPalette.white)
                .tint(RituoPalette.lightBlue)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct AppleLandingButton: View {
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    @StateObject private var coordinator = AppleSignInCoordinator()

    var body: some View {
        Button {
            coordinator.startSignIn(onCompletion: onCompletion)
        } label: {
            LandingAuthButtonChrome(
                title: "Iniciar sesión con Apple",
                icon: {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(RituoPalette.white)
                }
            )
        }
        .buttonStyle(LoginPressButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

final class AppleSignInCoordinator: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?
    private var currentController: ASAuthorizationController?

    func startSignIn(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.onCompletion = onCompletion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        currentController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        onCompletion?(.success(authorization))
        onCompletion = nil
        currentController = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        onCompletion?(.failure(error))
        onCompletion = nil
        currentController = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

struct LandingAuthButton<Icon: View>: View {
    let title: String
    let icon: () -> Icon
    let action: () -> Void

    init(
        title: String,
        @ViewBuilder icon: @escaping () -> Icon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            LandingAuthButtonChrome(title: title, icon: icon)
        }
        .buttonStyle(LoginPressButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct LandingAuthButtonChrome<Icon: View>: View {
    let title: String
    let icon: () -> Icon
    var isPressed = false

    init(
        title: String,
        @ViewBuilder icon: @escaping () -> Icon,
        isPressed: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.isPressed = isPressed
    }

    var body: some View {
        HStack(spacing: 0) {
            icon()
                .frame(width: 56, alignment: .center)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(isPressed ? 0.10 : 0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.09), lineWidth: 1)
        }
        .scaleEffect(isPressed ? 0.975 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isPressed)
    }
}

struct LoginPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.035 : 0)
            .shadow(
                color: configuration.isPressed ? RituoPalette.lightBlue.opacity(0.18) : Color.clear,
                radius: configuration.isPressed ? 12 : 0,
                x: 0,
                y: configuration.isPressed ? 5 : 0
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct GoogleLoginIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 40, height: 40)

            Text("G")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
}

struct EmailLoginIcon: View {
    var body: some View {
        Text("✉️")
            .font(.system(size: 28))
    }
}

struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct LandingBenefitRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RituoPalette.deepOceanBlue.opacity(0.08))
                    .frame(width: 48, height: 48)

                Image(systemName: symbol)
                    .font(.custom("Helvetica", size: 18).weight(.semibold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Helvetica", size: 15).weight(.semibold))
                    .foregroundStyle(RituoPalette.text)

                Text(subtitle)
                    .font(.custom("Helvetica", size: 12).weight(.medium))
                    .foregroundStyle(RituoPalette.subtext)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RituoPalette.white.opacity(0.74))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RituoPalette.stroke, lineWidth: 1)
        }
    }
}

struct LoginFeaturePill: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.custom("Helvetica", size: 12).weight(.bold))
            Text(text)
                .font(.custom("Helvetica", size: 12).weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
    }
}

final class LoginKeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
            .sink { [weak self] notification in
                guard let self else { return }

                if notification.name == UIResponder.keyboardWillHideNotification {
                    height = 0
                    return
                }

                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    height = 0
                    return
                }

                height = max(0, UIScreen.main.bounds.maxY - frame.minY)
            }
            .store(in: &cancellables)
    }
}
