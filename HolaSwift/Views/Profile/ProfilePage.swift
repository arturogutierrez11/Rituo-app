import SwiftUI
import UserNotifications

struct ProfilePage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedLegalDocument: LegalDocumentResponse?
    @State private var isSignOutConfirmationPresented = false
    @State private var isSettingsPresented = false
    @State private var settingsScrollAnchor: ProfileSettingsSection?
    @State private var appeared = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    private let notificationService = RitualNotificationService()

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader
                        .opacity(appeared ? 1 : 0)

                    avatarBlock
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.05), value: appeared)

                    settingsEntryCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.09), value: appeared)

                    systemCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.13), value: appeared)

                    legalCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.17), value: appeared)

                    aboutCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.21), value: appeared)

                    signOutButton
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.50, dampingFraction: 0.82).delay(0.24), value: appeared)
                }
                .padding(.horizontal, 20)
                .padding(.top, 62)
                .padding(.bottom, 140)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.40).delay(0.08)) { appeared = true }
            presentSettingsIfRequested()
        }
        .task {
            notificationStatus = await notificationService.authorizationStatus()
        }
        .onChange(of: viewModel.nfcTagSetupRequestID) { _, requestID in
            guard requestID != nil else { return }
            presentSettingsIfRequested()
        }
        .sheet(item: $selectedLegalDocument) { document in
            LegalDocumentDetailView(document: document)
        }
        .sheet(isPresented: $isSignOutConfirmationPresented) {
            RituoBottomActionSheet(
                symbol: "rectangle.portrait.and.arrow.right",
                tint: RituoPalette.danger,
                title: "Cerrar sesión",
                message: "Vas a salir de tu cuenta en este dispositivo. Tus rituales, modos y datos guardados seguirán asociados a tu cuenta.",
                actions: [
                    RituoBottomSheetAction(title: "Cerrar sesión", symbol: "rectangle.portrait.and.arrow.right", style: .destructive) {
                        isSignOutConfirmationPresented = false
                        if viewModel.hasClaimedNfcTag {
                            viewModel.validateTagForSensitiveAction(
                                accessToken: authViewModel.accessToken,
                                actionDescription: "cerrar sesión",
                                alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para cerrar sesión."
                            ) {
                                signOutAndReleaseRestrictions()
                            }
                        } else {
                            signOutAndReleaseRestrictions()
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        isSignOutConfirmationPresented = false
                    }
                ]
            )
        }
        .sheet(isPresented: $isSettingsPresented) {
            ProfileSettingsView(
                viewModel: viewModel,
                authViewModel: authViewModel,
                scrollAnchor: settingsScrollAnchor
            )
        }
    }

    private func presentSettingsIfRequested() {
        guard viewModel.nfcTagSetupRequestID != nil else { return }

        DispatchQueue.main.async {
            settingsScrollAnchor = .tag
            isSettingsPresented = true
            viewModel.consumeNfcTagSetupRequest()
        }
    }

    private func signOutAndReleaseRestrictions() {
        viewModel.clearAuthenticatedState()
        authViewModel.signOut()
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Perfil")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                HStack(spacing: 14) {
                    miniStat(value: focusTotalText, label: "foco")
                    dot()
                    miniStat(value: "\(viewModel.focusMetricsSummary?.completedSessions ?? 0)", label: "sesiones")
                    dot()
                    miniStat(value: "\(viewModel.focusMetricsSummary?.currentStreakDays ?? 0)d", label: "racha")
                }
            }
            Spacer()
        }
    }

    // MARK: - Avatar block

    private var avatarBlock: some View {
        VStack(spacing: 14) {
            ProfileAvatar(imageURL: authViewModel.profileImageURL, initials: initials)

            VStack(spacing: 4) {
                Text(displayName == "Perfil" ? "Tu perfil" : displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
                Text(authViewModel.authUser?.email ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(RituoPalette.white.opacity(0.40))

                if viewModel.isAppReviewAccount {
                    Label("Cuenta de demostración", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RituoPalette.lightBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RituoPalette.lightBlue.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(profileCardBg)
    }

    // MARK: - Settings entry card

    private var settingsEntryCard: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Configuración")
            VStack(spacing: 0) {
                Button {
                    settingsScrollAnchor = .protection
                    isSettingsPresented = true
                } label: {
                    profileLinkRowFn(
                        symbol: "lock.shield",
                        label: "Protección",
                        detail: protectionStatusText
                    )
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    settingsScrollAnchor = .emergency
                    isSettingsPresented = true
                } label: {
                    profileLinkRowFn(
                        symbol: "lock.open.trianglebadge.exclamationmark",
                        label: "Emergencias",
                        detail: viewModel.emergencyUnlockAvailabilityText
                    )
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    settingsScrollAnchor = .tag
                    isSettingsPresented = true
                } label: {
                    profileLinkRowFn(symbol: "wave.3.right", label: "Tag NFC",
                                     detail: viewModel.hasClaimedNfcTag ? "Vinculado" : "Sin vincular")
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    settingsScrollAnchor = .account
                    isSettingsPresented = true
                } label: {
                    profileLinkRowFn(
                        symbol: "person",
                        label: "Cuenta",
                        detail: nameParts.first
                    )
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    settingsScrollAnchor = .support
                    isSettingsPresented = true
                } label: {
                    profileLinkRowFn(
                        symbol: "questionmark.circle",
                        label: "Soporte",
                        detail: "Contacto y redes"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(profileCardBg)
        }
    }

    // MARK: - System card

    private var systemCard: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Estado")
            VStack(spacing: 0) {
                profileStatusRow(symbol: "person.crop.circle", label: "Cuenta",
                                 value: authViewModel.authUser?.status.capitalized ?? "Sin login",
                                 isOn: authViewModel.authUser?.status == "active")
                profileRowDivider
                profileStatusRow(symbol: "envelope", label: "Email",
                                 value: authViewModel.authUser?.emailVerified == true ? "Verificado" : "Pendiente",
                                 isOn: authViewModel.authUser?.emailVerified == true)
                profileRowDivider
                profileStatusRow(symbol: "shield", label: "Screen Time",
                                 value: viewModel.authorizationStatusText,
                                 isOn: viewModel.isAuthorized)
                profileRowDivider
                Button {
                    Task { await configureNotifications() }
                } label: {
                    profileStatusRow(
                        symbol: "bell",
                        label: "Notificaciones",
                        value: notificationStatusText,
                        isOn: notificationsEnabled
                    )
                }
                .buttonStyle(.plain)
                profileRowDivider
                profileStatusRow(symbol: "tag", label: "Tag NFC",
                                 value: viewModel.nfcTagStatusText,
                                 isOn: viewModel.hasClaimedNfcTag)
                profileRowDivider
                if viewModel.failedSyncCount > 0 {
                    Button {
                        viewModel.retryFailedSyncOperations()
                    } label: {
                        profileLinkRowFn(
                            symbol: "arrow.clockwise",
                            label: "Sincronización",
                            detail: "\(viewModel.failedSyncCount) con error"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    profileStatusRow(
                        symbol: "arrow.triangle.2.circlepath",
                        label: "Sincronización",
                        value: syncStatusText,
                        isOn: viewModel.pendingSyncCount == 0
                    )
                }
            }
            .background(profileCardBg)
        }
    }

    private var notificationsEnabled: Bool {
        [.authorized, .provisional, .ephemeral].contains(notificationStatus)
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:
            return "Activadas"
        case .provisional:
            return "Silenciosas"
        case .ephemeral:
            return "Temporales"
        case .denied:
            return "Desactivadas"
        case .notDetermined:
            return "Configurar"
        @unknown default:
            return "Revisar"
        }
    }

    private func configureNotifications() async {
        if notificationStatus == .notDetermined {
            _ = await notificationService.requestAuthorization()
            notificationStatus = await notificationService.authorizationStatus()
            return
        }

        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        await UIApplication.shared.open(settingsURL)
        notificationStatus = await notificationService.authorizationStatus()
    }

    // MARK: - Legal card

    private var legalCard: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Legal")
            VStack(spacing: 0) {
                ForEach(Array(legalDocuments.enumerated()), id: \.element.id) { index, document in
                    Button { selectedLegalDocument = document } label: {
                        profileLinkRowFn(
                            symbol: document.type == .terms ? "doc.text" : "lock.shield",
                            label: document.type.displayName,
                            detail: "v\(document.version)"
                        )
                    }
                    .buttonStyle(.plain)

                    if index < legalDocuments.count - 1 {
                        profileRowDivider
                    }
                }

                if !legalDocuments.isEmpty {
                    profileRowDivider
                }

                profileLinkRowFn(symbol: "text.justify.left", label: "Licencias open source", detail: nil)
            }
            .background(profileCardBg)
        }
    }

    // MARK: - About card

    private var aboutCard: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Acerca de")
            VStack(spacing: 0) {
                profileInfoRow(symbol: "info.circle", label: "Versión", value: appVersion)
                profileRowDivider
                profileInfoRow(symbol: "applescript", label: "Build", value: appBuild)
                profileRowDivider
                Button { } label: {
                    profileLinkRowFn(symbol: "square.and.arrow.up", label: "Compartir Rituo", detail: nil)
                }
                .buttonStyle(.plain)
            }
            .background(profileCardBg)
        }
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button { isSignOutConfirmationPresented = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Text("Cerrar sesión")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(RituoPalette.danger)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RituoPalette.danger.opacity(0.09))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RituoPalette.danger.opacity(0.20), lineWidth: 1)
                    }
            )
        }
        .buttonStyle(LoginPressButtonStyle())
        .padding(.top, 4)
    }

    private func miniStat(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
        }
    }

    private func dot() -> some View {
        Circle().fill(RituoPalette.white.opacity(0.16)).frame(width: 3, height: 3)
    }

    // MARK: - Computed

    private var legalDocuments: [LegalDocumentResponse] {
        (authViewModel.legalRequirements?.documents ?? []).sorted { left, right in
            left.type == .terms && right.type == .privacy
        }
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

    private var protectionStatusText: String {
        let activeProtectionCount = [
            viewModel.isStrictModeEnabled,
            viewModel.isAppInstallationBlockingEnabled,
            viewModel.isSensitiveWebContentBlockingEnabled
        ].filter { $0 }.count

        switch activeProtectionCount {
        case 3:
            return "3 protecciones activas"
        case 2:
            return "2 protecciones activas"
        case 1:
            return "1 protección activa"
        default:
            return "Configurar"
        }
    }

    private var syncStatusText: String {
        if viewModel.pendingSyncCount == 0 {
            return "Al día"
        }
        return viewModel.pendingSyncCount == 1
            ? "1 pendiente"
            : "\(viewModel.pendingSyncCount) pendientes"
    }

    private var focusTotalText: String {
        let mins = viewModel.focusMetricsSummary?.totalFocusMinutes ?? 0
        let h = mins / 60; let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(mins)m"
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var appBuild: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }

}

