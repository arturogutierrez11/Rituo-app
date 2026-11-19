import FamilyControls
import Foundation

@MainActor
final class FamilyControlsAuthorizer {
    private let center = AuthorizationCenter.shared

    var status: AuthorizationStatus {
        center.authorizationStatus
    }

    var statusText: String {
        let status = center.authorizationStatus
        // iOS 26.4 added a variant of "approved"; it is still an authorization.
        if #available(iOS 26.4, *), status == .approvedWithDataAccess {
            return "Autorizado"
        }

        switch status {
        case .approved:
            return "Autorizado"
        case .denied:
            return "Denegado"
        case .notDetermined:
            return "Todavia no solicitado"
        default:
            return "Estado desconocido"
        }
    }

    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }
}
