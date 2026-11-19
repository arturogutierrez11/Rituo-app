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

        let startedAt = ProcessInfo.processInfo.systemUptime
        let requestID = UUID().uuidString
        #if DEBUG
        print("Safari reload start id=\(requestID) enabled=\(isEnabled)")
        #endif
        SFContentBlockerManager.reloadContentBlocker(
            withIdentifier: extensionIdentifier
        ) { error in
            let elapsedMs = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
            if let error {
                let nsError = error as NSError
                print("Safari reload failed id=\(requestID) enabled=\(isEnabled) elapsed_ms=\(elapsedMs) domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) reason=\(nsError.localizedFailureReason ?? "none")")
                return
            }

            #if DEBUG
            print("Safari reload completed id=\(requestID) enabled=\(isEnabled) elapsed_ms=\(elapsedMs)")
            #endif
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

            #if DEBUG
            print("Safari content blocker extension enabled:", state?.isEnabled == true)
            #endif
        }
    }
}
