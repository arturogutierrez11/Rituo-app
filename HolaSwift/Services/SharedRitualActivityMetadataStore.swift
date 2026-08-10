import Foundation

struct SharedRitualActivityMetadata: Codable {
    let activityName: String
    let userID: String?
    let schedulerId: String
    let coreRitualId: String?
    let title: String
    let plannedEndAt: Date?
    let endHour: Int?
    let endMinute: Int?
    let priority: Int
    let strictModeEnabled: Bool
    let blockAppInstallation: Bool
    let blockAdultContent: Bool

    private enum CodingKeys: String, CodingKey {
        case activityName
        case userID
        case schedulerId
        case coreRitualId
        case title
        case plannedEndAt
        case endHour
        case endMinute
        case priority
        case strictModeEnabled
        case blockAppInstallation
        case blockAdultContent
    }

    init(
        activityName: String,
        userID: String?,
        schedulerId: String,
        coreRitualId: String?,
        title: String,
        plannedEndAt: Date?,
        endHour: Int?,
        endMinute: Int?,
        priority: Int = .max,
        strictModeEnabled: Bool = false,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false
    ) {
        self.activityName = activityName
        self.userID = userID
        self.schedulerId = schedulerId
        self.coreRitualId = coreRitualId
        self.title = title
        self.plannedEndAt = plannedEndAt
        self.endHour = endHour
        self.endMinute = endMinute
        self.priority = priority
        self.strictModeEnabled = strictModeEnabled
        self.blockAppInstallation = blockAppInstallation
        self.blockAdultContent = blockAdultContent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            activityName: try container.decode(String.self, forKey: .activityName),
            userID: try container.decodeIfPresent(String.self, forKey: .userID),
            schedulerId: try container.decode(String.self, forKey: .schedulerId),
            coreRitualId: try container.decodeIfPresent(String.self, forKey: .coreRitualId),
            title: try container.decode(String.self, forKey: .title),
            plannedEndAt: try container.decodeIfPresent(Date.self, forKey: .plannedEndAt),
            endHour: try container.decodeIfPresent(Int.self, forKey: .endHour),
            endMinute: try container.decodeIfPresent(Int.self, forKey: .endMinute),
            priority: try container.decodeIfPresent(Int.self, forKey: .priority) ?? .max,
            strictModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .strictModeEnabled) ?? false,
            blockAppInstallation: try container.decodeIfPresent(Bool.self, forKey: .blockAppInstallation) ?? false,
            blockAdultContent: try container.decodeIfPresent(Bool.self, forKey: .blockAdultContent) ?? false
        )
    }
}

struct SharedRitualActivityMetadataStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let keyPrefix = "rituo.deviceActivity.metadata."

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func save(metadata: SharedRitualActivityMetadata, for activityName: String) throws {
        let data = try JSONEncoder().encode(metadata)
        defaults?.set(data, forKey: Self.keyPrefix + activityName)
    }

    func loadMetadata(for activityName: String) -> SharedRitualActivityMetadata? {
        guard let data = defaults?.data(forKey: Self.keyPrefix + activityName) else {
            return nil
        }

        return try? JSONDecoder().decode(SharedRitualActivityMetadata.self, from: data)
    }

    func removeMetadata(for activityName: String) {
        defaults?.removeObject(forKey: Self.keyPrefix + activityName)
    }
}
