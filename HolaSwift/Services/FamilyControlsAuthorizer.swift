import FamilyControls
import Foundation

@MainActor
final class FamilyControlsAuthorizer {
    private let center = AuthorizationCenter.shared

    var status: AuthorizationStatus {
        center.authorizationStatus
    }

    var statusText: String {
        switch center.authorizationStatus {
        case .approved:
            return "Autorizado"
        case .denied:
            return "Denegado"
        case .notDetermined:
            return "Todavia no solicitado"
        @unknown default:
            return "Estado desconocido"
        }
    }

    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }
}
