import CoreHaptics
import FamilyControls
import SwiftUI
import UIKit

@MainActor
private final class InitialViewHapticPlayer {
    static let shared = InitialViewHapticPlayer()

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var hasPlayed = false

    private init() {}

    func playOnce() {
        guard !hasPlayed else { return }
        hasPlayed = true
        let span = AppDiagnostics.shared.begin("startup.haptics")
        defer { AppDiagnostics.shared.end("startup.haptics", span) }

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            return
        }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            try engine.start()

            let punch = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )
            let buzz = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ],
                relativeTime: 0.02,
                duration: 0.45
            )
            let pattern = try CHHapticPattern(events: [punch, buzz], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            self.engine = engine
            self.player = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
    }
}

struct RituoRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var familyAuthorizationCenter = AuthorizationCenter.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var blockViewModel = BlockSetupViewModel()
    @State private var refreshCoordinator = AsyncLoadCoordinator()
    @State private var selectedTab: RootTab = .home
    @State private var isNfcRequiredSheetPresented = false
    @State private var presentedAppUpdate: AppUpdateStatusResponse?
    @State private var appliedSupportReset: SupportResetResponse?
    @State private var isCheckingSupportReset = false
    @State private var protectionOnboardingRefreshID = 0
    private let protectionOnboardingStore = ProtectionOnboardingStore()
    @AppStorage("dismissedOptionalAppUpdateBuild")
    private var dismissedOptionalAppUpdateBuild = 0

    var body: some View {
        Group {
            if authViewModel.isRestoringSession || (authViewModel.isAuthenticated && !authViewModel.hasCheckedLegalRequirements) {
                RituoSessionRestoreView(authViewModel: authViewModel)
            } else if authViewModel.isAuthenticated {
                if authViewModel.legalRequirements?.requiresAcceptance == true {
                    LegalAcceptanceView(authViewModel: authViewModel)
                } else if shouldPresentProtectionOnboarding {
                    ProtectionOnboardingView(
                        isRecovery: isProtectionRecovery,
                        onCompleted: completeProtectionOnboarding,
                        onSignOut: authViewModel.signOut
                    )
                } else {
                mainTabs
                    .familyActivityPicker(
                        isPresented: $blockViewModel.isPickerPresented,
                        selection: $blockViewModel.selection
                    )
                    .overlay(alignment: .top) {
                        if authViewModel.isUsingOfflineSession {
                            OfflineSessionBanner()
                                .padding(.top, 58)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            } else {
                LoginLandingView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            AppDiagnostics.shared.event("root.appeared route=\(diagnosticRoute)")
        }
        .task(id: liveActivitySyncTrigger) {
            switch liveActivitySyncTrigger.state {
            case .waiting(let accountID):
                FocusLiveActivityService.shared.waitForSession(retainingAccountID: accountID)
            case .signedOut:
                FocusLiveActivityService.shared.synchronize(.init(active: nil, upcoming: nil))
            case .ready(let input):
                FocusLiveActivityService.shared.synchronize(input)
            }
        }
        .onChange(of: diagnosticRoute) { _, route in
            AppDiagnostics.shared.event("root.route=\(route)")
        }
        .animation(.easeInOut(duration: 0.24), value: authViewModel.isAuthenticated)
        .sheet(item: $presentedAppUpdate) { status in
            AppUpdateNoticeSheet(status: status)
        }
        .sheet(item: $appliedSupportReset) { _ in
            RituoBottomActionSheet(
                symbol: "checkmark.shield.fill",
                tint: RituoPalette.lightBlue,
                title: "Tu cuenta fue liberada",
                message: "Soporte restableció tu configuración y quitó las restricciones de este iPhone. Podés crear nuevamente tus rituales y modos.",
                actions: [
                    RituoBottomSheetAction(title: "Entendido") {
                        appliedSupportReset = nil
                    }
                ]
            )
        }
        .sheet(isPresented: $blockViewModel.isFocusSessionConflictPresented) {
            RituoBottomActionSheet(
                symbol: "clock.badge.exclamationmark",
                tint: RituoPalette.lightBlue,
                title: blockViewModel.focusSessionConflictTitle,
                message: blockViewModel.focusSessionConflictMessage,
                actions: [
                    RituoBottomSheetAction(title: "Entendido") {
                        blockViewModel.isFocusSessionConflictPresented = false
                    }
                ]
            )
        }
        .sheet(
            isPresented: Binding(
                get: { blockViewModel.reviewDemoTagPrompt != nil },
                set: { isPresented in
                    if !isPresented {
                        blockViewModel.cancelReviewDemoTagInteraction()
                    }
                }
            )
        ) {
            if let prompt = blockViewModel.reviewDemoTagPrompt {
                ReviewDemoTagSheet(
                    prompt: prompt,
                    onCompleted: blockViewModel.completeReviewDemoTagInteraction,
                    onCancelled: blockViewModel.cancelReviewDemoTagInteraction
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { blockViewModel.nfcErrorAlertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        blockViewModel.dismissNfcErrorAlert()
                    }
                }
            )
        ) {
            RituoBottomActionSheet(
                symbol: "wave.3.right.circle",
                tint: RituoPalette.danger,
                title: "No se pudo leer el NFC",
                message: blockViewModel.nfcErrorAlertMessage ?? "",
                actions: [
                    RituoBottomSheetAction(title: "Reintentar", symbol: "arrow.clockwise") {
                        blockViewModel.retryLastNfcAction()
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        blockViewModel.dismissNfcErrorAlert()
                    }
                ]
            )
        }
        .sheet(isPresented: $isNfcRequiredSheetPresented) {
            RituoBottomActionSheet(
                symbol: "wave.3.right",
                tint: RituoPalette.lightBlue,
                title: "Vinculá tu tag NFC",
                message: "Para iniciar un ritual o un modo necesitás tener una tarjeta vinculada a tu cuenta. Te llevamos a Perfil para configurarla.",
                actions: [
                    RituoBottomSheetAction(title: "Ir a Perfil", symbol: "arrow.right") {
                        isNfcRequiredSheetPresented = false
                        selectedTab = .profile
                    },
                    RituoBottomSheetAction(title: "Ahora no", style: .secondary) {
                        isNfcRequiredSheetPresented = false
                        blockViewModel.consumeNfcTagSetupRequest()
                    }
                ]
            )
        }
        .task(
            id: "\(authViewModel.accessToken ?? "signed-out"):\(authViewModel.isRestoringSession)"
        ) {
            blockViewModel.updateAccessToken(authViewModel.isRestoringSession ? nil : authViewModel.accessToken)
            blockViewModel.configureAppReviewAccount(
                email: authViewModel.authUser?.email
            )
            if !authViewModel.isRestoringSession, authViewModel.accessToken != nil {
                await authViewModel.loadLegalRequirements()
            } else if !authViewModel.isRestoringSession {
                blockViewModel.clearAuthenticatedState()
                selectedTab = .home
            }
        }
        .task {
            InitialViewHapticPlayer.shared.playOnce()
            await checkForAppUpdate()
        }
        .task(id: authViewModel.legalAccessTaskID) {
            guard authViewModel.canEnterAuthenticatedApp,
                  let accessToken = authViewModel.accessToken else {
                return
            }

            await refreshAuthenticatedContent(accessToken: accessToken)
        }
        .task(id: "\(authViewModel.authUser?.id ?? "signed-out"):\(authViewModel.isRestoringSession)") {
            guard !authViewModel.isRestoringSession else { return }
            blockViewModel.updateAccessToken(authViewModel.accessToken)
            blockViewModel.updateAuthenticatedUserID(authViewModel.authUser?.id)
            await restoreProtectionAuthorizationIfNeeded()
            blockViewModel.reconcileActiveFocusSession()
        }
        .onChange(of: blockViewModel.nfcTagSetupRequestID) { _, requestID in
            guard requestID != nil else { return }
            isNfcRequiredSheetPresented = true
        }
        .onChange(of: scenePhase) { _, phase in
            AppDiagnostics.shared.setActive(phase == .active)
            if phase == .active {
                protectionOnboardingRefreshID += 1
                Task {
                    await checkForAppUpdate()
                }
                blockViewModel.refreshScheduledRitualState()
                blockViewModel.refreshSafariContentBlockingState()
                if authViewModel.canEnterAuthenticatedApp,
                   let accessToken = authViewModel.accessToken {
                    Task {
                        await refreshAuthenticatedContent(accessToken: accessToken)
                    }
                }
            }
        }
    }

    private struct LiveActivitySyncTrigger: Equatable {
        var state: FocusLiveActivitySyncState
        var isForeground: Bool
    }

    private var liveActivitySyncTrigger: LiveActivitySyncTrigger {
        LiveActivitySyncTrigger(state: .resolve(
            isRestoring: authViewModel.isRestoringSession,
            authenticatedAccountID: authViewModel.isAuthenticated ? authViewModel.authUser?.id : nil,
            restoredAccountID: blockViewModel.liveActivityAccountID,
            hasCheckedLegal: authViewModel.hasCheckedLegalRequirements,
            canEnter: authViewModel.canEnterAuthenticatedApp,
            input: blockViewModel.liveActivityInput),
            isForeground: scenePhase == .active)
    }

    private func refreshAuthenticatedContent(accessToken: String) async {
        guard let userID = authViewModel.authUser?.id else { return }
        await refreshCoordinator.run(key: "\(userID):\(accessToken)") {
            let span = AppDiagnostics.shared.begin("sync.authenticated")
            defer { AppDiagnostics.shared.end("sync.authenticated", span) }
            @MainActor func isCurrent() -> Bool {
                authViewModel.canEnterAuthenticatedApp &&
                authViewModel.authUser?.id == userID && authViewModel.accessToken == accessToken
            }
            guard isCurrent() else { return }
            blockViewModel.updateAccessToken(accessToken)
            blockViewModel.updateAuthenticatedUserID(userID)
            blockViewModel.configureAppReviewAccount(email: authViewModel.authUser?.email)
            await checkForSupportReset(accessToken: accessToken)
            guard isCurrent() else { return }
            await blockViewModel.loadCoreRituals(accessToken: accessToken)
            guard isCurrent() else { return }
            await blockViewModel.loadCoreModes(accessToken: accessToken)
            guard isCurrent() else { return }
            await blockViewModel.syncPendingDeviceActivityEvents(accessToken: accessToken)
            guard isCurrent() else { return }
            await blockViewModel.refreshFocusSessionState(accessToken: accessToken)
            guard isCurrent() else { return }
            blockViewModel.reconcileActiveFocusSession()
            await blockViewModel.loadFocusMetricsSummary(accessToken: accessToken)
            guard isCurrent() else { return }
            await blockViewModel.loadNfcTagClaims(accessToken: accessToken)
        }
    }

    private var diagnosticRoute: String {
        if authViewModel.isRestoringSession { return "restoring" }
        if !authViewModel.isAuthenticated { return "login" }
        if !authViewModel.hasCheckedLegalRequirements { return "legal_loading" }
        if authViewModel.legalRequirements?.requiresAcceptance == true { return "legal_acceptance" }
        if shouldPresentProtectionOnboarding { return "protection" }
        return "tabs"
    }

    private var shouldPresentProtectionOnboarding: Bool {
        guard let userID = authViewModel.authUser?.id else { return false }
        _ = protectionOnboardingRefreshID

        if !protectionOnboardingStore.isCompleted(userID: userID) {
            return true
        }

        return familyAuthorizationCenter.authorizationStatus == .denied
    }

    private var isProtectionRecovery: Bool {
        guard let userID = authViewModel.authUser?.id else { return false }
        return protectionOnboardingStore.isCompleted(userID: userID) &&
            familyAuthorizationCenter.authorizationStatus == .denied
    }

    private func completeProtectionOnboarding() {
        guard let userID = authViewModel.authUser?.id,
              familyAuthorizationCenter.authorizationStatus == .approved else {
            return
        }

        protectionOnboardingStore.markCompleted(userID: userID)
        protectionOnboardingRefreshID += 1
    }

    private func restoreProtectionAuthorizationIfNeeded() async {
        guard let userID = authViewModel.authUser?.id,
              protectionOnboardingStore.isCompleted(userID: userID),
              familyAuthorizationCenter.authorizationStatus == .notDetermined else {
            return
        }

        do {
            try await familyAuthorizationCenter.requestAuthorization(for: .individual)
        } catch {
            print("Family Controls authorization restore error:", error)
        }
        protectionOnboardingRefreshID += 1
    }

    private func checkForAppUpdate() async {
        #if DEBUG
        // Local builds may keep an older build number while testing newer code.
        // App Store updates would replace that code and block device testing.
        presentedAppUpdate = nil
        #else
        do {
            let status = try await CoreApiService.shared.getAppUpdateStatus()
            guard status.updateAvailable else {
                presentedAppUpdate = nil
                return
            }

            if status.updateRequired ||
                status.latestBuild != dismissedOptionalAppUpdateBuild {
                presentedAppUpdate = status
            }
        } catch {
            print("App update status error:", error)
        }
        #endif
    }

    private func checkForSupportReset(accessToken: String) async {
        guard !isCheckingSupportReset,
              let userID = authViewModel.authUser?.id else {
            return
        }

        isCheckingSupportReset = true
        defer { isCheckingSupportReset = false }

        do {
            guard let reset = try await CoreApiService.shared
                .getPendingSupportReset(accessToken: accessToken) else {
                return
            }

            blockViewModel.applyRemoteSupportReset(
                userID: userID,
                preserveTag: !reset.revokeTag
            )
            try await CoreApiService.shared.acknowledgeSupportReset(
                accessToken: accessToken,
                requestId: reset.id
            )
            appliedSupportReset = reset
        } catch {
            print("Support reset error:", error)
        }
    }

    private var mainTabs: some View {
        ZStack(alignment: .bottom) {
            selectedPage
                .onAppear { AppDiagnostics.shared.event("page.appeared tab=\(selectedTab)") }
            RituoFloatingTabBar(selectedTab: $selectedTab)
        }
        .onAppear { AppDiagnostics.shared.event("tabs.appeared") }
        .onChange(of: selectedTab) { oldTab, newTab in
            AppDiagnostics.shared.event("navigation.selection from=\(oldTab) to=\(newTab)")
        }
        .overlay(alignment: .top) {
            RituoTopChromeFade().allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch selectedTab {
        case .home:
            RitualDashboardPage(
                viewModel: blockViewModel,
                accessToken: authViewModel.accessToken
            )
        case .rituals:
            SchedulerListPage(
                viewModel: blockViewModel,
                selectedTab: $selectedTab,
                accessToken: authViewModel.accessToken
            )
        case .focus:
            FocusSetupPage(
                viewModel: blockViewModel,
                accessToken: authViewModel.accessToken
            )
        case .ranking:
            RankingPage(accessToken: authViewModel.accessToken)
        case .profile:
            ProfilePage(
                viewModel: blockViewModel,
                authViewModel: authViewModel
            )
        }
    }
}

private struct RituoTopChromeFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                RituoPalette.deepOceanBlue.opacity(0.70),
                RituoPalette.darkCanteen.opacity(0.26),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 118)
        .ignoresSafeArea(edges: .top)
    }
}

private struct OfflineSessionBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .bold))

            Text("Sin conexión. Usando datos guardados.")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(RituoPalette.deepOceanBlue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(RituoPalette.white.opacity(0.94))
                .shadow(color: .black.opacity(0.20), radius: 18, x: 0, y: 10)
        )
    }
}

