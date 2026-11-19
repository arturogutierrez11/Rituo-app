import UserNotifications

/// Presentation only: identifiers, delivery claims and triggers stay with the caller.
enum RituoNotificationStyle {
    static let category = "RITUO_FOCUS_STATUS"

    static func apply(to content: UNMutableNotificationContent, name: String,
                      groupID: String, event: String, detail: String? = nil) {
        content.categoryIdentifier = category
        content.threadIdentifier = "rituo.focus.\(groupID)"
        content.subtitle = name
        content.userInfo["rituo.event"] = event
        if let detail { content.userInfo["rituo.detail"] = detail }
    }

    static func registerCategories() {
        let open = UNNotificationAction(identifier: "RITUO_OPEN", title: "Abrir Rituo", options: [.foreground])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [open], intentIdentifiers: [], options: [])
        ])
    }
}
