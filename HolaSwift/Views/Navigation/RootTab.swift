import SwiftUI

enum RootTab: Hashable, CaseIterable {
    case home
    case rituals
    case focus
    case profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .rituals: return "Rituales"
        case .focus: return "Focus"
        case .profile: return "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .rituals: return "sparkle"
        case .focus: return "timer"
        case .profile: return "person"
        }
    }
}
