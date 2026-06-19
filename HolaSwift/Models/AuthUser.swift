import Foundation

struct AuthUser: Decodable {
    let id: String
    let email: String?
    let displayName: String?
    let emailVerified: Bool
    let status: String
}
