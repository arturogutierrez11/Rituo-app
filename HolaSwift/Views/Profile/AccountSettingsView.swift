import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteAccountIntroPresented = false
    @State private var showDeleteAccountAlert = false
    @State private var deleteAccountConfirmation = ""

    var body: some View {
        VStack(spacing: 14) {
            userSection
        }
        .sheet(isPresented: $isDeleteAccountIntroPresented) {
            RituoBottomActionSheet(
                symbol: "person.crop.circle.badge.minus",
                tint: RituoPalette.danger,
                title: "Eliminar cuenta",
                message: "Se perderán definitivamente tu cuenta, rituales, modos, sesiones, métricas y tags vinculados. Esta acción no se puede deshacer.",
                actions: [
                    RituoBottomSheetAction(title: "Continuar", symbol: "exclamationmark.triangle", style: .destructive) {
                        isDeleteAccountIntroPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showDeleteAccountAlert = true
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        isDeleteAccountIntroPresented = false
                    }
                ]
            )
        }
        .alert("Eliminar cuenta definitivamente", isPresented: $showDeleteAccountAlert) {
            TextField("Escribí ELIMINAR", text: $deleteAccountConfirmation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Eliminar cuenta", role: .destructive) {
                guard deleteAccountConfirmation == "ELIMINAR",
                      let userID = authViewModel.authUser?.id else {
                    return
                }
                deleteAccountConfirmation = ""

                if viewModel.hasClaimedNfcTag {
                    viewModel.validateTagForSensitiveAction(
                        accessToken: authViewModel.accessToken,
                        actionDescription: "eliminar tu cuenta",
                        alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para eliminar tu cuenta."
                    ) {
                        deleteAccount(userID: userID)
                    }
                } else {
                    deleteAccount(userID: userID)
                }
            }
            .disabled(
                deleteAccountConfirmation != "ELIMINAR"
                    || authViewModel.isLoading
            )
            Button("Cancelar", role: .cancel) {
                deleteAccountConfirmation = ""
            }
        } message: {
            Text("Se eliminarán tu cuenta, rituales, modos, sesiones, métricas y tags vinculados. Esta acción no se puede deshacer.")
        }
    }

    private func deleteAccount(userID: String) {
        Task {
            let deleted = await authViewModel.deleteAccount()
            guard deleted else { return }
            viewModel.deleteLocalAccountData(userID: userID)
            dismiss()
        }
    }

    private var userSection: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Usuario")
            VStack(spacing: 0) {
                profileInfoRow(symbol: "person.text.rectangle", label: "Nombre", value: nameParts.first)
                profileRowDivider
                profileInfoRow(symbol: "person.crop.square", label: "Apellido", value: nameParts.last)
                profileRowDivider
                profileInfoRow(
                    symbol: "envelope",
                    label: "Email",
                    value: authViewModel.authUser?.email ?? "–"
                )
                profileRowDivider
                profileInfoRow(symbol: "key", label: "Inicio de sesión", value: authProviderText)
                profileRowDivider

                Button {
                    isDeleteAccountIntroPresented = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RituoPalette.danger)
                            .frame(width: 22)
                        Text("Eliminar cuenta")
                            .font(.system(size: 15))
                            .foregroundStyle(RituoPalette.danger)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(profileCardBg)
        }
    }

    private var nameParts: (first: String, last: String) {
        let name = authViewModel.authUser?.displayName ?? authViewModel.profileDisplayName ?? "Perfil"
        let parts = name.split(separator: " ").map(String.init)
        guard name != "Perfil", !parts.isEmpty else { return ("Sin nombre", "Sin apellido") }
        return parts.count == 1 ? (parts[0], "Sin apellido") : (parts[0], parts.dropFirst().joined(separator: " "))
    }

    private var authProviderText: String {
        authViewModel.authProvider?.displayName ?? "No detectado"
    }
}
