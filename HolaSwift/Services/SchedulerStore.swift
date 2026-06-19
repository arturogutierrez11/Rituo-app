import Foundation

final class SchedulerStore {
    private let defaults: UserDefaults
    private let key = "rituo.schedulers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [RitualScheduler] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        do {
            let schedulers = try JSONDecoder().decode([RitualScheduler].self, from: data)
            let userSchedulers = schedulers.filter { !$0.isLegacyDemoScheduler }

            if userSchedulers.count != schedulers.count {
                save(userSchedulers)
            }

            return userSchedulers
        } catch {
            return []
        }
    }

    func save(_ schedulers: [RitualScheduler]) {
        guard let data = try? JSONEncoder().encode(schedulers) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
