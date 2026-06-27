import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct ProfilePage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var tagPendingRevocation: NfcTagClaimResponse?
    @State private var isRevokeConfirmationPresented = false
    @State private var tagPendingRename: NfcTagClaimResponse?
    @State private var tagRenameText = ""
    @State private var isRenameAlertPresented = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroSection
                    statsStrip
                        .padding(.horizontal, 20)
                    profileSection
                        .padding(.horizontal, 20)
                    metricsSection
                        .padding(.horizontal, 20)
                    systemSection
                        .padding(.horizontal, 20)
                    nfcSection
                        .padding(.horizontal, 20)
                    settingsSection
                        .padding(.horizontal, 20)
                    legalSection
                        .padding(.horizontal, 20)
                    aboutSection
                        .padding(.horizontal, 20)
                    signOutSection
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 44)
            }
        }
        .sheet(isPresented: $showTermsSheet) { legalSheet(title: "Términos y Condiciones", content: termsText) }
        .sheet(isPresented: $showPrivacySheet) { legalSheet(title: "Política de Privacidad", content: privacyText) }
        .confirmationDialog("Desvincular tag", isPresented: $isRevokeConfirmationPresented, titleVisibility: .visible) {
            Button("Desvincular", role: .destructive) {
                guard let claim = tagPendingRevocation, let token = authViewModel.accessToken else {
                    tagPendingRevocation = nil; return
                }
                tagPendingRevocation = nil
                Task { await viewModel.revokeTagClaim(claim, accessToken: token) }
            }
            Button("Cancelar", role: .cancel) { tagPendingRevocation = nil }
        } message: {
            Text("Este tag dejará de funcionar como llave para tu cuenta.")
        }
        .alert("Nombre del tag", isPresented: $isRenameAlertPresented) {
            TextField("Ej. Llave de casa", text: $tagRenameText)
            Button("Guardar") {
                guard let claim = tagPendingRename, let token = authViewModel.accessToken else {
                    tagPendingRename = nil; tagRenameText = ""; return
                }
                let label = tagRenameText
                tagPendingRename = nil; tagRenameText = ""
                Task { await viewModel.renameTagClaim(claim, label: label, accessToken: token) }
            }
            Button("Cancelar", role: .cancel) { tagPendingRename = nil; tagRenameText = "" }
        } message: {
            Text("Usá un nombre que te ayude a reconocer dónde está.")
        }
    }

    // MARK: - Hero section

    private var heroSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERFIL")
                        .font(.custom("Helvetica", size: 10).weight(.bold))
                        .tracking(3)
                        .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
                    Text("Tu cuenta")
                        .font(.custom("Helvetica", size: 28).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                }
                Spacer()
                Image("RituoLogoWhite")
                    .resizable().scaledToFit().frame(width: 64)
            }

            ProfileAvatar(imageURL: authViewModel.profileImageURL, initials: initials)

            VStack(spacing: 5) {
                Text(displayName == "Perfil" ? "Tu perfil" : displayName)
                    .font(.custom("Helvetica", size: 24).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text(authViewModel.authUser?.email ?? "")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.mistBlue.opacity(0.72))
            }

            HStack(spacing: 8) {
                ProfileStatusBadge(
                    text: authViewModel.authUser?.status == "active" ? "Activo" : "Pendiente",
                    isOn: authViewModel.authUser?.status == "active",
                    symbol: "person.fill.checkmark"
                )
                ProfileStatusBadge(
                    text: authViewModel.authUser?.emailVerified == true ? "Email verificado" : "Sin verificar",
                    isOn: authViewModel.authUser?.emailVerified == true,
                    symbol: "envelope.badge.shield.half.filled"
                )
                ProfileStatusBadge(
                    text: authProviderText,
                    isOn: authViewModel.authProvider != nil,
                    symbol: "key.fill"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            ProfileStatPill(
                value: "\(viewModel.ritualSessionSummary?.totalSessions ?? 0)",
                label: "Sesiones",
                symbol: "list.bullet.rectangle",
                tint: RituoPalette.lightBlue,
                isLoading: viewModel.isLoadingSessionSummary && viewModel.ritualSessionSummary == nil
            )
            ProfileStatPill(
                value: focusTotalText,
                label: "Foco total",
                symbol: "timer",
                tint: RituoPalette.white,
                isLoading: viewModel.isLoadingSessionSummary && viewModel.ritualSessionSummary == nil
            )
            ProfileStatPill(
                value: "\(viewModel.ritualSessionSummary?.currentStreakDays ?? 0)d",
                label: "Racha",
                symbol: "flame.fill",
                tint: Color.orange,
                isLoading: viewModel.isLoadingSessionSummary && viewModel.ritualSessionSummary == nil
            )
        }
    }

    // MARK: - Profile info

    private var profileSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Mi cuenta")
            ProfileGlassCard {
                VStack(spacing: 0) {
                    SettingsRow(symbol: "person.text.rectangle", symbolColor: RituoPalette.lightBlue, label: "Nombre", value: nameParts.first)
                    cardDivider
                    SettingsRow(symbol: "person.crop.square", symbolColor: RituoPalette.mistBlue, label: "Apellido", value: nameParts.last)
                    cardDivider
                    SettingsRow(symbol: "envelope", symbolColor: Color(red: 0.4, green: 0.7, blue: 1.0), label: "Email", value: authViewModel.authUser?.email ?? "–")
                    cardDivider
                    SettingsRow(symbol: "key", symbolColor: Color.orange, label: "Inicio de sesión", value: authProviderText)

                    // Tag NFC config — shown only when linked
                    if viewModel.hasClaimedNfcTag, let claim = viewModel.nfcTagClaims.first {
                        Rectangle().fill(RituoPalette.white.opacity(0.06)).frame(height: 1).padding(.top, 6)

                        // Section sub-label
                        HStack {
                            Text("TAG NFC")
                                .font(.custom("Helvetica", size: 9).weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(RituoPalette.mistBlue.opacity(0.55))
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                    .shadow(color: Color.green.opacity(0.60), radius: 3)
                                Text("Vinculada")
                                    .font(.custom("Helvetica", size: 10).weight(.bold))
                                    .foregroundStyle(Color.green.opacity(0.80))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                        // Rename
                        Button {
                            tagPendingRename = claim
                            tagRenameText = claim.label ?? ""
                            isRenameAlertPresented = true
                        } label: {
                            SettingsLinkRow(symbol: "pencil", symbolColor: RituoPalette.lightBlue,
                                           label: claim.label ?? "Tag vinculado",
                                           detail: "Renombrar")
                        }
                        .buttonStyle(.plain)

                        cardDivider

                        // Replace
                        Button {
                            if let token = authViewModel.accessToken {
                                viewModel.claimTag(accessToken: token)
                            }
                        } label: {
                            SettingsLinkRow(symbol: "arrow.triangle.2.circlepath", symbolColor: Color.orange,
                                           label: "Reemplazar tarjeta", detail: nil)
                        }
                        .buttonStyle(.plain)

                        cardDivider

                        // Unlink
                        Button {
                            tagPendingRevocation = claim
                            isRevokeConfirmationPresented = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(RituoPalette.danger.opacity(0.16))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(RituoPalette.danger)
                                }
                                Text("Desvincular tarjeta")
                                    .font(.custom("Helvetica", size: 15).weight(.semibold))
                                    .foregroundStyle(RituoPalette.danger)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Métricas de foco")
            ProfileGlassCard {
                if viewModel.isLoadingSessionSummary && viewModel.ritualSessionSummary == nil {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(["Sesiones", "Completadas", "Foco", "Racha"], id: \.self) { title in
                            ProfileMetricLoadingTile(title: title)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ProfileMetricTile(
                            value: "\(viewModel.ritualSessionSummary?.totalSessions ?? 0)",
                            label: "Sesiones",
                            symbol: "list.bullet.rectangle",
                            tint: RituoPalette.lightBlue,
                            isOn: (viewModel.ritualSessionSummary?.totalSessions ?? 0) > 0
                        )
                        ProfileMetricTile(
                            value: "\(viewModel.ritualSessionSummary?.completedSessions ?? 0)",
                            label: "Completadas",
                            symbol: "checkmark.circle.fill",
                            tint: Color.green,
                            isOn: (viewModel.ritualSessionSummary?.completedSessions ?? 0) > 0
                        )
                        ProfileMetricTile(
                            value: focusTotalText,
                            label: "Tiempo de foco",
                            symbol: "timer",
                            tint: RituoPalette.white,
                            isOn: (viewModel.ritualSessionSummary?.totalFocusMinutes ?? 0) > 0
                        )
                        ProfileMetricTile(
                            value: "\(viewModel.ritualSessionSummary?.currentStreakDays ?? 0)d",
                            label: "Racha",
                            symbol: "flame.fill",
                            tint: Color.orange,
                            isOn: (viewModel.ritualSessionSummary?.currentStreakDays ?? 0) > 0
                        )
                    }
                }
            }
        }
    }

    // MARK: - System status

    private var systemSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Estado del sistema")
            ProfileGlassCard {
                VStack(spacing: 0) {
                    SystemRow(symbol: "person.crop.circle", label: "Cuenta",
                              value: authViewModel.authUser?.status.capitalized ?? "Sin login",
                              isOn: authViewModel.authUser?.status == "active")
                    cardDivider
                    SystemRow(symbol: "envelope", label: "Email",
                              value: authViewModel.authUser?.emailVerified == true ? "Verificado" : "Pendiente",
                              isOn: authViewModel.authUser?.emailVerified == true)
                    cardDivider
                    SystemRow(symbol: "shield", label: "Screen Time",
                              value: viewModel.authorizationStatusText,
                              isOn: viewModel.isAuthorized)
                    cardDivider
                    SystemRow(symbol: "lock", label: "Bloqueo",
                              value: viewModel.blockedUntil == nil ? "No activo" : "Activo",
                              isOn: viewModel.blockedUntil != nil)
                    cardDivider
                    SystemRow(symbol: "tag", label: "Tag NFC",
                              value: viewModel.nfcTagStatusText,
                              isOn: viewModel.hasClaimedNfcTag)
                }
            }
        }
    }

    // MARK: - NFC

    private var nfcSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Tag NFC")
            VStack(spacing: 14) {
                // Physical card visual
                if viewModel.hasClaimedNfcTag, let claim = viewModel.nfcTagClaims.first {
                    RituoPhysicalCard(label: claim.label)
                } else {
                    ZStack {
                        RituoPhysicalCard(label: nil).opacity(0.46)
                        VStack(spacing: 10) {
                            Image(systemName: "wave.3.right.circle")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(RituoPalette.white.opacity(0.38))
                            Text("Sin tarjeta vinculada")
                                .font(.custom("Helvetica", size: 13).weight(.semibold))
                                .foregroundStyle(RituoPalette.white.opacity(0.40))
                        }
                    }
                }

                if let msg = viewModel.tagMessage {
                    Text(msg)
                        .font(.custom("Helvetica", size: 12).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.52))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }

                // Show link button only when no tag is linked
                if !viewModel.hasClaimedNfcTag {
                    Button {
                        if let token = authViewModel.accessToken {
                            viewModel.claimTag(accessToken: token)
                        } else {
                            viewModel.tagMessage = "Iniciá sesión para vincular un tag."
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isReadingTag {
                                ProgressView().tint(RituoPalette.deepOceanBlue)
                            } else {
                                Image(systemName: "wave.3.right.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text("Vincular tarjeta")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                        }
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RituoPalette.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: RituoPalette.white.opacity(0.18), radius: 12, y: 4)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                    .disabled(viewModel.isReadingTag)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Ajustes")
            ProfileGlassCard {
                VStack(spacing: 0) {
                    SettingsLinkRow(symbol: "bell", symbolColor: Color.red, label: "Notificaciones", detail: "Activadas")
                    cardDivider
                    SettingsLinkRow(symbol: "hand.raised", symbolColor: Color.blue, label: "Privacidad", detail: nil)
                    cardDivider
                    SettingsLinkRow(symbol: "iphone", symbolColor: RituoPalette.lightBlue, label: "Permisos de Screen Time", detail: viewModel.isAuthorized ? "Autorizados" : "Pendiente")
                }
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Legal")
            ProfileGlassCard {
                VStack(spacing: 0) {
                    Button { showTermsSheet = true } label: {
                        SettingsLinkRow(symbol: "doc.text", symbolColor: RituoPalette.mistBlue, label: "Términos y Condiciones", detail: nil)
                    }
                    .buttonStyle(.plain)

                    cardDivider

                    Button { showPrivacySheet = true } label: {
                        SettingsLinkRow(symbol: "lock.shield", symbolColor: Color.green, label: "Política de Privacidad", detail: nil)
                    }
                    .buttonStyle(.plain)

                    cardDivider

                    SettingsLinkRow(symbol: "text.justify.left", symbolColor: Color(red: 0.6, green: 0.4, blue: 1.0), label: "Licencias de código abierto", detail: nil)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Acerca de")
            ProfileGlassCard {
                VStack(spacing: 0) {
                    SettingsRow(symbol: "info.circle", symbolColor: RituoPalette.lightBlue, label: "Versión", value: appVersion)
                    cardDivider
                    SettingsRow(symbol: "applescript", symbolColor: RituoPalette.mistBlue, label: "Build", value: appBuild)
                    cardDivider
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 34, height: 34)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }
                        Text("Compartir Rituo")
                            .font(.custom("Helvetica", size: 15).weight(.semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.88))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.24))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Sign out

    private var signOutSection: some View {
        Button {
            authViewModel.signOut()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .bold))
                Text("Cerrar sesión")
                    .font(.custom("Helvetica", size: 16).weight(.bold))
            }
            .foregroundStyle(RituoPalette.danger)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RituoPalette.danger.opacity(0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RituoPalette.danger.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(LoginPressButtonStyle())
        .padding(.top, 8)
    }

    // MARK: - Legal sheets

    private func legalSheet(title: String, content: String) -> some View {
        ZStack {
            Color(red: 0.08, green: 0.11, blue: 0.22).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(.custom("Helvetica", size: 26).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Text(content)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(5)
                }
                .padding(28)
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.custom("Helvetica", size: 11).weight(.bold))
            .tracking(1.2)
            .foregroundStyle(RituoPalette.mistBlue.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6)
            .padding(.bottom, 8)
            .padding(.top, 4)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(RituoPalette.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    // MARK: - Computed values

    private func lastSeenText(for claim: NfcTagClaimResponse) -> String {
        guard let lastSeenAt = claim.lastSeenAt else { return "Todavía no utilizado" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: lastSeenAt) ?? {
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: lastSeenAt)
        }()
        guard let date else { return "Vinculado" }
        let fmt = RelativeDateTimeFormatter()
        fmt.locale = Locale(identifier: "es_AR")
        fmt.unitsStyle = .full
        return "Usado \(fmt.localizedString(for: date, relativeTo: .now))"
    }

    private var displayName: String {
        let candidate = authViewModel.authUser?.displayName ?? authViewModel.profileDisplayName
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Perfil" }
        return candidate
    }

    private var nameParts: (first: String, last: String) {
        let parts = displayName.split(separator: " ").map(String.init)
        guard displayName != "Perfil", !parts.isEmpty else { return ("Sin nombre", "Sin apellido") }
        return parts.count == 1 ? (parts[0], "Sin apellido") : (parts[0], parts.dropFirst().joined(separator: " "))
    }

    private var initials: String {
        if displayName == "Perfil" { return "R" }
        let letters = displayName.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "R" : letters
    }

    private var authProviderText: String { authViewModel.authProvider?.displayName ?? "No detectado" }

    private var focusTotalText: String {
        let mins = viewModel.ritualSessionSummary?.totalFocusMinutes ?? 0
        let h = mins / 60; let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(mins)m"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var termsText: String {
"""
Última actualización: junio 2025

Al usar Rituo aceptás estos términos y condiciones en su totalidad. Si no estás de acuerdo, por favor no uses la aplicación.

1. Uso de la aplicación
Rituo es una herramienta de productividad personal que utiliza las APIs de Screen Time de Apple para ayudarte a gestionar el uso de aplicaciones durante períodos de enfoque definidos por vos.

2. Cuenta y acceso
Para usar Rituo necesitás crear una cuenta o iniciar sesión con Apple/Google. Sos responsable de mantener la seguridad de tu cuenta y contraseña.

3. Privacidad y datos
Recopilamos únicamente los datos necesarios para el funcionamiento de la app: información de sesiones de bloqueo, horarios de rituales y estado de tags NFC. No vendemos ni compartimos tu información personal con terceros.

4. Limitaciones del servicio
Rituo depende de las APIs de Screen Time de Apple. Ciertas funciones pueden no estar disponibles en todos los dispositivos o versiones de iOS.

5. Propiedad intelectual
Todo el contenido, diseño y código de Rituo es propiedad de sus creadores. Queda prohibida su reproducción sin autorización expresa.

6. Modificaciones
Nos reservamos el derecho de modificar estos términos en cualquier momento. Los cambios entran en vigencia inmediatamente después de su publicación en la app.

Para consultas escribinos a soporte@rituo.app
"""
    }

    private var privacyText: String {
"""
Última actualización: junio 2025

En Rituo tomamos muy en serio tu privacidad. Esta política describe cómo recopilamos, usamos y protegemos tu información.

1. Qué datos recopilamos
- Información de tu cuenta: nombre, email y foto de perfil
- Datos de uso: sesiones de foco, rituales configurados, duración de bloqueos
- Información del dispositivo: modelo, versión de iOS (solo para soporte técnico)
- Tags NFC vinculados a tu cuenta

2. Cómo usamos los datos
- Para proveer el servicio de bloqueo y seguimiento de rituales
- Para mostrarte estadísticas de tu progreso
- Para mejorar la experiencia de la aplicación

3. Almacenamiento y seguridad
Tus datos se almacenan en servidores seguros con cifrado en tránsito (HTTPS) y en reposo. Nunca almacenamos contraseñas en texto plano.

4. Compartir datos
No vendemos ni compartimos tu información personal con terceros, excepto cuando sea requerido por ley.

5. Tus derechos
Podés solicitar la eliminación de tu cuenta y todos tus datos enviando un email a privacidad@rituo.app

6. Retención de datos
Conservamos tus datos mientras tengas una cuenta activa. Al eliminar tu cuenta, borramos todos tus datos en un plazo de 30 días.

Contacto: privacidad@rituo.app
"""
    }
}

// MARK: - Stats pill

private struct ProfileStatPill: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tint.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint.opacity(0.90))
            }
            if isLoading {
                RituoLoadingBar(width: 36, height: 14)
            } else {
                Text(value)
                    .font(.custom("Helvetica", size: 18).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .monospacedDigit()
            }
            Text(label)
                .font(.custom("Helvetica", size: 10).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.46))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.20, green: 0.27, blue: 0.40), Color(red: 0.11, green: 0.15, blue: 0.26)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - Settings row (with value on right)

private struct SettingsRow: View {
    let symbol: String
    let symbolColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(symbolColor.opacity(0.20))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(symbolColor)
            }
            Text(label)
                .font(.custom("Helvetica", size: 15).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.88))
            Spacer()
            Text(value)
                .font(.custom("Helvetica", size: 14).weight(.medium))
                .foregroundStyle(RituoPalette.white.opacity(0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings link row (with chevron)

private struct SettingsLinkRow: View {
    let symbol: String
    let symbolColor: Color
    let label: String
    let detail: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(symbolColor.opacity(0.20))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(symbolColor)
            }
            Text(label)
                .font(.custom("Helvetica", size: 15).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.88))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.36))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.22))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Glass card container

