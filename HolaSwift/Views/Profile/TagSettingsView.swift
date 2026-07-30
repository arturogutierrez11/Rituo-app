import SwiftUI

struct TagSettingsView: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel

    @State private var tagPendingRevocation: NfcTagClaimResponse?
    @State private var isRevokeConfirmationPresented = false
    @State private var tagPendingRelink: NfcTagClaimResponse?
    @State private var isRelinkConfirmationPresented = false
    @State private var tagPendingRename: NfcTagClaimResponse?
    @State private var tagRenameText = ""
    @State private var isRenameAlertPresented = false

    var body: some View {
        tagSection
            .sheet(isPresented: $isRevokeConfirmationPresented) {
                RituoBottomActionSheet(
                    symbol: "wave.3.right.circle",
                    tint: RituoPalette.danger,
                    title: "Desvincular tag",
                    message: "Este tag dejará de funcionar como llave para tu cuenta. Para confirmar que lo tenés físicamente, primero vas a tener que acercarlo al iPhone.",
                    actions: [
                        RituoBottomSheetAction(
                            title: viewModel.isRevokingNfcTag ? "Desvinculando..." : "Confirmar con tag",
                            symbol: "wave.3.right",
                            style: .destructive
                        ) {
                            guard !viewModel.isRevokingNfcTag else { return }
                            guard let claim = tagPendingRevocation else {
                                closeRevokeSheet()
                                return
                            }

                            viewModel.validateTagForSensitiveAction(
                                accessToken: authViewModel.accessToken,
                                actionDescription: "desvincular el tag",
                                alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para desvincularla."
                            ) {
                                guard let token = authViewModel.accessToken else { return }
                                closeRevokeSheet()
                                Task { await viewModel.revokeTagClaim(claim, accessToken: token) }
                            }
                        },
                        RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                            closeRevokeSheet()
                        }
                    ]
                )
            }
            .sheet(isPresented: $isRelinkConfirmationPresented) {
                RituoBottomActionSheet(
                    symbol: "arrow.triangle.2.circlepath",
                    tint: RituoPalette.accent,
                    title: "Volver a vincular",
                    message: "Vamos a reemplazar la tarjeta actual por una nueva. La anterior deja de funcionar para esta cuenta cuando la nueva queda vinculada.",
                    actions: [
                        RituoBottomSheetAction(
                            title: viewModel.isReadingTag ? "Escaneando..." : "Escanear nueva tarjeta",
                            symbol: "wave.3.right"
                        ) {
                            guard !viewModel.isReadingTag else { return }
                            guard let token = authViewModel.accessToken else {
                                closeRelinkSheet()
                                viewModel.tagMessage = "Iniciá sesión para volver a vincular un tag."
                                return
                            }

                            let preservedLabel = tagPendingRelink?.label
                            closeRelinkSheet()
                            viewModel.claimTag(
                                accessToken: token,
                                preferredLabel: preservedLabel,
                                isReplacement: true
                            )
                        },
                        RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                            closeRelinkSheet()
                        }
                    ]
                )
            }
            .alert("Nombre del tag", isPresented: $isRenameAlertPresented) {
                TextField("Ej. Llave de casa", text: $tagRenameText)
                Button("Guardar") {
                    guard let claim = tagPendingRename, let token = authViewModel.accessToken else {
                        tagPendingRename = nil
                        tagRenameText = ""
                        return
                    }
                    let label = tagRenameText
                    tagPendingRename = nil
                    tagRenameText = ""
                    Task { await viewModel.renameTagClaim(claim, label: label, accessToken: token) }
                }
                Button("Cancelar", role: .cancel) {
                    tagPendingRename = nil
                    tagRenameText = ""
                }
            } message: {
                Text("Usá un nombre que te ayude a reconocer dónde está.")
            }
    }

    private var tagSection: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Tag NFC")

            VStack(spacing: 14) {
                if viewModel.hasClaimedNfcTag, let claim = viewModel.primaryNfcTagClaim {
                    RituoPhysicalCard(label: claim.label)

                    VStack(spacing: 0) {
                        Button {
                            tagPendingRename = claim
                            tagRenameText = claim.label ?? ""
                            isRenameAlertPresented = true
                        } label: {
                            profileLinkRowFn(
                                symbol: "pencil",
                                label: "Renombrar tag",
                                detail: claim.label ?? "Sin nombre"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRevokingNfcTag)

                        profileRowDivider

                        Button {
                            tagPendingRelink = claim
                            isRelinkConfirmationPresented = true
                        } label: {
                            profileLinkRowFn(
                                symbol: "arrow.triangle.2.circlepath",
                                label: "Volver a vincular",
                                detail: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRevokingNfcTag)

                        profileRowDivider

                        Button {
                            tagPendingRevocation = claim
                            isRevokeConfirmationPresented = true
                        } label: {
                            HStack(spacing: 14) {
                                if viewModel.isRevokingNfcTag {
                                    ProgressView()
                                        .tint(RituoPalette.danger)
                                        .scaleEffect(0.75)
                                        .frame(width: 22)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(RituoPalette.danger)
                                        .frame(width: 22)
                                }
                                Text(viewModel.isRevokingNfcTag ? "Desvinculando..." : "Desvincular tag")
                                    .font(.system(size: 15))
                                    .foregroundStyle(RituoPalette.danger)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRevokingNfcTag)
                    }
                    .background(profileCardBg)
                } else {
                    ZStack {
                        RituoPhysicalCard(label: nil).opacity(0.40)
                        VStack(spacing: 8) {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(RituoPalette.white.opacity(0.30))
                            Text("Sin tarjeta vinculada")
                                .font(.system(size: 13))
                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                        }
                    }

                    Button {
                        if let token = authViewModel.accessToken {
                            viewModel.claimTag(accessToken: token)
                        } else {
                            viewModel.tagMessage = "Iniciá sesión para vincular un tag."
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isReadingTag {
                                ProgressView()
                                    .tint(RituoPalette.deepOceanBlue)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Text("Vincular tarjeta")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RituoPalette.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(LoginPressButtonStyle())
                    .disabled(viewModel.isReadingTag)
                }

                if let msg = viewModel.tagMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(RituoPalette.white.opacity(0.40))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func closeRevokeSheet() {
        isRevokeConfirmationPresented = false
        tagPendingRevocation = nil
    }

    private func closeRelinkSheet() {
        isRelinkConfirmationPresented = false
        tagPendingRelink = nil
    }

}