// MARK: - File-level profile UI helpers

func profileInfoRow(symbol: String, label: String, value: String) -> some View {
    HStack(spacing: 14) {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(RituoPalette.white.opacity(0.35))
            .frame(width: 22)
        Text(label)
            .font(.system(size: 15))
            .foregroundStyle(RituoPalette.white.opacity(0.80))
        Spacer()
        Text(value)
            .font(.system(size: 14))
            .foregroundStyle(RituoPalette.white.opacity(0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
}

func profileLinkRowFn(symbol: String, label: String, detail: String?) -> some View {
    HStack(spacing: 14) {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(RituoPalette.white.opacity(0.35))
            .frame(width: 22)
        Text(label)
            .font(.system(size: 15))
            .foregroundStyle(RituoPalette.white.opacity(0.80))
        Spacer()
        if let detail {
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.30))
        }
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RituoPalette.white.opacity(0.18))
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .contentShape(Rectangle())
}

func profileStatusRow(symbol: String, label: String, value: String, isOn: Bool) -> some View {
    HStack(spacing: 14) {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.28))
            .frame(width: 22)
        Text(label)
            .font(.system(size: 15))
            .foregroundStyle(RituoPalette.white.opacity(0.80))
        Spacer()
        Text(value)
            .font(.system(size: 13))
            .foregroundStyle(RituoPalette.white.opacity(0.35))
            .lineLimit(1)
        Circle()
            .fill(isOn ? Color(red: 0.30, green: 0.90, blue: 0.52) : RituoPalette.white.opacity(0.18))
            .frame(width: 6, height: 6)
            .shadow(color: Color.green.opacity(isOn ? 0.55 : 0), radius: 4)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
}

