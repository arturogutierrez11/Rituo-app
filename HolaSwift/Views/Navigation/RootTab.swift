import SwiftUI

enum RootTab: Hashable, CaseIterable {
    case home
    case rituals
    case focus
    case profile

    var title: String {
        switch self {
        case .home:    return "Inicio"
        case .rituals: return "Rituales"
        case .focus:   return "Foco"
        case .profile: return "Perfil"
        }
    }

    var symbolName: String {
        switch self {
        case .home:    return "circle"
        case .rituals: return "calendar"
        case .focus:   return "chart.bar.xaxis"
        case .profile: return "person"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .home:    return "circle.fill"
        case .rituals: return "calendar.badge.clock"
        case .focus:   return "chart.bar.xaxis.ascending"
        case .profile: return "person.fill"
        }
    }
}
