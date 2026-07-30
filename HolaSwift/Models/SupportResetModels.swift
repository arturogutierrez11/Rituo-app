import Foundation

struct SupportResetResponse: Decodable, Identifiable {
    let id: String
    let userId: String
    let userEmail: String
    let reason: String
    let status: String
    let revokeTag: Bool
    let requestedAt: String
}

struct AcknowledgeSupportResetRequest: Encodable {
    let appVersion: String?
    let appBuild: String?
}