var profileRowDivider: some View {
    Rectangle()
        .fill(RituoPalette.white.opacity(0.05))
        .frame(height: 1)
        .padding(.leading, 54)
}

func profileSectionLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(RituoPalette.white.opacity(0.28))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .padding(.bottom, 7)
        .padding(.top, 4)
}

var profileCardBg: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
}

// MARK: - Profile Avatar

struct ProfileAvatar: View {
    let imageURL: URL?
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.18, green: 0.24, blue: 0.38))
                .frame(width: 84, height: 84)
                .shadow(color: RituoPalette.lightBlue.opacity(0.18), radius: 16, y: 6)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: fallbackView
                    }
                }
                .frame(width: 76, height: 76).clipShape(Circle())
            } else {
                fallbackView.frame(width: 76, height: 76)
            }
        }
        .overlay {
            Circle().stroke(RituoPalette.white.opacity(0.14), lineWidth: 1.5)
        }
    }

    private var fallbackView: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Color(red: 0.28, green: 0.40, blue: 0.60), Color(red: 0.14, green: 0.20, blue: 0.34)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            Text(initials)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
        }
    }
}

// MARK: - Rituo physical NFC card

struct RituoPhysicalCard: View {
    let label: String?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.38, blue: 0.56),
                            Color(red: 0.17, green: 0.23, blue: 0.38),
                            Color(red: 0.10, green: 0.14, blue: 0.28)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06), Color.clear],
                        startPoint: UnitPoint(x: 0.2, y: 0),
                        endPoint: UnitPoint(x: 0.7, y: 0.55)
                    ))

                Image("RituoLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.44)
                    .opacity(0.08)
                    .position(x: geo.size.width * 0.57, y: geo.size.height * 0.54)

                Text("rituo")
                    .font(.custom("Helvetica", size: geo.size.height * 0.14).weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.top, geo.size.height * 0.14)
                    .padding(.leading, geo.size.width * 0.07)

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
    }
}

