import Foundation
import SafariServices

enum SafariContentBlockerController {
    static let extensionIdentifier = "io.rituo.app.SafariContentBlocker"
    static let enabledDefaultsKey = "rituo.safariContentBlocker.enabled"

    private static let appGroupIdentifier = "group.io.rituo.app"

    static func setBlockingEnabled(_ isEnabled: Bool) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(isEnabled, forKey: enabledDefaultsKey)
        defaults?.synchronize()

        SFContentBlockerManager.reloadContentBlocker(
            withIdentifier: extensionIdentifier
        ) { error in
            if let error {
                print("Safari content blocker reload error:", error.localizedDescription)
                return
            }

            print("Safari content blocker reloaded. Blocking enabled:", isEnabled)
            logExtensionState()
        }
    }

    static func isExtensionEnabled() async -> Bool {
        await withCheckedContinuation { continuation in
            SFContentBlockerManager.getStateOfContentBlocker(
                withIdentifier: extensionIdentifier
            ) { state, error in
                if let error {
                    print("Safari content blocker state error:", error.localizedDescription)
                }
                continuation.resume(returning: state?.isEnabled == true)
            }
        }
    }

    private static func logExtensionState() {
        SFContentBlockerManager.getStateOfContentBlocker(
            withIdentifier: extensionIdentifier
        ) { state, error in
            if let error {
                print("Safari content blocker state error:", error.localizedDescription)
                return
            }

            print("Safari content blocker extension enabled:", state?.isEnabled == true)
        }
    }
}