private struct ProfileGlassCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.20, green: 0.27, blue: 0.40), Color(red: 0.11, green: 0.15, blue: 0.26)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
    }
}

// MARK: - Profile info row

private struct ProfileInfoRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.mistBlue.opacity(0.72))
                .frame(width: 28)
            Text(label)
                .font(.custom("Helvetica", size: 13).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.custom("Helvetica", size: 13).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

// MARK: - Status badge

private struct ProfileStatusBadge: View {
    let text: String
    let isOn: Bool
    let symbol: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.36))
            Text(text)
                .font(.custom("Helvetica", size: 10).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(isOn ? 0.88 : 0.50))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(isOn ? RituoPalette.white.opacity(0.12) : RituoPalette.white.opacity(0.06)))
        .overlay { Capsule().stroke(isOn ? RituoPalette.white.opacity(0.22) : RituoPalette.white.opacity(0.06), lineWidth: 1) }
    }
}

// MARK: - System status row

private struct SystemRow: View {
    let symbol: String
    let label: String
    let value: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? RituoPalette.lightBlue.opacity(0.18) : RituoPalette.white.opacity(0.07))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.40))
            }
            Text(label)
                .font(.custom("Helvetica", size: 15).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.82))
            Spacer()
            Text(value)
                .font(.custom("Helvetica", size: 13).weight(.medium))
                .foregroundStyle(RituoPalette.white.opacity(0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Circle()
                .fill(isOn ? Color.green : RituoPalette.white.opacity(0.20))
                .frame(width: 7, height: 7)
                .shadow(color: Color.green.opacity(isOn ? 0.60 : 0), radius: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Metric tile

private struct ProfileMetricTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(tint.opacity(0.14)).frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint.opacity(0.90))
                }
                Spacer()
                Circle()
                    .fill(isOn ? tint : RituoPalette.white.opacity(0.16))
                    .frame(width: 7, height: 7)
                    .shadow(color: tint.opacity(isOn ? 0.56 : 0), radius: 5)
            }
            Text(value)
                .font(.custom("Helvetica", size: 22).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()
            Text(label)
                .font(.custom("Helvetica", size: 11).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.48))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RituoPalette.white.opacity(0.07), lineWidth: 1) }
    }
}

