import SwiftUI

private enum EmergencyUnlockSheet: Identifiable {
    case overview
    case reason
    case lostTagWarning
    case confirm(EmergencyUnlockReason)

    var id: String {
        switch self {
        case .overview:
            return "overview"
        case .reason:
            return "reason"
        case .lostTagWarning:
            return "lost-tag-warning"
        case .confirm(let reason):
            return "confirm-\(reason.rawValue)"
        }
    }
}

private enum StrictModeSheet: Identifiable {
    case overview
    case enableConfirm
    case disableConfirm

    var id: String {
        switch self {
        case .overview:
            return "overview"
        case .enableConfirm:
            return "enable-confirm"
        case .disableConfirm:
            return "disable-confirm"
        }
    }
}

private enum AppInstallationBlockSheet: Identifiable {
    case overview
    case enableConfirm
    case disableConfirm

    var id: String {
        switch self {
        case .overview:
            return "overview"
        case .enableConfirm:
            return "enable-confirm"
        case .disableConfirm:
            return "disable-confirm"
        }
    }
}

private enum SensitiveWebContentBlockSheet: Identifiable {
    case overview
    case enableConfirm
    case disableConfirm

    var id: String {
        switch self {
        case .overview:
            return "overview"
        case .enableConfirm:
            return "enable-confirm"
        case .disableConfirm:
            return "disable-confirm"
        }
    }
}

