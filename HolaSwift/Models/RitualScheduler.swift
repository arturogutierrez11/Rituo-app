import FamilyControls
import Foundation

struct RitualScheduler: Identifiable, Hashable, Codable {
    let id: UUID
    let coreRitualId: String?
    let title: String
    let detail: String
    let focusTarget: String
    let symbolName: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let weekdays: [Int]
    let selection: FamilyActivitySelection
    let isProtected: Bool
    let nfcUnlockEnabled: Bool

    init(
        id: UUID = UUID(),
        coreRitualId: String? = nil,
        title: String,
        detail: String,
        focusTarget: String,
        symbolName: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        weekdays: [Int],
        selection: FamilyActivitySelection,
        isProtected: Bool = false,
        nfcUnlockEnabled: Bool = false
    ) {
        self.id = id
        self.coreRitualId = coreRitualId
        self.title = title
        self.detail = detail
        self.focusTarget = focusTarget
        self.symbolName = symbolName
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.selection = selection
        self.isProtected = isProtected
        self.nfcUnlockEnabled = nfcUnlockEnabled
    }

    var durationMinutes: Int {
        ((endHour * 60) + endMinute) - ((startHour * 60) + startMinute)
    }

    var appCount: Int {
        selection.applicationTokens.count
    }

    var categoryCount: Int {
        selection.categoryTokens.count
    }

    var domainCount: Int {
        selection.webDomainTokens.count
    }

    var selectedItemCount: Int {
        appCount + categoryCount + domainCount
    }

    var selectionDigest: String {
        Self.selectionDigest(for: selection)
    }

    var isLegacyDemoScheduler: Bool {
        coreRitualId == nil &&
        selectedItemCount == 0 &&
        ["Lectura", "Deep Work", "Sleep Wind-down", "Gym"].contains(title)
    }

    var timeRangeText: String {
        "\(Self.format(hour: startHour, minute: startMinute)) - \(Self.format(hour: endHour, minute: endMinute))"
    }

    var endTimeText: String {
        Self.format(hour: endHour, minute: endMinute)
    }

    var weekdayText: String {
        let lookup = [
            1: "Dom",
            2: "Lun",
            3: "Mar",
            4: "Mie",
            5: "Jue",
            6: "Vie",
            7: "Sab"
        ]

        if weekdays == [2, 3, 4, 5, 6] {
            return "Lun a Vie"
        }

        return weekdays.compactMap { lookup[$0] }.joined(separator: ", ")
    }

