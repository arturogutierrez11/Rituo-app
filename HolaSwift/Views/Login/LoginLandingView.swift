import AuthenticationServices
import Combine
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

struct LoginLandingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showsLoginOptions = false
    @State private var sheetDragOffset: CGFloat = 0
    @State private var logoAppeared = false
    @State private var textAppeared = false
    @State private var buttonAppeared = false
    @State private var glows = false
    @State private var rotates = false

    var body: some View {
        GeometryReader { proxy in
            let sheetHeight = min(max(proxy.size.height * 0.46, 430), 540)

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

                        Text("Ya tenés cuenta · Entrá acá")
                            .font(.custom("Helvetica", size: 13).weight(.semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.54))
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
                        authViewModel: authViewModel,
                        onAppleCompletion: handleAppleCompletion
                    )
                    .frame(height: sheetHeight)
                    .offset(y: sheetDragOffset)
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
                }
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

            printAppleTokenAudience(identityToken)

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

            authViewModel.errorMessage = "Sign in with Apple fallo: \(error.localizedDescription)"
        }
    }

    private func printAppleTokenAudience(_ identityToken: String) {
        let parts = identityToken.split(separator: ".")
        guard parts.count >= 2 else { return }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        print("Apple identityToken aud:", json["aud"] ?? "nil")
        print("Apple identityToken sub present:", json["sub"] != nil)
    }
}

struct LoginBottomSheet: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    @State private var mode: LoginBottomSheetMode = .social

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.81, green: 0.86, blue: 0.90).opacity(0.60))
                .frame(width: 36, height: 5)
                .padding(.top, 14)

            Text("Inicia sesion")
                .font(.custom("Helvetica", size: 30).weight(.bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .padding(.top, 36)

            Text("Continua para crear tu ritual de foco.")
                .font(.custom("Helvetica", size: 15).weight(.regular))
                .foregroundStyle(RituoPalette.darkCanteen.opacity(0.88))
                .padding(.top, 8)

            VStack(spacing: 14) {
                if mode == .social {
                    AppleLandingButton(onCompletion: onAppleCompletion)

                    LandingAuthButton(
                        title: "Iniciar sesion con Google",
                        icon: { GoogleLoginIcon() },
                        action: authViewModel.signInWithGoogle
                    )

                    LandingAuthButton(
                        title: "Iniciar sesion con mail",
                        icon: { EmailLoginIcon() },
                        action: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                authViewModel.errorMessage = nil
                                authViewModel.successMessage = nil
                                mode = .email
                            }
                        }
                    )
                } else {
                    EmailPasswordLoginForm(
                        isLoading: authViewModel.isLoading,
                        goBack: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                authViewModel.errorMessage = nil
                                mode = .social
                            }
                        },
                        submit: { email, password in
                            authViewModel.signInWithEmail(email: email, password: password)
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .tint(RituoPalette.deepOceanBlue)
                        .padding(.top, 2)
                }

                if let successMessage = authViewModel.successMessage {
                    MessageStrip(text: successMessage, tint: RituoPalette.success)
                }

                if let errorMessage = authViewModel.errorMessage {
                    MessageStrip(text: errorMessage, tint: RituoPalette.danger)
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            TopRoundedRectangle(radius: 40)
                .fill(Color(red: 0.98, green: 0.99, blue: 1.0))
                .shadow(color: Color.black.opacity(0.12), radius: 30, x: 0, y: -8)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private enum LoginBottomSheetMode {
    case social
    case email
}

struct EmailPasswordLoginForm: View {
    let isLoading: Bool
    let goBack: () -> Void
    let submit: (String, String) -> Void

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(RituoPalette.white))
                        .overlay {
                            Circle()
                                .stroke(Color(red: 0.84, green: 0.88, blue: 0.92), lineWidth: 1)
                        }
                }
                .buttonStyle(LoginPressButtonStyle())

                Text("Entrar con mail")
                    .font(.custom("Helvetica", size: 18).weight(.bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)

                Spacer()
            }

            VStack(spacing: 12) {
                LoginTextFieldChrome(systemImage: "envelope", placeholder: "Email") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LoginTextFieldChrome(systemImage: "lock", placeholder: "Password") {
                    SecureField("Password", text: $password)
                }
            }

            Button {
                submit(email, password)
            } label: {
                HStack(spacing: 10) {
                    Text("Iniciar sesion")
                    Image(systemName: "arrow.right")
                }
                .font(.custom("Helvetica", size: 17).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(RituoPalette.deepOceanBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: RituoPalette.deepOceanBlue.opacity(0.32), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(isLoading)
            .opacity(isLoading ? 0.65 : 1)
        }
    }
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RituoPalette.darkCanteen.opacity(0.78))
                .frame(width: 24)

            content()
                .font(.custom("Helvetica", size: 16).weight(.medium))
                .foregroundStyle(RituoPalette.deepOceanBlue)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(RituoPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.84, green: 0.88, blue: 0.92), lineWidth: 1.1)
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
                title: "Iniciar sesion con Apple",
                icon: {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.black)
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
                .frame(width: 62, alignment: .center)

            Text(title)
                .font(.custom("Helvetica", size: 16).weight(.semibold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(isPressed ? Color(red: 0.94, green: 0.96, blue: 0.98) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.91, blue: 0.95), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
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
