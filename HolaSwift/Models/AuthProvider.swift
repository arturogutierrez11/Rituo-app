import Foundation

enum AuthProvider: String {
    case apple
    case google
    case email

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .email:
            return "Email"
        }
    }

    var systemImageName: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .google:
            return "g.circle.fill"
        case .email:
            return "envelope.fill"
        }
    }
}
