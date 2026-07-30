import FamilyControls
import SwiftUI

struct RituoRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var familyAuthorizationCenter = AuthorizationCenter.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var blockViewModel = BlockSetupViewModel()
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
            if authViewModel.isRestoringSession {
                RituoSessionRestoreView()
            } else if authViewModel.isAuthenticated {
                if !authViewModel.hasCheckedLegalRequirements {
                    LegalRequirementsLoadingView(authViewModel: authViewModel)
                } else if authViewModel.legalRequirements?.requiresAcceptance == true {
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
        .task(id: authViewModel.accessToken) {
            blockViewModel.updateAccessToken(authViewModel.accessToken)
            blockViewModel.configureAppReviewAccount(
                email: authViewModel.authUser?.email
            )
            if authViewModel.accessToken != nil {
                await authViewModel.loadLegalRequirements()
            } else {
                blockViewModel.clearAuthenticatedState()
                selectedTab = .home
            }
        }
        .task {
            await checkForAppUpdate()
        }
        .task(id: authViewModel.legalAccessTaskID) {
            guard authViewModel.canEnterAuthenticatedApp,
                  let accessToken = authViewModel.accessToken else {
                return
            }

                blockViewModel.updateAuthenticatedUserID(authViewModel.authUser?.id)
                blockViewModel.configureAppReviewAccount(
                    email: authViewModel.authUser?.email
                )
                await checkForSupportReset(accessToken: accessToken)
                await blockViewModel.loadCoreRituals(accessToken: accessToken)
                await blockViewModel.loadCoreModes(accessToken: accessToken)
                await blockViewModel.syncPendingDeviceActivityEvents(accessToken: accessToken)
                await blockViewModel.refreshFocusSessionState(accessToken: accessToken)
                blockViewModel.reconcileActiveFocusSession()
                await blockViewModel.loadFocusMetricsSummary(accessToken: accessToken)
                await blockViewModel.loadNfcTagClaims(accessToken: accessToken)
        }
        .task(id: authViewModel.authUser?.id) {
            blockViewModel.updateAuthenticatedUserID(authViewModel.authUser?.id)
            await restoreProtectionAuthorizationIfNeeded()
            blockViewModel.reconcileActiveFocusSession()
        }
        .onChange(of: blockViewModel.nfcTagSetupRequestID) { _, requestID in
            guard requestID != nil else { return }
            isNfcRequiredSheetPresented = true
        }
        .onChange(of: scenePhase) { _, phase in
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
                        blockViewModel.updateAuthenticatedUserID(authViewModel.authUser?.id)
                        await checkForSupportReset(accessToken: accessToken)
                        await blockViewModel.loadCoreRituals(accessToken: accessToken)
                        await blockViewModel.loadCoreModes(accessToken: accessToken)
                        await blockViewModel.syncPendingDeviceActivityEvents(accessToken: accessToken)
                        await blockViewModel.refreshFocusSessionState(accessToken: accessToken)
                        blockViewModel.reconcileActiveFocusSession()
                        await blockViewModel.loadFocusMetricsSummary(accessToken: accessToken)
                        await blockViewModel.loadNfcTagClaims(accessToken: accessToken)
                    }
                }
            }
        }
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
        selectedPage
            .overlay(alignment: .bottom) {
                RituoFloatingTabBar(selectedTab: $selectedTab)
            }
            .overlay(alignment: .top) {
                RituoTopChromeFade()
                    .allowsHitTesting(false)
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
    @State private var breathes = false
    @State private var rotates = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            // Glow central
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            RituoPalette.white.opacity(breathes ? 0.30 : 0.14),
                            RituoPalette.lightBlue.opacity(breathes ? 0.16 : 0.06),
                            Color.clear
                        ],
                        center: .center, startRadius: 0, endRadius: 160
                    )
                )
                .frame(width: 340, height: 340)
                .blur(radius: 46)
                .scaleEffect(breathes ? 1.08 : 0.92)
                .allowsHitTesting(false)

            VStack(spacing: 28) {
                ZStack {
                    // Anillo orbital
                    Circle()
                        .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 168, height: 168)

                    // Arco giratorio
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(
                            LinearGradient(
                                colors: [.clear, RituoPalette.white.opacity(0.85), RituoPalette.lightBlue.opacity(0.5), .clear],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 168, height: 168)
                        .rotationEffect(.degrees(rotates ? 360 : 0))
                        .shadow(color: RituoPalette.white.opacity(0.60), radius: 8)

                    Image("RituoLogoWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128)
                        .shadow(color: RituoPalette.white.opacity(0.30), radius: 26)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.88)

                Text("Preparando tu espacio de foco")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.42))
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathes = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotates = true
            }
        }
    }
}

#Preview {
    RituoRootView()
}
