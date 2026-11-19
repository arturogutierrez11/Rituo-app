import Foundation

enum AppEnvironment {
    static let authAPIBaseURL = requiredBaseURL(for: "AuthAPIBaseURL")
    static let coreAPIBaseURL = requiredBaseURL(for: "CoreAPIBaseURL")

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "AppEnvironment") as? String ?? "unknown"
    }

    private static func requiredBaseURL(for key: String) -> String {
        guard
            let configuredValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !configuredValue.isEmpty,
            let url = URL(string: configuredValue),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            preconditionFailure("Missing or invalid \(key) in the app configuration.")
        }

        if name == "local-simulator" {
            #if DEBUG && targetEnvironment(simulator)
            precondition(url.host == "127.0.0.1" && scheme == "http",
                         "Local simulator tests must use loopback APIs.")
            #else
            preconditionFailure("Local test configuration is only supported in the Debug simulator.")
            #endif
        }

        return configuredValue.hasSuffix("/")
            ? String(configuredValue.dropLast())
            : configuredValue
    }
}
