import Foundation

final class SchedulerStore {
    private let defaults: UserDefaults
    private let legacyKey = "rituo.schedulers"
    private let accountKeyPrefix = "rituo.schedulers.account"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(accountID: String) -> [RitualScheduler] {
        let key = accountKey(for: accountID)
        migrateLegacySchedulersIfNeeded(to: key)

        guard let data = defaults.data(forKey: key) else {
            return []
        }

        do {
            let schedulers = try JSONDecoder().decode([RitualScheduler].self, from: data)
            let userSchedulers = schedulers.filter { !$0.isLegacyDemoScheduler }

            if userSchedulers.count != schedulers.count {
                save(userSchedulers, accountID: accountID)
            }

            return userSchedulers
        } catch {
            return []
        }
    }

    func save(_ schedulers: [RitualScheduler], accountID: String) {
        guard let data = try? JSONEncoder().encode(schedulers) else {
            return
        }

        defaults.set(data, forKey: accountKey(for: accountID))
    }

    func clear(accountID: String) {
        defaults.removeObject(forKey: accountKey(for: accountID))
    }

    private func accountKey(for accountID: String) -> String {
        "\(accountKeyPrefix).\(accountID)"
    }

    private func migrateLegacySchedulersIfNeeded(to accountKey: String) {
        guard defaults.object(forKey: accountKey) == nil,
              let legacyData = defaults.data(forKey: legacyKey) else {
            return
        }

        defaults.set(legacyData, forKey: accountKey)
        defaults.removeObject(forKey: legacyKey)
    }
}