    func isActive(on date: Date = .now) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else {
            return false
        }

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return minutes >= start && minutes < end
    }

    func endDate(on date: Date = .now) -> Date? {
        let calendar = Calendar.current
        guard weekdays.contains(calendar.component(.weekday, from: date)) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return calendar.date(from: components)
    }

    private static func format(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute

        let date = components.date ?? .now
        return formatter.string(from: date).lowercased()
    }

    static func selectionDigest(for selection: FamilyActivitySelection) -> String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        let domainCount = selection.webDomainTokens.count

        if appCount == 0 && categoryCount == 0 && domainCount == 0 {
            return "Sin apps configuradas"
        }

        var parts: [String] = []

        if appCount > 0 {
            parts.append("\(appCount) app\(appCount == 1 ? "" : "s")")
        }

        if categoryCount > 0 {
            parts.append("\(categoryCount) categoria\(categoryCount == 1 ? "" : "s")")
        }

        if domainCount > 0 {
            parts.append("\(domainCount) web")
        }

        return parts.joined(separator: ", ")
    }

    static func == (lhs: RitualScheduler, rhs: RitualScheduler) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension RitualScheduler {
    init(response: RitualResponse, preserving selection: FamilyActivitySelection = FamilyActivitySelection()) {
        let fallbackStart = Self.timeParts(from: response.startTime) ?? (hour: 17, minute: 0)
        let fallbackEnd = Self.timeParts(from: response.endTime) ?? Self.endTimeParts(
            from: fallbackStart,
            durationMinutes: response.durationMinutes
        )

        self.init(
            coreRitualId: response.id,
            title: response.title,
            detail: response.description ?? "Ritual sincronizado con core-api.",
            focusTarget: response.selectionDigest ?? "Sin seleccion local",
            symbolName: Self.systemSymbol(for: response.icon),
            startHour: fallbackStart.hour,
            startMinute: fallbackStart.minute,
            endHour: fallbackEnd.hour,
            endMinute: fallbackEnd.minute,
            weekdays: response.weekdays.sorted(),
            selection: selection,
            isProtected: response.isProtected,
            nfcUnlockEnabled: response.nfcUnlockEnabled
        )
    }

    func createRitualRequest(password: String? = nil) -> CreateRitualRequest {
        CreateRitualRequest(
            title: title,
            description: detail,
            icon: symbolName,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            startTime: Self.apiTime(hour: startHour, minute: startMinute),
            endTime: Self.apiTime(hour: endHour, minute: endMinute),
            appCount: appCount,
            categoryCount: categoryCount,
            domainCount: domainCount,
            selectionDigest: selectionDigest,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            password: isProtected ? password : nil
        )
    }


    var blockedItemsRequest: ReplaceRitualBlockedItemsRequest {
        var items: [RitualBlockedItemRequest] = []

        items += selection.applicationTokens.enumerated().map { index, token in
            RitualBlockedItemRequest(
                type: "app",
                identifier: Self.encodedTokenIdentifier(token, fallback: "app-\(index + 1)"),
                displayName: "App \(index + 1)",
                bundleIdentifier: nil
            )
        }

        items += selection.categoryTokens.enumerated().map { index, token in
            RitualBlockedItemRequest(
                type: "category",
                identifier: Self.encodedTokenIdentifier(token, fallback: "category-\(index + 1)"),
                displayName: "Categoria \(index + 1)",
                bundleIdentifier: nil
            )
        }

        items += selection.webDomainTokens.enumerated().map { index, token in
            RitualBlockedItemRequest(
                type: "domain",
                identifier: Self.encodedTokenIdentifier(token, fallback: "domain-\(index + 1)"),
                displayName: "Web \(index + 1)",
                bundleIdentifier: nil
            )
        }

        return ReplaceRitualBlockedItemsRequest(items: items)
    }

    private static func timeParts(from value: String?) -> (hour: Int, minute: Int)? {
        guard let value else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return (hour: parts[0], minute: parts[1])
    }

    private static func endTimeParts(
        from start: (hour: Int, minute: Int),
        durationMinutes: Int
    ) -> (hour: Int, minute: Int) {
        let startTotal = start.hour * 60 + start.minute
        let endTotal = startTotal + max(durationMinutes, 1)
        return (hour: (endTotal / 60) % 24, minute: endTotal % 60)
    }

    private static func apiTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }


    private static func encodedTokenIdentifier<T: Encodable>(_ token: T, fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(token) else {
            return fallback
        }

        return data.base64EncodedString()
    }

    private static func systemSymbol(for icon: String) -> String {
        switch icon {
        case "book":
            return "book.closed"
        case "gym":
            return "dumbbell"
        case "moon":
            return "moon.stars"
        default:
            return icon
        }
    }
}

extension RitualScheduler {
    private enum CodingKeys: String, CodingKey {
        case id
        case coreRitualId
        case title
        case detail
        case focusTarget
        case symbolName
        case startHour
        case startMinute
        case endHour
        case endMinute
        case weekdays
        case selection
        case isProtected
        case nfcUnlockEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            coreRitualId: try container.decodeIfPresent(String.self, forKey: .coreRitualId),
            title: try container.decode(String.self, forKey: .title),
            detail: try container.decode(String.self, forKey: .detail),
            focusTarget: try container.decode(String.self, forKey: .focusTarget),
            symbolName: try container.decode(String.self, forKey: .symbolName),
            startHour: try container.decode(Int.self, forKey: .startHour),
            startMinute: try container.decode(Int.self, forKey: .startMinute),
            endHour: try container.decode(Int.self, forKey: .endHour),
            endMinute: try container.decode(Int.self, forKey: .endMinute),
            weekdays: try container.decode([Int].self, forKey: .weekdays),
            selection: try container.decode(FamilyActivitySelection.self, forKey: .selection),
            isProtected: try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false,
            nfcUnlockEnabled: try container.decodeIfPresent(Bool.self, forKey: .nfcUnlockEnabled) ?? false
        )
    }
}
