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

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    BrandScreenHeader(
                        eyebrow: "Profile",
                        quote: "Tu ritual empieza por diseñar el entorno que te cuida."
                    )

                    profileHero
                    metricsPanel
                    systemPanel
                    nfcTagPanel
                    sessionPanel
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 20)
            }
        }
        .confirmationDialog(
            "Desvincular tag",
            isPresented: $isRevokeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Desvincular", role: .destructive) {
                guard
                    let claim = tagPendingRevocation,
                    let accessToken = authViewModel.accessToken
                else {
                    tagPendingRevocation = nil
                    return
                }

                tagPendingRevocation = nil
                Task {
                    await viewModel.revokeTagClaim(claim, accessToken: accessToken)
                }
            }

            Button("Cancelar", role: .cancel) {
                tagPendingRevocation = nil
            }
        } message: {
            Text("Este tag dejará de funcionar como llave para tu cuenta. Los demás usuarios vinculados no se verán afectados.")
        }
        .alert("Nombre del tag", isPresented: $isRenameAlertPresented) {
            TextField("Ej. Llave de casa", text: $tagRenameText)

            Button("Guardar") {
                guard
                    let claim = tagPendingRename,
                    let accessToken = authViewModel.accessToken
                else {
                    tagPendingRename = nil
                    tagRenameText = ""
                    return
                }

                let label = tagRenameText
                tagPendingRename = nil
                tagRenameText = ""

                Task {
                    await viewModel.renameTagClaim(
                        claim,
                        label: label,
                        accessToken: accessToken
                    )
                }
            }

            Button("Cancelar", role: .cancel) {
                tagPendingRename = nil
                tagRenameText = ""
            }
        } message: {
            Text("Usá un nombre que te ayude a reconocer dónde está o para quién funciona.")
        }
    }

    private var profileHero: some View {
        BrandPanel {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    ProfileAvatar(
                        imageURL: authViewModel.profileImageURL,
                        initials: initials
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayName)
                            .font(.custom("Helvetica", size: 25).weight(.bold))
                            .foregroundStyle(RituoPalette.white)
                            .lineLimit(2)

                        Text(authViewModel.authUser?.email ?? "Sin email")
                            .font(.custom("Helvetica", size: 13).weight(.medium))
                            .foregroundStyle(RituoPalette.white.opacity(0.68))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    ProfileBrandBadge(text: authViewModel.authUser?.status == "active" ? "Activo" : "Sin sesion", isOn: authViewModel.authUser?.status == "active")
                    ProfileBrandBadge(text: authViewModel.authUser?.emailVerified == true ? "Email verificado" : "Email pendiente", isOn: authViewModel.authUser?.emailVerified == true)
                    ProfileBrandBadge(text: authProviderText, isOn: authViewModel.authProvider != nil)
                }

                VStack(spacing: 10) {
                    ProfileDarkRow(label: "Nombre", value: nameParts.first)
                    ProfileDarkRow(label: "Apellido", value: nameParts.last)
                    ProfileDarkRow(label: "Mail", value: authViewModel.authUser?.email ?? "Sin mail")
                    ProfileDarkRow(label: "Login", value: authProviderText)
                }
            }
        }
    }

    private var metricsPanel: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Métricas")
                    .font(.custom("Helvetica", size: 20).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                if viewModel.isLoadingSessionSummary && viewModel.ritualSessionSummary == nil {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ProfileMetricLoadingTile(title: "Sesiones")
                        ProfileMetricLoadingTile(title: "Completadas")
                        ProfileMetricLoadingTile(title: "Foco")
                        ProfileMetricLoadingTile(title: "Racha")
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ProfileBrandStateTile(title: "Sesiones", value: "\(viewModel.ritualSessionSummary?.totalSessions ?? 0)", symbol: "list.bullet.rectangle", isOn: (viewModel.ritualSessionSummary?.totalSessions ?? 0) > 0)
                        ProfileBrandStateTile(title: "Completadas", value: "\(viewModel.ritualSessionSummary?.completedSessions ?? 0)", symbol: "checkmark.circle", isOn: (viewModel.ritualSessionSummary?.completedSessions ?? 0) > 0)
                        ProfileBrandStateTile(title: "Foco", value: "\(viewModel.ritualSessionSummary?.totalFocusMinutes ?? 0)m", symbol: "timer", isOn: (viewModel.ritualSessionSummary?.totalFocusMinutes ?? 0) > 0)
                        ProfileBrandStateTile(title: "Racha", value: "\(viewModel.ritualSessionSummary?.currentStreakDays ?? 0)d", symbol: "flame", isOn: (viewModel.ritualSessionSummary?.currentStreakDays ?? 0) > 0)
                    }
                }
            }
        }
    }

    private var systemPanel: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Estado del sistema")
                    .font(.custom("Helvetica", size: 20).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ProfileBrandStateTile(title: "Cuenta", value: authViewModel.authUser?.status.capitalized ?? "Sin login", symbol: "person.crop.circle", isOn: authViewModel.authUser?.status == "active")
                    ProfileBrandStateTile(title: "Email", value: authViewModel.authUser?.emailVerified == true ? "Verificado" : "Pendiente", symbol: "envelope", isOn: authViewModel.authUser?.emailVerified == true)
                    ProfileBrandStateTile(title: "Screen Time", value: viewModel.authorizationStatusText, symbol: "shield", isOn: viewModel.isAuthorized)
                    ProfileBrandStateTile(title: "Scheduler", value: viewModel.selectedScheduler?.title ?? "Ninguno", symbol: "calendar", isOn: viewModel.selectedScheduler != nil)
                    ProfileBrandStateTile(title: "Bloqueo", value: viewModel.blockedUntil == nil ? "No activo" : "Activo", symbol: "lock", isOn: viewModel.blockedUntil != nil)
                    ProfileBrandStateTile(title: "Tag", value: viewModel.nfcTagStatusText, symbol: "tag", isOn: viewModel.hasClaimedNfcTag)
                }
            }
        }
    }

    private var nfcTagPanel: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(viewModel.hasClaimedNfcTag ? RituoPalette.mistBlue.opacity(0.18) : RituoPalette.white.opacity(0.08))
                            .frame(width: 58, height: 58)

                        Image(systemName: viewModel.hasClaimedNfcTag ? "tag.fill" : "tag")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(viewModel.hasClaimedNfcTag ? RituoPalette.mistBlue : RituoPalette.white.opacity(0.72))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tag NFC")
                            .font(.custom("Helvetica", size: 20).weight(.bold))
                            .foregroundStyle(RituoPalette.white)

                        Text(viewModel.nfcTagStatusText)
                            .font(.custom("Helvetica", size: 13).weight(.bold))
                            .foregroundStyle(RituoPalette.mistBlue.opacity(0.82))

                        Text("Este tag va a funcionar como llave fisica para detener rituales protegidos.")
                            .font(.custom("Helvetica", size: 12).weight(.medium))
                            .foregroundStyle(RituoPalette.white.opacity(0.58))
                            .lineSpacing(3)
                    }

                    Spacer()
                }

                if !viewModel.nfcTagClaims.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(viewModel.nfcTagClaims) { claim in
                            HStack(spacing: 12) {
                                Image(systemName: "wave.3.right.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(RituoPalette.mistBlue)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(claim.label ?? "Tag vinculado")
                                    .font(.custom("Helvetica", size: 13).weight(.bold))
                                    .foregroundStyle(RituoPalette.white.opacity(0.88))

                                    Text(lastSeenText(for: claim))
                                        .font(.custom("Helvetica", size: 10).weight(.semibold))
                                        .foregroundStyle(RituoPalette.white.opacity(0.48))
                                }

                                Spacer()

                                Button {
                                    tagPendingRename = claim
                                    tagRenameText = claim.label ?? ""
                                    isRenameAlertPresented = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(RituoPalette.mistBlue)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(RituoPalette.white.opacity(0.07)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Renombrar \(claim.label ?? "tag")")

                                Button {
                                    tagPendingRevocation = claim
                                    isRevokeConfirmationPresented = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(RituoPalette.danger)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(RituoPalette.white.opacity(0.07)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Desvincular \(claim.label ?? "tag")")
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
                        }
                    }
                }

                if let tagMessage = viewModel.tagMessage {
                    Text(tagMessage)
                        .font(.custom("Helvetica", size: 12).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.66))
                        .lineLimit(3)
                }

                Button {
                    if let accessToken = authViewModel.accessToken {
                        viewModel.claimTag(accessToken: accessToken)
                    } else {
                        viewModel.tagMessage = "Inicia sesion para vincular un tag."
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isReadingTag {
                            ProgressView()
                                .tint(RituoPalette.deepOceanBlue)
                        } else {
                            Image(systemName: viewModel.hasClaimedNfcTag ? "arrow.triangle.2.circlepath" : "wave.3.right.circle.fill")
                        }

                        Text(viewModel.hasClaimedNfcTag ? "Reemplazar tag" : "Vincular tag")
                    }
                    .font(.custom("Helvetica", size: 16).weight(.bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RituoPalette.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(LoginPressButtonStyle())
                .disabled(viewModel.isReadingTag)
            }
        }
    }

    private func lastSeenText(for claim: NfcTagClaimResponse) -> String {
        guard let lastSeenAt = claim.lastSeenAt else {
            return "Todavía no utilizado"
        }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: lastSeenAt) ?? {
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: lastSeenAt)
        }()

        guard let date else {
            return "Vinculado"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.unitsStyle = .full
        return "Usado \(formatter.localizedString(for: date, relativeTo: .now))"
    }

    private var sessionPanel: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sesion")
                    .font(.custom("Helvetica", size: 20).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("Tu cuenta sincroniza el perfil y los tokens de Rituo para futuras APIs.")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.66))
                    .lineSpacing(3)

                Button {
                    authViewModel.signOut()
                } label: {
                    Label("Cerrar sesion", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.custom("Helvetica", size: 16).weight(.bold))
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RituoPalette.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(LoginPressButtonStyle())
            }
        }
    }

    private var displayName: String {
        let candidate = authViewModel.authUser?.displayName ?? authViewModel.profileDisplayName
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Perfil"
        }
        return candidate
    }

    private var nameParts: (first: String, last: String) {
        let parts = displayName.split(separator: " ").map(String.init)
        guard displayName != "Perfil", !parts.isEmpty else {
            return ("Sin nombre", "Sin apellido")
        }

        if parts.count == 1 {
            return (parts[0], "Sin apellido")
        }

        return (parts[0], parts.dropFirst().joined(separator: " "))
    }

    private var initials: String {
        if displayName == "Perfil" {
            return "R"
        }

        let letters = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return letters.isEmpty ? "R" : letters
    }

    private var authProviderText: String {
        authViewModel.authProvider?.displayName ?? "No detectado"
    }
}

