import FamilyControls
import SwiftUI

struct RituoRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var blockViewModel = BlockSetupViewModel()
    @State private var selectedTab: RootTab = .home

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                RituoSessionRestoreView()
            } else if authViewModel.isAuthenticated {
                mainTabs
                    .familyActivityPicker(
                        isPresented: $blockViewModel.isPickerPresented,
                        selection: $blockViewModel.selection
                    )
            } else {
                LoginLandingView(authViewModel: authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: authViewModel.isAuthenticated)
        .task(id: authViewModel.accessToken) {
            blockViewModel.updateAccessToken(authViewModel.accessToken)
            if let accessToken = authViewModel.accessToken {
                await blockViewModel.loadCoreRituals(accessToken: accessToken)
                await blockViewModel.syncPendingDeviceActivityEvents(accessToken: accessToken)
                await blockViewModel.loadActiveRitualSession(accessToken: accessToken)
                await blockViewModel.loadRitualSessionSummary(accessToken: accessToken)
                await blockViewModel.loadRitualSessionHistories(accessToken: accessToken)
                await blockViewModel.loadNfcTagClaims(accessToken: accessToken)
            } else {
                blockViewModel.clearAuthenticatedState()
                selectedTab = .home
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                blockViewModel.refreshScheduledRitualState()
                if let accessToken = authViewModel.accessToken {
                    Task {
                        await blockViewModel.syncPendingDeviceActivityEvents(accessToken: accessToken)
                        await blockViewModel.loadActiveRitualSession(accessToken: accessToken)
                        await blockViewModel.loadRitualSessionSummary(accessToken: accessToken)
                        await blockViewModel.loadRitualSessionHistories(accessToken: accessToken)
                        await blockViewModel.loadNfcTagClaims(accessToken: accessToken)
                    }
                }
            }
        }
    }

    private var mainTabs: some View {
        selectedPage
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
            FocusSetupPage(viewModel: blockViewModel)
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

struct RituoSessionRestoreView: View {
    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            VStack(spacing: 18) {
                Image("RituoLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)

                ProgressView()
                    .tint(RituoPalette.white)
            }
        }
    }
}

#Preview {
    RituoRootView()
}
