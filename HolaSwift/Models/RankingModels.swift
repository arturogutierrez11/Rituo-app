import Foundation

/// Respuesta de `GET /ranking` (ranking mensual de minutos de foco).
struct RankingResponse: Decodable, Equatable {
    let period: String
    let periodStart: String
    let periodEnd: String
    let timeZone: String
    /// Usuarios que usan la app (encabezado "N usuarios").
    let totalUsers: Int
    /// Usuarios con foco este mes (los que están en el ranking).
    let participants: Int
    let me: RankingMe
    /// Ordenado por `position` ascendente. Hasta 100 + la fila propia si quedó afuera del top.
    let entries: [RankingEntry]
}

struct RankingMe: Decodable, Equatable {
    /// `nil` si todavía no tiene foco este mes.
    let position: Int?
    let displayName: String?
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
}

struct RankingEntry: Decodable, Equatable, Identifiable {
    let position: Int
    /// Texto a mostrar: "Usuario N" o el nombre real si `isMe`.
    let label: String
    let isMe: Bool
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
    let displayName: String?

    /// Las posiciones pueden repetirse (empates), así que la identidad
    /// combina posición con etiqueta.
    var id: String { "\(position)-\(label)-\(isMe)" }
}