struct ProfileBrandBadge: View {
    let text: String
    let isOn: Bool

    var body: some View {
        Text(text)
            .font(.custom("Helvetica", size: 11).weight(.bold))
            .foregroundStyle(isOn ? RituoPalette.deepOceanBlue : RituoPalette.white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(isOn ? RituoPalette.mistBlue.opacity(0.88) : RituoPalette.white.opacity(0.12)))
            .overlay {
                Capsule().stroke(RituoPalette.white.opacity(isOn ? 0.44 : 0.10), lineWidth: 1)
            }
    }
}

struct ProfileDarkRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
            Spacer()
            Text(value)
                .font(.custom("Helvetica", size: 13).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
        }
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
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isOn ? RituoPalette.mistBlue : RituoPalette.white.opacity(0.62))
                Spacer()
                Circle()
                    .fill(isOn ? RituoPalette.mistBlue : RituoPalette.white.opacity(0.24))
                    .frame(width: 8, height: 8)
            }

            Text(title)
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.62))

            Text(value)
                .font(.custom("Helvetica", size: 14).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(2)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RituoPalette.mistBlue.opacity(0.11), lineWidth: 1)
        }
    }
}

struct ProfileMetricLoadingTile: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RituoLoadingBar(width: 24, height: 16)
                Spacer()
                Circle()
                    .fill(RituoPalette.white.opacity(0.20))
                    .frame(width: 8, height: 8)
            }

            Text(title)
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.48))

            RituoLoadingBar(width: 56, height: 16)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
    }
}

