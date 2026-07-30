import SwiftUI

struct AppUpdateNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("dismissedOptionalAppUpdateBuild")
    private var dismissedOptionalAppUpdateBuild = 0

    let status: AppUpdateStatusResponse

    var body: some View {
        RituoBottomActionSheet(
            symbol: "arrow.down.app.fill",
            tint: RituoPalette.lightBlue,
            title: status.title ?? "Hay una nueva versión de rituo",
            message: message,
            actions: actions
        )
        .interactiveDismissDisabled(status.updateRequired)
    }

    private var message: String {
        let configuredMessage = status.message
            ?? "Actualizá la app para seguir usando las últimas mejoras y protecciones."
        guard let latestVersion = status.latestVersion else {
            return configuredMessage
        }
        return "\(configuredMessage)\n\nVersión disponible: \(latestVersion)"
    }

    private var actions: [RituoBottomSheetAction] {
        var actions = [
            RituoBottomSheetAction(
                title: "Actualizar ahora",
                symbol: "arrow.up.right"
            ) {
                guard let storeURL = status.storeURL else { return }
                if !status.updateRequired, let latestBuild = status.latestBuild {
                    dismissedOptionalAppUpdateBuild = latestBuild
                    dismiss()
                }
                openURL(storeURL)
            }
        ]

        if !status.updateRequired {
            actions.append(
                RituoBottomSheetAction(
                    title: "Ahora no",
                    style: .secondary
                ) {
                    if let latestBuild = status.latestBuild {
                        dismissedOptionalAppUpdateBuild = latestBuild
                    }
                    dismiss()
                }
            )
        }

        return actions
    }
}