// MARK: - Rituo physical NFC card

struct RituoPhysicalCard: View {
    let label: String?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // Base gradient — navy blue metallic
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.38, blue: 0.56),
                            Color(red: 0.17, green: 0.23, blue: 0.38),
                            Color(red: 0.10, green: 0.14, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                // Metallic sheen highlight (top center-left)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: 0.2, y: 0),
                        endPoint: UnitPoint(x: 0.7, y: 0.55)
                    ))

                // Secondary sheen (bottom-right subtle)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.clear, Color(red: 0.36, green: 0.50, blue: 0.72).opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                // Watermark logo — centered
                Image("RituoLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.44)
                    .opacity(0.10)
                    .position(x: geo.size.width * 0.57, y: geo.size.height * 0.54)

                // "rituo" brand text — top left
                Text("rituo")
                    .font(.custom("Helvetica", size: geo.size.height * 0.14).weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.top, geo.size.height * 0.14)
                    .padding(.leading, geo.size.width * 0.07)

                // Tag name — bottom left
                if let label {
                    VStack(alignment: .leading, spacing: 2) {
                        Spacer()
                        Text(label.uppercased())
                            .font(.custom("Helvetica", size: geo.size.height * 0.11).weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.bottom, geo.size.height * 0.14)
                    .padding(.leading, geo.size.width * 0.07)
                }

                // NFC chip indicator — bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(red: 0.22, green: 0.30, blue: 0.46).opacity(0.80))
                                .frame(width: geo.size.width * 0.11, height: geo.size.height * 0.20)
                            Image(systemName: "wave.3.right")
                                .font(.system(size: geo.size.height * 0.09, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.40))
                        }
                        .padding(.trailing, geo.size.width * 0.06)
                        .padding(.bottom, geo.size.height * 0.12)
                    }
                }
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: Color(red: 0.10, green: 0.14, blue: 0.28).opacity(0.55), radius: 24, x: 0, y: 12)
        .shadow(color: Color(red: 0.20, green: 0.30, blue: 0.52).opacity(0.25), radius: 14, x: 0, y: 4)
    }
}