struct ProfileHeader: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        FuturisticCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    ProfileAvatar(
                        imageURL: authViewModel.profileImageURL,
                        initials: initials
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Text(displayName)
                            .font(.custom("Helvetica", size: 30).weight(.semibold))
                            .foregroundStyle(RituoPalette.text)
                            .lineLimit(2)

                        Text(authViewModel.authUser?.email ?? "Inicia sesion para cargar tu perfil")
                            .font(.custom("Helvetica", size: 14).weight(.medium))
                            .foregroundStyle(RituoPalette.subtext)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            InlineBadge(
                                text: authViewModel.authUser?.status == "active" ? "Activo" : "Sin sesion",
                                tint: authViewModel.authUser?.status == "active" ? RituoPalette.success : RituoPalette.dimText
                            )

                            InlineBadge(
                                text: authViewModel.authUser?.emailVerified == true ? "Email verificado" : "Email pendiente",
                                tint: authViewModel.authUser?.emailVerified == true ? RituoPalette.success : RituoPalette.dimText
                            )
                        }
                    }
                }

                VStack(spacing: 10) {
                    ProfileIdentityRow(label: "Nombre", value: nameParts.first)
                    ProfileIdentityRow(label: "Apellido", value: nameParts.last)
                    ProfileIdentityRow(label: "Mail", value: authViewModel.authUser?.email ?? "Sin mail")
                }
            }
        }
    }

    private var displayName: String {
        let candidate = authViewModel.authUser?.displayName ?? authViewModel.profileDisplayName
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Perfil"
        }
        return candidate
    }

    private var nameParts: (first: String, last: String) {
        let parts = displayName.split(separator: " ").map(String.init)
        guard displayName != "Perfil", !parts.isEmpty else {
            return ("Sin nombre", "Sin apellido")
        }

        if parts.count == 1 {
            return (parts[0], "Sin apellido")
        }

        return (parts[0], parts.dropFirst().joined(separator: " "))
    }

    private var initials: String {
        if displayName == "Perfil" {
            return "R"
        }

        let letters = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return letters.isEmpty ? "R" : letters
    }
}

