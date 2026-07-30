import Foundation

struct AppUpdateStatusResponse: Codable, Identifiable, Equatable {
    let updateAvailable: Bool
    let updateRequired: Bool
    let currentVersion: String?
    let currentBuild: Int
    let latestVersion: String?
    let latestBuild: Int?
    let minimumBuild: Int?
    let title: String?
    let message: String?
    let storeUrl: String?

    var id: Int {
        latestBuild ?? currentBuild
    }

    var storeURL: URL? {
        guard let storeUrl else { return nil }
        return URL(string: storeUrl)
    }
}
