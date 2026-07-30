import FirebaseCore
import FirebaseCrashlytics
import Foundation

enum CrashReportingService {
    private static var isConfigured = false

    static func configure(bundle: Bundle = .main) {
        guard !isConfigured else {
            return
        }

        guard
            let configurationPath = bundle.path(
                forResource: "GoogleService-Info",
                ofType: "plist"
            ),
            let options = FirebaseOptions(contentsOfFile: configurationPath)
        else {
            #if DEBUG
            print(
                "[Crashlytics] GoogleService-Info.plist no está disponible; "
                    + "los reportes de fallos están desactivados."
            )
            #endif
            return
        }

        FirebaseApp.configure(options: options)
        isConfigured = true

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "unknown",
            forKey: "app_version"
        )
        crashlytics.setCustomValue(
            bundle.object(forInfoDictionaryKey: "CFBundleVersion")
                as? String ?? "unknown",
            forKey: "app_build"
        )
    }

    static func record(
        _ error: Error,
        context: [String: Any] = [:]
    ) {
        guard isConfigured else {
            return
        }

        let crashlytics = Crashlytics.crashlytics()
        context.forEach { key, value in
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.record(error: error)
    }

    static func log(_ message: String) {
        guard isConfigured else {
            return
        }

        Crashlytics.crashlytics().log(message)
    }
}
