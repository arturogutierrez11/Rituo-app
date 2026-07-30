import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

struct ProtectionOnboardingView: View {
    private enum Step: Int, CaseIterable {
        case screenTime
        case notifications
        case safari
        case summary

        var title: String {
            switch self {
            case .screenTime: return "Protección de apps"
            case .notifications: return "Avisos importantes"
            case .safari: return "Protección en Safari"
            case .summary: return "Todo preparado"
            }
        }
    }

    let isRecovery: Bool
    let onCompleted: () -> Void
    let onSignOut: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    @State private var step: Step = .screenTime
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isSafariExtensionEnabled = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private let notificationService = RitualNotificationService()

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        hero
                        stepContent
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 130)
                }

                actionArea
            }
        }
        .task {
            await refreshPermissionStates()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPermissionStates() }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 14) {
            HStack {
                if step != .screenTime {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(RituoPalette.white.opacity(0.68))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(RituoPalette.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }

                Spacer()

                Text("CONFIGURACIÓN INICIAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.7)
                    .foregroundStyle(RituoPalette.white.opacity(0.38))

                Spacer()

                Button("Salir") {
                    onSignOut()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.46))
                .frame(width: 38, height: 38)
            }

            HStack(spacing: 7) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue
                            ? RituoPalette.lightBlue
                            : RituoPalette.white.opacity(0.10))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(heroTint.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: heroSymbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(heroTint)
            }

            Text(step.title)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(RituoPalette.white)
                .multilineTextAlignment(.center)

            Text(heroMessage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .screenTime:
            VStack(spacing: 14) {
                permissionCard(
                    symbol: "hourglass.badge.lock",
                    title: "Screen Time",
                    detail: screenTimeDetail,
                    status: screenTimeStatusText,
                    isEnabled: isScreenTimeApproved,
                    isRequired: true
                )

                privacyNotice

                if authorizationCenter.authorizationStatus == .denied {
                    recoveryNotice
                }
            }

        case .notifications:
            VStack(spacing: 14) {
                permissionCard(
                    symbol: "bell.badge.fill",
                    title: "Notificaciones",
                    detail: "Te avisan cuando comienza o termina un ritual y cuando finaliza un recreo.",
                    status: notificationStatusText,
                    isEnabled: notificationsEnabled,
                    isRequired: false
                )

                informationCard(
                    symbol: "hand.raised.fill",
                    text: "Podés continuar aunque no las habilites. Rituo seguirá bloqueando, pero no podrá mostrarte avisos importantes."
                )
            }

        case .safari:
            VStack(spacing: 14) {
                permissionCard(
                    symbol: "safari.fill",
                    title: "Extensión de Safari",
                    detail: "Es necesaria para filtrar redes sociales y apuestas deportivas cuando navegás en Safari.",
                    status: isSafariExtensionEnabled ? "Activada" : "Sin activar",
                    isEnabled: isSafariExtensionEnabled,
                    isRequired: false
                )

                informationCard(
                    symbol: "gearshape.fill",
                    text: "En Ajustes, buscá Safari → Extensiones → rituo y activala. Después volvé y verificaremos el estado."
                )
            }

        case .summary:
            VStack(spacing: 0) {
                summaryRow(
                    symbol: "hourglass.badge.lock",
                    title: "Screen Time",
                    value: isScreenTimeApproved ? "Autorizado" : "Pendiente",
                    isEnabled: isScreenTimeApproved
                )
                divider
                summaryRow(
                    symbol: "bell.fill",
                    title: "Notificaciones",
                    value: notificationsEnabled ? "Activadas" : "Opcionales",
                    isEnabled: notificationsEnabled
                )
                divider
                summaryRow(
                    symbol: "safari.fill",
                    title: "Safari",
                    value: isSafariExtensionEnabled ? "Protegido" : "Opcional",
                    isEnabled: isSafariExtensionEnabled
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(RituoPalette.white.opacity(0.07), lineWidth: 1)
                    }
            )
        }

        if let errorMessage {
            LoginAuthNotice(text: errorMessage, style: .error)
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            switch step {
            case .screenTime:
                if isScreenTimeApproved {
                    primaryButton(title: "Continuar", symbol: "arrow.right") {
                        advance()
                    }
                } else {
                    primaryButton(
                        title: isWorking ? "Solicitando…" : "Autorizar Screen Time",
                        symbol: "checkmark.shield.fill"
                    ) {
                        Task { await requestScreenTimeAuthorization() }
                    }
                    .disabled(isWorking)
                    .opacity(isWorking ? 0.65 : 1)

                    if authorizationCenter.authorizationStatus == .denied {
                        secondaryButton(title: "Abrir Ajustes") {
                            openApplicationSettings()
                        }
                    }
                }

            case .notifications:
                if notificationsEnabled {
                    primaryButton(title: "Continuar", symbol: "arrow.right") {
                        advance()
                    }
                } else {
                    primaryButton(
                        title: isWorking ? "Solicitando…" : "Activar notificaciones",
                        symbol: "bell.badge.fill"
                    ) {
                        Task { await requestNotifications() }
                    }
                    .disabled(isWorking || notificationStatus == .denied)

                    secondaryButton(title: "Ahora no") {
                        advance()
                    }
                }

            case .safari:
                if isSafariExtensionEnabled {
                    primaryButton(title: "Continuar", symbol: "arrow.right") {
                        advance()
                    }
                } else {
                    primaryButton(title: "Abrir Ajustes", symbol: "gearshape.fill") {
                        openApplicationSettings()
                    }

                    secondaryButton(title: "Verificar nuevamente") {
                        Task { await refreshPermissionStates() }
                    }

                    secondaryButton(title: "Configurar más tarde") {
                        advance()
                    }
                }

            case .summary:
                primaryButton(title: "Empezar a usar rituo", symbol: "arrow.right") {
                    guard isScreenTimeApproved else {
                        step = .screenTime
                        return
                    }
                    onCompleted()
                }
            }

            if step == .screenTime {
                Link(destination: URL(string: "mailto:hello@rituo.io")!) {
                    Label("Necesito ayuda", systemImage: "questionmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.48))
                        .frame(minHeight: 32)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.96))
    }

    private var privacyNotice: some View {
        informationCard(
            symbol: "lock.shield.fill",
            text: "Rituo recibe identificadores privados de las apps seleccionadas. No puede ver su contenido, tus mensajes ni tu actividad dentro de ellas."
        )
    }

    private var recoveryNotice: some View {
        informationCard(
            symbol: "exclamationmark.triangle.fill",
            text: isRecovery
                ? "Screen Time fue desactivado. Volvé a autorizarlo para asegurar que tus rituales puedan aplicar y liberar restricciones."
                : "Sin esta autorización Rituo no puede bloquear aplicaciones. Podés volver a intentarlo o contactar a Soporte."
        )
    }

    private func permissionCard(
        symbol: String,
        title: String,
        detail: String,
        status: String,
        isEnabled: Bool,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isEnabled ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.38))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(RituoPalette.white.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RituoPalette.white)

                        if isRequired {
                            Text("OBLIGATORIO")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.7)
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(RituoPalette.lightBlue))
                        }
                    }

                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isEnabled ? Color.green.opacity(0.90) : RituoPalette.white.opacity(0.36))
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? Color.green : RituoPalette.white.opacity(0.20))
            }

            Text(detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.46))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.07), lineWidth: 1)
                }
        )
    }

    private func informationCard(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RituoPalette.lightBlue.opacity(0.85))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.44))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.045))
        )
    }

    private func summaryRow(
        symbol: String,
        title: String,
        value: String,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .foregroundStyle(isEnabled ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.30))
                .frame(width: 26)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.82))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.42))

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(isEnabled ? Color.green : RituoPalette.white.opacity(0.22))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(RituoPalette.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func primaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: symbol)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(RituoPalette.deepOceanBlue)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RituoPalette.white)
            .clipShape(Capsule())
        }
        .buttonStyle(LoginPressButtonStyle())
    }

    private func secondaryButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(RituoPalette.white.opacity(0.54))
            .frame(maxWidth: .infinity, minHeight: 38)
            .buttonStyle(LoginPressButtonStyle())
    }

    private var isScreenTimeApproved: Bool {
        authorizationCenter.authorizationStatus == .approved
    }

    private var notificationsEnabled: Bool {
        [.authorized, .provisional, .ephemeral].contains(notificationStatus)
    }

    private var screenTimeStatusText: String {
        switch authorizationCenter.authorizationStatus {
        case .approved: return "Autorizado"
        case .denied: return "Acceso denegado"
        case .notDetermined: return "Todavía no solicitado"
        @unknown default: return "Estado desconocido"
        }
    }

    private var screenTimeDetail: String {
        "Permite seleccionar y restringir apps durante rituales y modos. Es la función principal de Rituo."
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Activadas"
        case .provisional: return "Activadas de forma silenciosa"
        case .ephemeral: return "Activadas temporalmente"
        case .denied: return "Desactivadas"
        case .notDetermined: return "Todavía no solicitado"
        @unknown default: return "Estado desconocido"
        }
    }

    private var heroSymbol: String {
        switch step {
        case .screenTime: return "shield.lefthalf.filled.badge.checkmark"
        case .notifications: return "bell.badge.fill"
        case .safari: return "safari.fill"
        case .summary: return "checkmark.seal.fill"
        }
    }

    private var heroTint: Color {
        step == .summary ? Color.green : RituoPalette.lightBlue
    }

    private var heroMessage: String {
        switch step {
        case .screenTime:
            return isRecovery
                ? "La autorización principal dejó de estar disponible. Necesitamos recuperarla para que Rituo funcione correctamente."
                : "Rituo necesita algunos permisos para aplicar tus decisiones de forma confiable."
        case .notifications:
            return "Te mantenemos informado incluso cuando Rituo está en segundo plano."
        case .safari:
            return "Completá la protección de contenido sensible mientras navegás."
        case .summary:
            return "La protección principal está autorizada. Las opciones adicionales pueden configurarse más adelante desde Perfil."
        }
    }

    private func requestScreenTimeAuthorization() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            if authorizationCenter.authorizationStatus != .approved {
                errorMessage = "La autorización no se completó. Sin Screen Time no podemos activar los bloqueos."
            }
        } catch {
            errorMessage = "No pudimos autorizar Screen Time: \(error.localizedDescription)"
        }
    }

    private func requestNotifications() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let granted = await notificationService.requestAuthorization()
        await refreshPermissionStates()
        if !granted {
            errorMessage = "Las notificaciones quedaron desactivadas. Podés continuar y habilitarlas más adelante."
        }
    }

    private func refreshPermissionStates() async {
        notificationStatus = await notificationService.authorizationStatus()
        isSafariExtensionEnabled = await SafariContentBlockerController.isExtensionEnabled()
    }

    private func openApplicationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            step = next
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            step = previous
        }
    }
}
