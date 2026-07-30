import GoogleSignIn
import SwiftUI
import UserNotifications

final class RituoNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@main
struct HolaSwiftApp: App {
    private static let notificationDelegate = RituoNotificationDelegate()

    init() {
        CrashReportingService.configure()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: GoogleSignInConfig.clientID
        )
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RituoRootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
