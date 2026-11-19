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
    let strictModeEnabled: Bool
    let blockAppInstallation: Bool
    let blockAdultContent: Bool
    /// Number of configured breaks (0-3). Synced via the dedicated
    /// `/rituals/:id/breaks` endpoint, not the ritual create/update request.
    let breakCount: Int
    /// Minutes per break (1-5). Only meaningful when `breakCount > 0`.
    let breakDurationMinutes: Int

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
        nfcUnlockEnabled: Bool = false,
        strictModeEnabled: Bool = false,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false,
        breakCount: Int = 0,
        breakDurationMinutes: Int = 5
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
        self.strictModeEnabled = strictModeEnabled
        self.blockAppInstallation = blockAppInstallation
        self.blockAdultContent = blockAdultContent
        self.breakCount = max(0, min(3, breakCount))
        self.breakDurationMinutes = max(1, min(15, breakDurationMinutes))
    }

    var durationMinutes: Int {
        let startTotal = (startHour * 60) + startMinute
        let endTotal = (endHour * 60) + endMinute
        if endTotal == startTotal { return 0 }
        return endTotal < startTotal ? (24 * 60 - startTotal + endTotal) : (endTotal - startTotal)
    }

    /// True when the ritual's window crosses midnight (end time is earlier in the day than start time).
    var crossesMidnight: Bool {
        (endHour * 60 + endMinute) < (startHour * 60 + startMinute)
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
        [
            "Lectura",
            "Trabajo profundo",
            "Descanso nocturno",
            "Gimnasio",
            "Deep Work",
            "Sleep Wind-down",
            "Gym"
        ].contains(title)
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
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard start != end else { return false }

        let weekday = calendar.component(.weekday, from: date)

        if !crossesMidnight {
            guard weekdays.contains(weekday) else { return false }
            return minutes >= start && minutes < end
        }

        // Overnight ritual: active either from `start` until midnight (today is a
        // configured weekday) or from midnight until `end` (today is the day after
        // a configured weekday, finishing off last night's window).
        if weekdays.contains(weekday) && minutes >= start {
            return true
        }

        let previousWeekday = weekday == 1 ? 7 : weekday - 1
        return weekdays.contains(previousWeekday) && minutes < end
    }

    /// Start of the occurrence of this ritual that contains `date`, or nil when
    /// the ritual is not active at that moment. Used to tell whether state saved
    /// during an earlier occurrence (e.g. breaks already taken) is stale.
    func occurrenceStart(on date: Date = .now) -> Date? {
        guard isActive(on: date) else { return nil }
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        var day = date
        // Post-midnight part of an overnight window belongs to yesterday's occurrence.
        if crossesMidnight && minutes < startHour * 60 + startMinute {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
            day = yesterday
        }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        return calendar.date(from: components)
    }

    func endDate(on date: Date = .now) -> Date? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        func endDate(onCalendarDayOf referenceDate: Date) -> Date? {
            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = endHour
            components.minute = endMinute
            components.second = 0
            return calendar.date(from: components)
        }

        if weekdays.contains(weekday) {
            guard let sameDayEnd = endDate(onCalendarDayOf: date) else { return nil }
            return crossesMidnight ? calendar.date(byAdding: .day, value: 1, to: sameDayEnd) : sameDayEnd
        }

        let previousWeekday = weekday == 1 ? 7 : weekday - 1
        if crossesMidnight && weekdays.contains(previousWeekday) {
            return endDate(onCalendarDayOf: date)
        }

        return nil
    }

    private static func format(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
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
            nfcUnlockEnabled: response.nfcUnlockEnabled,
            strictModeEnabled: false,
            blockAppInstallation: false,
            blockAdultContent: false
        )
    }

    func withProtection(
        strictModeEnabled: Bool,
        blockAppInstallation: Bool,
        blockAdultContent: Bool
    ) -> RitualScheduler {
        RitualScheduler(
            id: id,
            coreRitualId: coreRitualId,
            title: title,
            detail: detail,
            focusTarget: focusTarget,
            symbolName: symbolName,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            weekdays: weekdays,
            selection: selection,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            strictModeEnabled: strictModeEnabled,
            blockAppInstallation: blockAppInstallation,
            blockAdultContent: blockAdultContent,
            breakCount: breakCount,
            breakDurationMinutes: breakDurationMinutes
        )
    }

    func withBreakConfig(breakCount: Int, breakDurationMinutes: Int) -> RitualScheduler {
        RitualScheduler(
            id: id,
            coreRitualId: coreRitualId,
            title: title,
            detail: detail,
            focusTarget: focusTarget,
            symbolName: symbolName,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            weekdays: weekdays,
            selection: selection,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            strictModeEnabled: strictModeEnabled,
            blockAppInstallation: blockAppInstallation,
            blockAdultContent: blockAdultContent,
            breakCount: breakCount,
            breakDurationMinutes: breakDurationMinutes
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

    func breakConfigRequest() -> SaveBreakConfigRequest {
        SaveBreakConfigRequest(breakCount: breakCount, breakDurationMinutes: breakDurationMinutes)
    }

    func updateRitualRequest(password: String? = nil) -> UpdateRitualRequest {
        UpdateRitualRequest(
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

        items += selection.applicationTokens
            .map { Self.encodedTokenIdentifier($0, fallback: "app-unavailable") }
            .sorted()
            .enumerated().map { index, identifier in
            RitualBlockedItemRequest(
                type: "app",
                identifier: identifier,
                displayName: "App \(index + 1)",
                bundleIdentifier: nil
            )
        }

        items += selection.categoryTokens
            .map { Self.encodedTokenIdentifier($0, fallback: "category-unavailable") }
            .sorted()
            .enumerated().map { index, identifier in
            RitualBlockedItemRequest(
                type: "category",
                identifier: identifier,
                displayName: "Categoria \(index + 1)",
                bundleIdentifier: nil
            )
        }

        items += selection.webDomainTokens
            .map { Self.encodedTokenIdentifier($0, fallback: "domain-unavailable") }
            .sorted()
            .enumerated().map { index, identifier in
            RitualBlockedItemRequest(
                type: "domain",
                identifier: identifier,
                displayName: "Web \(index + 1)",
                bundleIdentifier: nil
            )
        }

        // Identifiers are ordered before numbering display names, so both stay stable.
        items.sort { ($0.type, $0.identifier) < ($1.type, $1.identifier) }

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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(token) else {
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
        case strictModeEnabled
        case blockAppInstallation
        case blockAdultContent
        case breakCount
        case breakDurationMinutes
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
            nfcUnlockEnabled: try container.decodeIfPresent(Bool.self, forKey: .nfcUnlockEnabled) ?? false,
            strictModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .strictModeEnabled) ?? false,
            blockAppInstallation: try container.decodeIfPresent(Bool.self, forKey: .blockAppInstallation) ?? false,
            blockAdultContent: try container.decodeIfPresent(Bool.self, forKey: .blockAdultContent) ?? false,
            breakCount: try container.decodeIfPresent(Int.self, forKey: .breakCount) ?? 0,
            breakDurationMinutes: try container.decodeIfPresent(Int.self, forKey: .breakDurationMinutes) ?? 5
        )
    }
}
