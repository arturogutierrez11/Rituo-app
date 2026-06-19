import Foundation

struct AppleAuthRequest: Encodable {
    let identityToken: String
    let deviceId: String
    let authorizationCode: String?
    let deviceLabel: String
}

struct AppleAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}


struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
