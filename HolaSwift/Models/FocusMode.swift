import FamilyControls
import Foundation

struct FocusMode: Identifiable, Hashable, Codable {
    static let defaultDisplaySymbolName = "scope"

    let id: String
    let coreModeId: String?
    var title: String
    var symbolName: String
    var selection: FamilyActivitySelection
    var isProtected: Bool
    var nfcUnlockEnabled: Bool
    var strictModeEnabled: Bool
    var blockAppInstallation: Bool
    var blockAdultContent: Bool
    /// Number of configured breaks (0-3). Synced via the dedicated
    /// `/modes/:id/breaks` endpoint, not the mode update request.
    var breakCount: Int
    /// Minutes per break (1-5). Only meaningful when `breakCount > 0`.
    var breakDurationMinutes: Int

    init(
        id: String,
        coreModeId: String? = nil,
        title: String,
        symbolName: String,
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
        self.coreModeId = coreModeId
        self.title = title
        self.symbolName = symbolName
        self.selection = selection
        self.isProtected = isProtected
        self.nfcUnlockEnabled = nfcUnlockEnabled
        self.strictModeEnabled = strictModeEnabled
        self.blockAppInstallation = blockAppInstallation
        self.blockAdultContent = blockAdultContent
        self.breakCount = max(0, min(3, breakCount))
        self.breakDurationMinutes = max(1, min(15, breakDurationMinutes))
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

    var displaySymbolName: String {
        Self.defaultDisplaySymbolName
    }

    var selectedItemCount: Int {
        appCount + categoryCount + domainCount
    }

    var hasBlockingConfiguration: Bool {
        selectedItemCount > 0 ||
            strictModeEnabled ||
            blockAdultContent ||
            blockAppInstallation
    }

    var blockingRuleCount: Int {
        selectedItemCount
            + (strictModeEnabled ? 1 : 0)
            + (blockAdultContent ? 1 : 0)
            + (blockAppInstallation ? 1 : 0)
    }

    var selectionDigest: String {
        RitualScheduler.selectionDigest(for: selection)
    }

    static let defaults: [FocusMode] = [
        FocusMode(
            id: "gym",
            title: "Gimnasio",
            symbolName: "dumbbell.fill",
            selection: FamilyActivitySelection()
        ),
        FocusMode(
            id: "meeting",
            title: "Reunión",
            symbolName: "person.2.fill",
            selection: FamilyActivitySelection()
        ),
        FocusMode(
            id: "reading",
            title: "Lectura",
            symbolName: "book.closed.fill",
            selection: FamilyActivitySelection()
        ),
        FocusMode(
            id: "work",
            title: "Trabajar",
            symbolName: "laptopcomputer",
            selection: FamilyActivitySelection()
        ),
        FocusMode(
            id: "sleep",
            title: "Dormir",
            symbolName: "moon.stars.fill",
            selection: FamilyActivitySelection()
        )
    ]

    static func == (lhs: FocusMode, rhs: FocusMode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FocusMode {
    init(response: ModeResponse, preserving selection: FamilyActivitySelection = FamilyActivitySelection()) {
        self.init(
            id: response.templateKey,
            coreModeId: response.id,
            title: response.title,
            symbolName: response.icon,
            selection: selection,
            isProtected: response.isProtected,
            nfcUnlockEnabled: response.nfcUnlockEnabled,
            blockAdultContent: false
        )
    }

    func breakConfigRequest() -> SaveBreakConfigRequest {
        SaveBreakConfigRequest(breakCount: breakCount, breakDurationMinutes: breakDurationMinutes)
    }

    func updateModeRequest(password: String? = nil) -> UpdateModeRequest {
        UpdateModeRequest(
            title: title,
            icon: symbolName,
            appCount: appCount,
            categoryCount: categoryCount,
            domainCount: domainCount,
            selectionDigest: selectedItemCount > 0 ? selectionDigest : nil,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            password: isProtected ? password : nil
        )
    }

    var blockedItemsRequest: ReplaceModeBlockedItemsRequest {
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

        return ReplaceModeBlockedItemsRequest(items: items)
    }

    private static func encodedTokenIdentifier<T: Encodable>(_ token: T, fallback: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(token) else {
            return fallback
        }

        return data.base64EncodedString()
    }
}

extension FocusMode {
    private enum CodingKeys: String, CodingKey {
        case id
        case coreModeId
        case title
        case symbolName
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
            id: try container.decode(String.self, forKey: .id),
            coreModeId: try container.decodeIfPresent(String.self, forKey: .coreModeId),
            title: try container.decode(String.self, forKey: .title),
            symbolName: try container.decode(String.self, forKey: .symbolName),
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
