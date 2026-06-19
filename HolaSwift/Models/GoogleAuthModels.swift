import Foundation

struct GoogleAuthRequest: Encodable {
    let identityToken: String
    let deviceId: String
    let deviceLabel: String
}

struct GoogleAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}