struct ProtectionSettingsView: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @ObservedObject var authViewModel: AuthViewModel

    @State private var emergencyUnlockSheet: EmergencyUnlockSheet?
    @State private var strictModeSheet: StrictModeSheet?
    @State private var appInstallationBlockSheet: AppInstallationBlockSheet?
    @State private var sensitiveWebContentBlockSheet: SensitiveWebContentBlockSheet?

    var body: some View {
        VStack(spacing: 14) {
            protectionSection
            emergencyUnlockSection
        }
        .task(id: authViewModel.accessToken) {
            guard let token = authViewModel.accessToken else { return }
            await viewModel.loadEmergencyUnlockStatus(accessToken: token)
        }
        .sheet(item: $strictModeSheet) { sheet in
            strictModeBottomSheet(sheet)
        }
        .sheet(item: $emergencyUnlockSheet) { sheet in
            emergencyUnlockBottomSheet(sheet)
        }
        .sheet(item: $appInstallationBlockSheet) { sheet in
            appInstallationBlockBottomSheet(sheet)
        }
        .sheet(item: $sensitiveWebContentBlockSheet) { sheet in
            sensitiveWebContentBlockBottomSheet(sheet)
        }
    }

    private var protectionSection: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Protección")

            VStack(spacing: 0) {
                Button {
                    strictModeSheet = .overview
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.isStrictModeEnabled
                                    ? RituoPalette.lightBlue
                                    : RituoPalette.white.opacity(0.24)
                            )
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Modo estricto")
                                .font(.system(size: 15))
                                .foregroundStyle(RituoPalette.white.opacity(0.80))
                            Text(strictModeStatusText)
                                .font(.system(size: 11))
                                .foregroundStyle(RituoPalette.white.opacity(0.34))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.20))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    appInstallationBlockSheet = .overview
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.isAppInstallationBlockingEnabled
                                    ? RituoPalette.lightBlue
                                    : RituoPalette.white.opacity(0.24)
                            )
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bloquear descargas de apps")
                                .font(.system(size: 15))
                                .foregroundStyle(RituoPalette.white.opacity(0.80))
                            Text(appInstallationBlockStatusText)
                                .font(.system(size: 11))
                                .foregroundStyle(RituoPalette.white.opacity(0.34))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.20))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                profileRowDivider

                Button {
                    sensitiveWebContentBlockSheet = .overview
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.isSensitiveWebContentBlockingEnabled
                                    ? RituoPalette.lightBlue
                                    : RituoPalette.white.opacity(0.24)
                            )
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bloquear contenido sensible")
                                .font(.system(size: 15))
                                .foregroundStyle(RituoPalette.white.opacity(0.80))
                            Text(sensitiveWebContentBlockStatusText)
                                .font(.system(size: 11))
                                .foregroundStyle(RituoPalette.white.opacity(0.34))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.20))
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

    private var emergencyUnlockSection: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Emergencias")

            VStack(spacing: 0) {
                Button {
                    emergencyUnlockSheet = .overview
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.open.trianglebadge.exclamationmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.canUseEmergencyUnlock
                                    ? RituoPalette.danger
                                    : RituoPalette.white.opacity(0.24)
                            )
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Desbloqueo de emergencia")
                                .font(.system(size: 15))
                                .foregroundStyle(RituoPalette.white.opacity(0.80))
                            Text(viewModel.emergencyUnlockAvailabilityText)
                                .font(.system(size: 11))
                                .foregroundStyle(RituoPalette.white.opacity(0.34))
                        }

                        Spacer()

                        if viewModel.isLoadingEmergencyUnlock {
                            ProgressView()
                                .tint(RituoPalette.white.opacity(0.45))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(RituoPalette.white.opacity(0.20))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(profileCardBg)

            if let message = viewModel.emergencyUnlockMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(RituoPalette.white.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
            }
        }
        .id(ProfileSettingsSection.emergency)
    }

    @ViewBuilder
    private func strictModeBottomSheet(_ sheet: StrictModeSheet) -> some View {
        switch sheet {
        case .overview:
            RituoBottomActionSheet(
                symbol: "lock.shield",
                tint: RituoPalette.lightBlue,
                title: "Modo estricto",
                message: strictModeOverviewMessage,
                actions: strictModeOverviewActions
            )
        case .enableConfirm:
            RituoBottomActionSheet(
                symbol: "lock.shield",
                tint: RituoPalette.lightBlue,
                title: "Activar modo estricto",
                message: "rituo va a impedir que la app se elimine en todo momento, aunque no haya un ritual activo. Para desactivarlo vas a necesitar tu tarjeta y no puede haber una sesión en curso.",
                actions: [
                    RituoBottomSheetAction(title: "Activar", symbol: "checkmark") {
                        strictModeSheet = nil
                        Task { await viewModel.setStrictModeEnabled(true) }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        strictModeSheet = nil
                    }
                ]
            )
        case .disableConfirm:
            RituoBottomActionSheet(
                symbol: "lock.open",
                tint: RituoPalette.danger,
                title: "Desactivar modo estricto",
                message: "Si lo desactivás, el iPhone volverá a permitir que rituo se elimine.",
                actions: [
                    RituoBottomSheetAction(title: "Desactivar", symbol: "lock.open", style: .destructive) {
                        strictModeSheet = nil
                        viewModel.validateTagForSensitiveAction(
                            accessToken: authViewModel.accessToken,
                            actionDescription: "desactivar el modo estricto",
                            alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para desactivar el modo estricto."
                        ) {
                            Task { await viewModel.setStrictModeEnabled(false) }
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        strictModeSheet = nil
                    }
                ]
            )
        }
    }

    @ViewBuilder
    private func emergencyUnlockBottomSheet(_ sheet: EmergencyUnlockSheet) -> some View {
        switch sheet {
        case .overview:
            RituoBottomActionSheet(
                symbol: "lock.open.trianglebadge.exclamationmark",
                tint: RituoPalette.lightBlue,
                title: "Desbloqueo de emergencia",
                message: emergencyOverviewMessage,
                actions: emergencyOverviewActions
            )
        case .reason:
            RituoBottomActionSheet(
                symbol: "lock.open.trianglebadge.exclamationmark",
                tint: RituoPalette.danger,
                title: "Desbloqueo de emergencia",
                message: "Usalo solo si no tenés tu tag a mano. Esta opción tiene un límite de uso para proteger el bloqueo.",
                actions: [
                    RituoBottomSheetAction(title: "Lo olvidé", symbol: "hand.raised") {
                        emergencyUnlockSheet = .confirm(.forgotTag)
                    },
                    RituoBottomSheetAction(title: "Lo perdí", symbol: "exclamationmark.triangle", style: .destructive) {
                        emergencyUnlockSheet = .lostTagWarning
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        emergencyUnlockSheet = nil
                    }
                ]
            )
        case .lostTagWarning:
            RituoBottomActionSheet(
                symbol: "tag.slash",
                tint: RituoPalette.danger,
                title: "¿Realmente perdiste tu tag?",
                message: """
                Si elegís esta opción, el tag quedará inhabilitado permanentemente. Aunque lo encuentres después, no vas a poder volver a usarlo.

                Si solamente no lo tenés a mano, volvé y elegí “Lo olvidé”.
                """,
                actions: [
                    RituoBottomSheetAction(
                        title: "Sí, lo perdí",
                        symbol: "exclamationmark.triangle",
                        style: .destructive
                    ) {
                        emergencyUnlockSheet = .confirm(.lostTag)
                    },
                    RituoBottomSheetAction(title: "Volver", style: .secondary) {
                        emergencyUnlockSheet = .reason
                    }
                ]
            )
        case .confirm(let reason):
            RituoBottomActionSheet(
                symbol: reason == .lostTag ? "tag.slash" : "lock.open",
                tint: reason == .lostTag ? RituoPalette.danger : RituoPalette.lightBlue,
                title: "Confirmar desbloqueo",
                message: emergencyConfirmationMessage(for: reason),
                actions: [
                    RituoBottomSheetAction(title: "Desbloquear", symbol: "lock.open", style: .destructive) {
                        guard let token = authViewModel.accessToken else {
                            emergencyUnlockSheet = nil
                            return
                        }

                        emergencyUnlockSheet = nil
                        Task {
                            _ = await viewModel.useEmergencyUnlock(
                                reason: reason,
                                accessToken: token
                            )
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        emergencyUnlockSheet = nil
                    }
                ]
            )
        }
    }

    @ViewBuilder
    private func appInstallationBlockBottomSheet(_ sheet: AppInstallationBlockSheet) -> some View {
        switch sheet {
        case .overview:
            RituoBottomActionSheet(
                symbol: "arrow.down.app.fill",
                tint: RituoPalette.lightBlue,
                title: "Descargas de apps",
                message: appInstallationBlockOverviewMessage,
                actions: appInstallationBlockOverviewActions
            )
        case .enableConfirm:
            RituoBottomActionSheet(
                symbol: "arrow.down.app.fill",
                tint: RituoPalette.lightBlue,
                title: "Bloquear descargas",
                message: "Mientras esté activo, iOS no permitirá instalar apps nuevas desde App Store. Podés desactivarlo desde esta misma sección.",
                actions: [
                    RituoBottomSheetAction(title: "Bloquear", symbol: "checkmark") {
                        appInstallationBlockSheet = nil
                        Task { await viewModel.setAppInstallationBlockingEnabled(true) }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        appInstallationBlockSheet = nil
                    }
                ]
            )
        case .disableConfirm:
            RituoBottomActionSheet(
                symbol: "arrow.down.app",
                tint: RituoPalette.danger,
                title: "Permitir descargas",
                message: "Si lo desactivás, App Store volverá a permitir instalar apps nuevas.",
                actions: [
                    RituoBottomSheetAction(title: "Permitir descargas", symbol: "lock.open", style: .destructive) {
                        appInstallationBlockSheet = nil
                        viewModel.validateTagForSensitiveAction(
                            accessToken: authViewModel.accessToken,
                            actionDescription: "permitir descargas de apps",
                            alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para permitir descargas de apps."
                        ) {
                            Task { await viewModel.setAppInstallationBlockingEnabled(false) }
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        appInstallationBlockSheet = nil
                    }
                ]
            )
        }
    }

    @ViewBuilder
    private func sensitiveWebContentBlockBottomSheet(
        _ sheet: SensitiveWebContentBlockSheet
    ) -> some View {
        switch sheet {
        case .overview:
            RituoBottomActionSheet(
                symbol: "shield.lefthalf.filled",
                tint: RituoPalette.lightBlue,
                title: "Contenido sensible",
                message: sensitiveWebContentBlockOverviewMessage,
                actions: sensitiveWebContentBlockOverviewActions
            )
        case .enableConfirm:
            RituoBottomActionSheet(
                symbol: "shield.lefthalf.filled",
                tint: RituoPalette.lightBlue,
                title: "Bloquear contenido sensible",
                message: "El filtro quedará activo globalmente, aunque no haya un modo o ritual en curso. Para Safari, la extensión de rituo debe permanecer habilitada.",
                actions: [
                    RituoBottomSheetAction(title: "Bloquear", symbol: "checkmark") {
                        sensitiveWebContentBlockSheet = nil
                        Task {
                            await viewModel.setSensitiveWebContentBlockingEnabled(true)
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        sensitiveWebContentBlockSheet = nil
                    }
                ]
            )
        case .disableConfirm:
            RituoBottomActionSheet(
                symbol: "shield.slash",
                tint: RituoPalette.danger,
                title: "Permitir contenido sensible",
                message: "Si lo desactivás, el filtro global dejará de aplicarse. Los modos y rituales que tengan su propio filtro seguirán funcionando.",
                actions: [
                    RituoBottomSheetAction(
                        title: "Desactivar filtro",
                        symbol: "shield.slash",
                        style: .destructive
                    ) {
                        sensitiveWebContentBlockSheet = nil
                        viewModel.validateTagForSensitiveAction(
                            accessToken: authViewModel.accessToken,
                            actionDescription: "desactivar el bloqueo de contenido sensible",
                            alertMessage: "Acerca la tarjeta rituo para desactivar el bloqueo global de contenido sensible."
                        ) {
                            Task {
                                await viewModel.setSensitiveWebContentBlockingEnabled(false)
                            }
                        }
                    },
                    RituoBottomSheetAction(title: "Cancelar", style: .secondary) {
                        sensitiveWebContentBlockSheet = nil
                    }
                ]
            )
        }
    }

    private var strictModeStatusText: String {
        viewModel.isStrictModeEnabled
            ? "Protección permanente activa"
            : "Desactivado"
    }

    private var appInstallationBlockStatusText: String {
        viewModel.isAppInstallationBlockingEnabled ? "Descargas bloqueadas" : "Descargas permitidas"
    }

    private var sensitiveWebContentBlockStatusText: String {
        viewModel.isSensitiveWebContentBlockingEnabled
            ? "Filtro global activo"
            : "Desactivado"
    }

    private var sensitiveWebContentBlockOverviewMessage: String {
        """
        Filtra contenido adulto, redes sociales y sitios de apuestas en todo el iPhone. En Safari también utiliza la extensión de rituo.

        Es una configuración general del perfil: queda activa aunque no haya una sesión de foco.

        Estado: \(sensitiveWebContentBlockStatusText).
        """
    }

    private var sensitiveWebContentBlockOverviewActions: [RituoBottomSheetAction] {
        if viewModel.isSensitiveWebContentBlockingEnabled {
            return [
                RituoBottomSheetAction(
                    title: "Desactivar filtro",
                    symbol: "shield.slash",
                    style: .destructive
                ) {
                    sensitiveWebContentBlockSheet = .disableConfirm
                },
                RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                    sensitiveWebContentBlockSheet = nil
                }
            ]
        }

        return [
            RituoBottomSheetAction(title: "Activar filtro", symbol: "checkmark") {
                sensitiveWebContentBlockSheet = .enableConfirm
            },
            RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                sensitiveWebContentBlockSheet = nil
            }
        ]
    }

    private var appInstallationBlockOverviewMessage: String {
        """
        Esta opción bloquea la instalación de apps nuevas en el iPhone. Sirve para que no puedas descargar otra app para esquivar un modo o ritual.

        Es una configuración general del perfil: queda activa aunque no tengas una sesión de foco corriendo.

        Estado: \(appInstallationBlockStatusText).
        """
    }

    private var appInstallationBlockOverviewActions: [RituoBottomSheetAction] {
        if viewModel.isAppInstallationBlockingEnabled {
            return [
                RituoBottomSheetAction(title: "Permitir descargas", symbol: "lock.open", style: .destructive) {
                    appInstallationBlockSheet = .disableConfirm
                },
                RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                    appInstallationBlockSheet = nil
                }
            ]
        }

        return [
            RituoBottomSheetAction(title: "Bloquear descargas", symbol: "checkmark") {
                appInstallationBlockSheet = .enableConfirm
            },
            RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                appInstallationBlockSheet = nil
            }
        ]
    }

    private var strictModeOverviewMessage: String {
        """
        El modo estricto evita que rituo se pueda eliminar en todo momento, incluso cuando no hay un ritual o modo activo.

        Para desactivarlo necesitás apoyar tu tarjeta rituo. Si hay una sesión activa, primero tiene que terminar.

        Estado: \(strictModeStatusText).
        """
    }

    private var strictModeOverviewActions: [RituoBottomSheetAction] {
        if viewModel.isStrictModeEnabled && viewModel.hasActiveFocusSession {
            return [
                RituoBottomSheetAction(title: "Entendido", style: .secondary) {
                    strictModeSheet = nil
                }
            ]
        }

        if viewModel.isStrictModeEnabled {
            return [
                RituoBottomSheetAction(title: "Desactivar", symbol: "lock.open", style: .destructive) {
                    strictModeSheet = .disableConfirm
                },
                RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                    strictModeSheet = nil
                }
            ]
        }

        return [
            RituoBottomSheetAction(title: "Activar", symbol: "checkmark") {
                strictModeSheet = .enableConfirm
            },
            RituoBottomSheetAction(title: "Cerrar", style: .secondary) {
                strictModeSheet = nil
            }
        ]
    }

    private func emergencyConfirmationMessage(for reason: EmergencyUnlockReason) -> String {
        if reason == .lostTag {
            return "La sesión terminará, el tag quedará inhabilitado permanentemente y no podrás volver a usar el desbloqueo durante 30 días."
        }

        return "La sesión terminará sin desvincular tu tag. No podrás volver a usar el desbloqueo durante 30 días."
    }

    private var emergencyOverviewMessage: String {
        """
        Usá esta opción solo si olvidaste o perdiste tu tarjeta rituo. Termina la sesión activa sin NFC y libera las apps bloqueadas.

        Por seguridad, solo puede usarse una vez cada 30 días. Si marcás el tag como perdido, esa tarjeta queda inhabilitada y vas a tener que vincular una nueva.

        Estado: \(viewModel.emergencyUnlockAvailabilityText).
        """
    }

    private var emergencyOverviewActions: [RituoBottomSheetAction] {
        var actions: [RituoBottomSheetAction] = []

        if viewModel.canUseEmergencyUnlock {
            actions.append(
                RituoBottomSheetAction(
                    title: "Usar desbloqueo",
                    symbol: "lock.open",
                    style: .destructive
                ) {
                    emergencyUnlockSheet = .reason
                }
            )
        }

        actions.append(
            RituoBottomSheetAction(title: "Entendido", style: .secondary) {
                emergencyUnlockSheet = nil
            }
        )

        return actions
    }
}