// MARK: - Shared legacy components (kept for compatibility)

struct ProfileBrandBadge: View {
    let text: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.34)).frame(width: 6, height: 6)
            Text(text).lineLimit(1)
        }
        .font(.custom("Helvetica", size: 11).weight(.bold))
        .foregroundStyle(RituoPalette.white.opacity(isOn ? 0.90 : 0.60))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background { Capsule().fill(RituoPalette.white.opacity(isOn ? 0.16 : 0.08)) }
        .overlay { Capsule().stroke(RituoPalette.white.opacity(isOn ? 0.24 : 0.08), lineWidth: 1) }
    }
}

struct ProfileInfoChip: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RituoPalette.mistBlue.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.88))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.custom("Helvetica", size: 9).weight(.bold)).tracking(0.5).foregroundStyle(RituoPalette.white.opacity(0.40))
                Text(value).font(.custom("Helvetica", size: 14).weight(.bold)).foregroundStyle(RituoPalette.white.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 70)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RituoPalette.white.opacity(0.075)) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RituoPalette.white.opacity(0.08), lineWidth: 1) }
    }
}

struct ProfileMailStrip: View {
    let email: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.82))
            Text(email).font(.custom("Helvetica", size: 13).weight(.bold)).foregroundStyle(RituoPalette.white.opacity(0.86)).lineLimit(1).minimumScaleFactor(0.66)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RituoPalette.white.opacity(0.07)) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RituoPalette.white.opacity(0.08), lineWidth: 1) }
    }
}

