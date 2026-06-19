import Foundation

enum AuthProvider: String {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }

    var systemImageName: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .google:
            return "g.circle.fill"
        }
    }
}
