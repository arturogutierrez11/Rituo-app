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
        AppDiagnostics.shared.start()
        let diagnosticSpan = AppDiagnostics.shared.begin("app.init")
        defer { AppDiagnostics.shared.end("app.init", diagnosticSpan) }
        let firebaseSpan = AppDiagnostics.shared.begin("startup.firebase")
        CrashReportingService.configure()
        AppDiagnostics.shared.end("startup.firebase", firebaseSpan)
        let servicesSpan = AppDiagnostics.shared.begin("startup.services")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: GoogleSignInConfig.clientID
        )
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        RituoNotificationStyle.registerCategories()
        AppDiagnostics.shared.end("startup.services", servicesSpan)
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
