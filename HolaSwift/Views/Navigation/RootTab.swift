import SwiftUI

enum RootTab: Hashable, CaseIterable {
    case home
    case rituals
    case focus
    case profile

    var title: String {
        switch self {
        case .home:    return "Home"
        case .rituals: return "Rituales"
        case .focus:   return "Focus"
        case .profile: return "Perfil"
        }
    }

    var symbolName: String {
        switch self {
        case .home:    return "square.grid.2x2"
        case .rituals: return "bolt"
        case .focus:   return "circle.dotted"
        case .profile: return "person"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .home:    return "square.grid.2x2.fill"
        case .rituals: return "bolt.fill"
        case .focus:   return "record.circle"
        case .profile: return "person.fill"
        }
    }
}
