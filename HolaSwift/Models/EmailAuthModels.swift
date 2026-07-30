import Foundation

struct EmailRegisterRequest: Encodable {
    let email: String
    let firstName: String
    let lastName: String
    let password: String
    let passwordConfirmation: String
    let deviceId: String
    let deviceLabel: String
}

struct EmailLoginRequest: Encodable {
    let email: String
    let password: String
    let deviceId: String
    let deviceLabel: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ResendEmailVerificationRequest: Encodable {
    let email: String
}

struct EmailRegisterResponse: Decodable {
    let ok: Bool
    let emailVerificationRequired: Bool
    let user: AuthUser
}

struct EmailAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}
