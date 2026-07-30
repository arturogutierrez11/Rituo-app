import SwiftUI

// MARK: - Profile Settings

enum ProfileSettingsSection { case protection, emergency, tag, account, support }

struct ProfileSettingsView: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel
    let scrollAnchor: ProfileSettingsSection?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                settingsNavigationBar

                Rectangle()
                    .fill(RituoPalette.white.opacity(0.06))
                    .frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            ProtectionSettingsView(
                                viewModel: viewModel,
                                authViewModel: authViewModel
                            )
                            .id(ProfileSettingsSection.protection)

                            TagSettingsView(
                                viewModel: viewModel,
                                authViewModel: authViewModel
                            )
                            .id(ProfileSettingsSection.tag)

                            AccountSettingsView(
                                viewModel: viewModel,
                                authViewModel: authViewModel
                            )
                            .id(ProfileSettingsSection.account)

                            SupportSettingsView()
                                .id(ProfileSettingsSection.support)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        guard let anchor = scrollAnchor else { return }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                        }
                    }
                }
            }
        }
    }

    private var settingsNavigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.40))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(RituoPalette.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Configuración")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RituoPalette.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}