struct RituoSessionRestoreView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            RituoLaunchGlowBackground()

            Image("RituoLogoWhite")
                .resizable()
                .scaledToFit()
                .frame(width: 140)
                .accessibilityLabel("Rituo, cargando")
        }
        .overlay(alignment: .bottom) {
            if !authViewModel.isRestoringSession,
               !authViewModel.isLoadingLegalRequirements,
               let error = authViewModel.legalRequirementsError {
                VStack(spacing: 16) {
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                    Button("Volver a intentar") {
                        Task { await authViewModel.loadLegalRequirements() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cerrar sesión") { authViewModel.signOut() }
                        .foregroundStyle(.white)
                }
                .padding(28)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            AppDiagnostics.shared.event("restore_screen.appeared")
        }
    }
}


/// Composited gradients keep the launch animation lightweight; the logo is a separate layer.
private struct RituoLaunchGlowBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var illuminated = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Image("RituoAppBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)

                // Broad blue light fields move behind the stationary brand mark.
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.30, green: 0.72, blue: 1).opacity(0.48), .clear],
                        center: .center, startRadius: 0, endRadius: width * 0.65
                    ))
                    .frame(width: width * 1.5, height: height * 0.85)
                    .rotationEffect(.degrees(illuminated ? 24 : -22))
                    .offset(x: illuminated ? width * 0.25 : -width * 0.35,
                            y: illuminated ? -height * 0.18 : height * 0.26)
                    .blendMode(.screen)

                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.35, green: 0.46, blue: 1).opacity(0.38), .clear],
                        center: .center, startRadius: 0, endRadius: width * 0.55
                    ))
                    .frame(width: width * 1.3, height: height * 0.7)
                    .offset(x: illuminated ? -width * 0.3 : width * 0.3,
                            y: illuminated ? height * 0.28 : -height * 0.3)
                    .blendMode(.screen)

                // A soft diagonal sheen, with no flashes or particles.
                Rectangle()
                    .fill(LinearGradient(
                        stops: [.init(color: .clear, location: 0),
                                .init(color: Color(red: 0.66, green: 0.85, blue: 1).opacity(0.02), location: 0.35),
                                .init(color: Color(red: 0.66, green: 0.85, blue: 1).opacity(0.16), location: 0.5),
                                .init(color: .clear, location: 0.7)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: width * 1.1, height: height * 1.6)
                    .rotationEffect(.degrees(24))
                    .offset(x: illuminated ? width * 0.8 : -width * 0.8)
                    .blendMode(.screen)
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { illuminated = false }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                illuminated = true
            }
        }
    }
}

#Preview {
    RituoRootView()
}
