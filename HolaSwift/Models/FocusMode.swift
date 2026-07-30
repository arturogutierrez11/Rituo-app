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
        blockAdultContent: Bool = false
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

        return ReplaceModeBlockedItemsRequest(items: items)
    }

    private static func encodedTokenIdentifier<T: Encodable>(_ token: T, fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(token) else {
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
            blockAdultContent: try container.decodeIfPresent(Bool.self, forKey: .blockAdultContent) ?? false
        )
    }
}