struct ProfileDarkRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.custom("Helvetica", size: 12).weight(.bold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
            Spacer()
            Text(value).font(.custom("Helvetica", size: 13).weight(.bold)).foregroundStyle(RituoPalette.white).lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
        .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(RituoPalette.white.opacity(0.06), lineWidth: 1) }
    }
}

struct ProfileBrandStateTile: View {
    let title: String
    let value: String
    let symbol: String
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill((isOn ? RituoPalette.lightBlue : RituoPalette.white).opacity(isOn ? 0.16 : 0.07)).frame(width: 36, height: 36)
                    Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(isOn ? RituoPalette.mistBlue : RituoPalette.white.opacity(0.50))
                }
                Spacer()
                Circle().fill(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.18)).frame(width: 7, height: 7)
                    .shadow(color: RituoPalette.lightBlue.opacity(isOn ? 0.52 : 0), radius: 6)
            }
            Text(title).font(.custom("Helvetica", size: 11).weight(.semibold)).foregroundStyle(RituoPalette.white.opacity(0.54))
            Text(value).font(.custom("Helvetica", size: 15).weight(.bold)).foregroundStyle(RituoPalette.white).lineLimit(2).minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(16)
        .background { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(colors: [RituoPalette.white.opacity(0.105), RituoPalette.white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RituoPalette.white.opacity(0.085), lineWidth: 1) }
    }
}