// MARK: - Legacy shared components (kept for compatibility)

struct ProfileBrandBadge: View {
    let text: String; let isOn: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.34)).frame(width: 6, height: 6)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(RituoPalette.white.opacity(isOn ? 0.90 : 0.60))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background { Capsule().fill(RituoPalette.white.opacity(isOn ? 0.14 : 0.07)) }
        .overlay { Capsule().stroke(RituoPalette.white.opacity(isOn ? 0.22 : 0.07), lineWidth: 1) }
    }
}

struct ProfileInfoChip: View {
    let title: String; let value: String; let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RituoPalette.mistBlue.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.88))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(RituoPalette.white.opacity(0.40))
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(RituoPalette.white.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 70)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RituoPalette.white.opacity(0.07)) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RituoPalette.white.opacity(0.07), lineWidth: 1) }
    }
}

struct ProfileMailStrip: View {
    let email: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.82))
            Text(email).font(.system(size: 13, weight: .semibold)).foregroundStyle(RituoPalette.white.opacity(0.86)).lineLimit(1).minimumScaleFactor(0.66)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RituoPalette.white.opacity(0.07)) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RituoPalette.white.opacity(0.07), lineWidth: 1) }
    }
}

struct ProfileDarkRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(RituoPalette.white).lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
        .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(RituoPalette.white.opacity(0.06), lineWidth: 1) }
    }
}

struct ProfileBrandStateTile: View {
    let title: String; let value: String; let symbol: String; let isOn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill((isOn ? RituoPalette.lightBlue : RituoPalette.white).opacity(isOn ? 0.14 : 0.07)).frame(width: 34, height: 34)
                    Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(isOn ? RituoPalette.mistBlue : RituoPalette.white.opacity(0.50))
                }
                Spacer()
                Circle().fill(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.18)).frame(width: 7, height: 7)
                    .shadow(color: RituoPalette.lightBlue.opacity(isOn ? 0.52 : 0), radius: 6)
            }
            Text(title).font(.system(size: 11)).foregroundStyle(RituoPalette.white.opacity(0.50))
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(RituoPalette.white).lineLimit(2).minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(16)
        .background { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RituoPalette.white.opacity(0.07)) }
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RituoPalette.white.opacity(0.08), lineWidth: 1) }
    }
}

struct ProfileMetricLoadingTile: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { RituoLoadingBar(width: 24, height: 14); Spacer() }
            Text(title).font(.system(size: 11)).foregroundStyle(RituoPalette.white.opacity(0.45))
            RituoLoadingBar(width: 56, height: 14)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
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
