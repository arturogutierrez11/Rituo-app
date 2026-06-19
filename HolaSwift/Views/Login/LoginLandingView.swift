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

    var body: some View {
        GeometryReader { proxy in
            let sheetHeight = min(max(proxy.size.height * 0.46, 430), 540)

            ZStack(alignment: .bottom) {
                RituoAnimatedBackground()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 22) {
                        Image("RituoLogoWhite")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(proxy.size.width * 0.48, 238))

                        Text("Tus hábitos construyen la persona en la que te conviertes.")
                            .font(.custom("Helvetica", size: 15).weight(.medium))
                            .foregroundStyle(RituoPalette.white.opacity(0.86))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 52)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showsLoginOptions = true
                            sheetDragOffset = 0
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Iniciar sesion o registrarme")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(RituoPalette.white.opacity(0.94))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(LoginPressButtonStyle())
                    .padding(.bottom, 34)
                    .opacity(showsLoginOptions ? 0 : 1)
                    .allowsHitTesting(!showsLoginOptions)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, showsLoginOptions ? sheetHeight : 0)

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
                .fill(Color(red: 0.81, green: 0.86, blue: 0.90))
                .frame(width: 78, height: 7)
                .padding(.top, 30)

            Text("Inicia sesion")
                .font(.custom("Helvetica", size: 27).weight(.bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .padding(.top, 34)

            Text("Continua para crear tu ritual de foco.")
                .font(.custom("Helvetica", size: 16).weight(.regular))
                .foregroundStyle(RituoPalette.darkCanteen)
                .padding(.top, 12)

            VStack(spacing: 16) {
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
            .padding(.top, 30)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            TopRoundedRectangle(radius: 46)
                .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
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
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RituoPalette.deepOceanBlue)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
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
        .contentShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
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
        .contentShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
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
                .frame(width: 70, alignment: .center)

            Text(title)
                .font(.custom("Helvetica", size: 18).weight(.bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(isPressed ? RituoPalette.lightBlue.opacity(0.10) : RituoPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(isPressed ? RituoPalette.lightBlue.opacity(0.60) : Color(red: 0.84, green: 0.88, blue: 0.92), lineWidth: 1.2)
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