struct ProfileAvatar: View {
    let imageURL: URL?
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(RituoPalette.softPanel)
                .frame(width: 88, height: 88)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
            } else {
                fallback
                    .frame(width: 82, height: 82)
            }
        }
        .overlay {
            Circle()
                .stroke(RituoPalette.stroke, lineWidth: 1)
        }
        .shadow(color: RituoPalette.glow.opacity(0.16), radius: 20, y: 10)
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(RituoPalette.glow.opacity(0.15))

            Text(initials)
                .font(.custom("Helvetica", size: 28).weight(.bold))
                .foregroundStyle(RituoPalette.text)
        }
    }
}

struct AuthAccountPanel: View {
    @ObservedObject var authViewModel: AuthViewModel
    var showsDiagnostics = true

    var body: some View {
        FuturisticCard {
            VStack(alignment: .leading, spacing: 14) {
                PanelEyebrow(authViewModel.isAuthenticated ? "Sesion" : "Login")

                if authViewModel.isAuthenticated {
                    Button {
                        authViewModel.signOut()
                    } label: {
                        Label("Cerrar sesion", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.custom("Helvetica", size: 15).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RituoPalette.danger)
                } else {
                    loginButtons
                }

                if showsDiagnostics {
                    diagnosticsRow
                }

                if let successMessage = authViewModel.successMessage {
                    MessageStrip(text: successMessage, tint: RituoPalette.success)
                }

                if let errorMessage = authViewModel.errorMessage {
                    MessageStrip(text: errorMessage, tint: RituoPalette.danger)
                }
            }
        }
    }

    private var loginButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    handleAppleCompletion(result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                authViewModel.signInWithGoogle()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                        Button {
                            authViewModel.signInWithGoogle()
                        } label: {
                            HStack(spacing: 12) {
                                GoogleIcon()
                                    .frame(width: 22, height: 22)

                                Text("Continuar con Google")
                                    .font(.custom("Helvetica", size: 16).weight(.semibold))
                                    .foregroundStyle(RituoPalette.text)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RituoPalette.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RituoPalette.stroke, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                            .font(.custom("Helvetica", size: 24).weight(.semibold))
                            .foregroundStyle(Color(red: 0.22, green: 0.48, blue: 0.96))
                    }

                    Text("Continuar con Google")
                        .font(.custom("Helvetica", size: 16).weight(.bold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white)
            .background(
                LinearGradient(
                    colors: [
                        RituoPalette.deepOceanBlue,
                        RituoPalette.darkCanteen
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(RituoPalette.stroke, lineWidth: 1)
            }
        }
    }

    private var diagnosticsRow: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await authViewModel.runHealthCheck()
                }
            } label: {
                Label("Health", systemImage: "waveform.path.ecg")
                    .font(.custom("Helvetica", size: 13).weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(RituoPalette.glow)

            Button {
                Task {
                    await authViewModel.getCurrentUser()
                }
            } label: {
                Label("/auth/me", systemImage: "person.text.rectangle")
                    .font(.custom("Helvetica", size: 13).weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(RituoPalette.accent)
            .disabled(authViewModel.accessToken == nil)

            if authViewModel.isLoading {
                ProgressView()
                    .tint(RituoPalette.glow)
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
            authViewModel.errorMessage = "Sign in with Apple fallo: \(error.localizedDescription)"
        }
    }
}
