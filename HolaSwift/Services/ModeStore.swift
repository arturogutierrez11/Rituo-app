import Foundation

struct ActiveFocusModeRecord: Codable, Equatable {
    let accountID: String
    let modeID: FocusMode.ID
}

final class ModeStore {
    private let defaults: UserDefaults
    private let modesKeyPrefix = "rituo.modes."
    private let activeModeKey = "rituo.activeMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(accountID: String) -> [FocusMode] {
        let savedModes: [FocusMode]

        if let data = defaults.data(forKey: modesKey(for: accountID)),
           let decodedModes = try? JSONDecoder().decode([FocusMode].self, from: data) {
            savedModes = decodedModes
        } else {
            savedModes = []
        }

        let savedByID = Dictionary(uniqueKeysWithValues: savedModes.map { ($0.id, $0) })
        let modes = FocusMode.defaults.map { defaultMode in
            guard let savedMode = savedByID[defaultMode.id] else {
                return defaultMode
            }

            return FocusMode(
                id: defaultMode.id,
                coreModeId: savedMode.coreModeId,
                title: savedMode.title.isEmpty ? defaultMode.title : savedMode.title,
                symbolName: savedMode.symbolName.isEmpty ? defaultMode.symbolName : savedMode.symbolName,
                selection: savedMode.selection,
                isProtected: savedMode.isProtected,
                nfcUnlockEnabled: savedMode.nfcUnlockEnabled,
                strictModeEnabled: savedMode.strictModeEnabled,
                blockAppInstallation: savedMode.blockAppInstallation,
                blockAdultContent: savedMode.blockAdultContent
            )
        }

        save(modes, accountID: accountID)
        return modes
    }

    func save(_ modes: [FocusMode], accountID: String) {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        defaults.set(data, forKey: modesKey(for: accountID))
    }

    func loadActiveMode() -> ActiveFocusModeRecord? {
        guard let data = defaults.data(forKey: activeModeKey) else { return nil }
        return try? JSONDecoder().decode(ActiveFocusModeRecord.self, from: data)
    }

    func saveActiveMode(_ modeID: FocusMode.ID, accountID: String) {
        let record = ActiveFocusModeRecord(accountID: accountID, modeID: modeID)
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: activeModeKey)
    }

    func clearActiveMode() {
        defaults.removeObject(forKey: activeModeKey)
    }

    func clear(accountID: String) {
        defaults.removeObject(forKey: modesKey(for: accountID))
        if loadActiveMode()?.accountID == accountID {
            clearActiveMode()
        }
    }

    private func modesKey(for accountID: String) -> String {
        modesKeyPrefix + accountID
    }
}
