import Foundation
import UserNotifications

final class RitualNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let debugStore = DeviceActivityDebugStore()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [debugStore] granted, error in
            if let error {
                debugStore.log("Error permiso notificaciones: \(error.localizedDescription)")
                return
            }

            debugStore.log("Permiso notificaciones: \(granted ? "aprobado" : "rechazado")")
        }
    }

    func rescheduleNotifications(for schedulers: [RitualScheduler]) {
        let identifiers = schedulers.flatMap { scheduler in
            scheduler.weekdays.flatMap { weekday in
                [
                    notificationIdentifier(for: scheduler, weekday: weekday),
                    endNotificationIdentifier(for: scheduler, weekday: weekday)
                ]
            } + [
                nextNotificationIdentifier(for: scheduler),
                nextEndNotificationIdentifier(for: scheduler)
            ]
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for scheduler in schedulers where scheduler.selectedItemCount > 0 {
            scheduleNotification(for: scheduler)
            scheduleEndNotification(for: scheduler)
        }
    }

    func sendRitualStartedNotification(for scheduler: RitualScheduler) {
        let content = UNMutableNotificationContent()
        content.title = "Ritual activo"
        content.body = startNotificationBody(for: scheduler)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "rituo.ritual.started.\(scheduler.id.uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func sendRitualStoppedNotification(for scheduler: RitualScheduler?, endSource: String) {
        let content = UNMutableNotificationContent()
        content.title = "Ritual desactivado"
        content.body = scheduler.map { "\($0.title) se detuvo. Las apps vuelven a estar disponibles." } ?? "Se detuvo el ritual activo. Las apps vuelven a estar disponibles."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "rituo.ritual.stopped.\(scheduler?.id.uuidString ?? UUID().uuidString).\(endSource)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    private func scheduleNextEndNotification(for scheduler: RitualScheduler) {
        guard let nextDate = nextEndDate(for: scheduler) else {
            debugStore.log("Sin próxima notificación de fin para \(scheduler.title).")
            return
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        let content = UNMutableNotificationContent()
        content.title = "Ritual finalizado"
        content.body = "\(scheduler.title) terminó. Las apps vuelven a estar disponibles."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: nextEndNotificationIdentifier(for: scheduler),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        center.add(request) { [debugStore] error in
            if let error {
                debugStore.log("Error notificación próxima fin \(scheduler.title): \(error.localizedDescription)")
            } else {
                debugStore.log("Notificación próxima fin \(scheduler.title): \(Self.formatDate(nextDate)).")
            }
        }
    }

    private func scheduleNextOccurrenceNotification(for scheduler: RitualScheduler) {
        guard let nextDate = nextStartDate(for: scheduler) else {
            debugStore.log("Sin próxima notificación para \(scheduler.title).")
            return
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        let content = UNMutableNotificationContent()
        content.title = "Tu ritual empieza ahora"
        content.body = startNotificationBody(for: scheduler)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: nextNotificationIdentifier(for: scheduler),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        center.add(request) { [debugStore] error in
            if let error {
                debugStore.log("Error notificación próxima \(scheduler.title): \(error.localizedDescription)")
            } else {
                debugStore.log("Notificación próxima \(scheduler.title): \(Self.formatDate(nextDate)).")
            }
        }
    }

    private func scheduleEndNotification(for scheduler: RitualScheduler) {
        for weekday in scheduler.weekdays {
            var components = DateComponents()
            components.calendar = calendar
            components.weekday = weekday
            components.hour = scheduler.endHour
            components.minute = scheduler.endMinute

            let content = UNMutableNotificationContent()
            content.title = "Ritual finalizado"
            content.body = "\(scheduler.title) terminó. Las apps vuelven a estar disponibles."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: endNotificationIdentifier(for: scheduler, weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            center.add(request) { [debugStore] error in
                if let error {
                    debugStore.log("Error notificación semanal fin \(scheduler.title): \(error.localizedDescription)")
                } else {
                    debugStore.log("Notificación semanal fin \(scheduler.title) weekday=\(weekday) \(Self.format(hour: scheduler.endHour, minute: scheduler.endMinute)).")
                }
            }
        }
    }

    private func scheduleNotification(for scheduler: RitualScheduler) {
        for weekday in scheduler.weekdays {
            var components = DateComponents()
            components.calendar = calendar
            components.weekday = weekday
            components.hour = scheduler.startHour
            components.minute = scheduler.startMinute

            let content = UNMutableNotificationContent()
            content.title = "Tu ritual empieza ahora"
            content.body = startNotificationBody(for: scheduler)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: scheduler, weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            center.add(request) { [debugStore] error in
                if let error {
                    debugStore.log("Error notificación semanal \(scheduler.title): \(error.localizedDescription)")
                } else {
                    debugStore.log("Notificación semanal \(scheduler.title) weekday=\(weekday) \(Self.format(hour: scheduler.startHour, minute: scheduler.startMinute)).")
                }
            }
        }
    }

    private func nextEndDate(for scheduler: RitualScheduler, now: Date = .now) -> Date? {
        scheduler.weekdays.compactMap { weekday in
            var components = DateComponents()
            components.calendar = calendar
            components.weekday = weekday
            components.hour = scheduler.endHour
            components.minute = scheduler.endMinute
            components.second = 0
            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        }
        .min()
    }

    private func nextStartDate(for scheduler: RitualScheduler, now: Date = .now) -> Date? {
        scheduler.weekdays.compactMap { weekday in
            var components = DateComponents()
            components.calendar = calendar
            components.weekday = weekday
            components.hour = scheduler.startHour
            components.minute = scheduler.startMinute
            components.second = 0
            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        }
        .min()
    }

    private func notificationIdentifier(for scheduler: RitualScheduler, weekday: Int) -> String {
        "rituo.ritual.notification.\(scheduler.id.uuidString).weekday.\(weekday)"
    }

    private func endNotificationIdentifier(for scheduler: RitualScheduler, weekday: Int) -> String {
        "rituo.ritual.notification.end.\(scheduler.id.uuidString).weekday.\(weekday)"
    }

    private func nextNotificationIdentifier(for scheduler: RitualScheduler) -> String {
        "rituo.ritual.notification.next.\(scheduler.id.uuidString)"
    }

    private func nextEndNotificationIdentifier(for scheduler: RitualScheduler) -> String {
        "rituo.ritual.notification.next.end.\(scheduler.id.uuidString)"
    }

    private func startNotificationBody(for scheduler: RitualScheduler) -> String {
        "\(scheduler.title) está activo. \(scheduler.selectionDigest) en pausa hasta las \(scheduler.endTimeText)."
    }

    private static func format(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }
}