struct ProfileMetricLoadingTile: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { RituoLoadingBar(width: 24, height: 16); Spacer(); Circle().fill(RituoPalette.white.opacity(0.20)).frame(width: 8, height: 8) }
            Text(title).font(.custom("Helvetica", size: 12).weight(.bold)).foregroundStyle(RituoPalette.white.opacity(0.48))
            RituoLoadingBar(width: 56, height: 16)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
    }
}

struct ProfileAvatar: View {
    let imageURL: URL?
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [RituoPalette.white.opacity(0.88), RituoPalette.mistBlue.opacity(0.58), RituoPalette.deepOceanBlue.opacity(0.28)],
                    center: .topLeading, startRadius: 4, endRadius: 74
                ))
                .frame(width: 90, height: 90)
                .shadow(color: RituoPalette.lightBlue.opacity(0.22), radius: 20, y: 8)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: fallback
                    }
                }
                .frame(width: 82, height: 82).clipShape(Circle())
            } else {
                fallback.frame(width: 82, height: 82)
            }
        }
        .overlay {
            Circle().stroke(
                LinearGradient(colors: [RituoPalette.white.opacity(0.78), RituoPalette.white.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 2
            )
        }
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [RituoPalette.white.opacity(0.92), RituoPalette.mistBlue.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initials).font(.custom("Helvetica", size: 28).weight(.bold)).foregroundStyle(RituoPalette.deepOceanBlue)
        }
    }
}

struct ProfileHeader: View {
    @ObservedObject var authViewModel: AuthViewModel
    var body: some View { EmptyView() }
}

struct AuthAccountPanel: View {
    @ObservedObject var authViewModel: AuthViewModel
    var showsDiagnostics = true
    var body: some View { EmptyView() }
}
