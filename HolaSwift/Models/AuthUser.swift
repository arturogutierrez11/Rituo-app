import Foundation

struct AuthUser: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let dateOfBirth: String?
    let emailVerified: Bool
    let status: String
}
