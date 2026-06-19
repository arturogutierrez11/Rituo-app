import Foundation

enum BlockDuration: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fifteenMinutes:
            return "15 minutos"
        case .thirtyMinutes:
            return "30 minutos"
        case .oneHour:
            return "1 hora"
        case .twoHours:
            return "2 horas"
        }
    }

    var minutes: Int {
        rawValue
    }

    var caption: String {
        switch self {
        case .fifteenMinutes:
            return "Check-in corto"
        case .thirtyMinutes:
            return "Sesion enfocada"
        case .oneHour:
            return "Trabajo profundo"
        case .twoHours:
            return "Bloque extendido"
        }
    }

    static func closest(to minutes: Int) -> BlockDuration {
        allCases.min { abs($0.minutes - minutes) < abs($1.minutes - minutes) } ?? .thirtyMinutes
    }
}
