//
//  NotificationManager.swift
//  SplitBill
//

import UserNotifications

struct NotificationManager {

    // MARK: - Permission

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
                if let error { print("[Notifications] ❌ Permission error: \(error)") }
            }
    }

    // MARK: - Schedule

    static func scheduleReminder(for person: HistoryPerson, bill: BillHistory, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Payment Reminder"
        content.body  = "\(person.name) hasn't paid \(person.amount.toCurrency()) for \"\(bill.title.isEmpty ? "your bill" : bill.title)\""
        content.sound = .default
        content.userInfo = ["billId": bill.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(billId: bill.id, personId: person.id),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[Notifications] ❌ Schedule error: \(error)") }
            else { print("[Notifications] ✅ Reminder set for \(person.name) at \(date)") }
        }
    }

    // MARK: - Cancel

    static func cancelReminder(billId: UUID, personId: UUID) {
        let id = notificationId(billId: billId, personId: personId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Query

    static func pendingPersonIds(for billId: UUID, completion: @escaping (Set<UUID>) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let prefix = "reminder-\(billId.uuidString)-"
            let ids: Set<UUID> = Set(
                requests
                    .filter { $0.identifier.hasPrefix(prefix) }
                    .compactMap { req -> UUID? in
                        let personIdString = String(req.identifier.dropFirst(prefix.count))
                        return UUID(uuidString: personIdString)
                    }
            )
            DispatchQueue.main.async { completion(ids) }
        }
    }

    // MARK: - Helpers

    static func reminderDate(option: ReminderOption) -> Date {
        let cal = Calendar.current
        let now = Date()
        switch option {
        case .inOneHour:
            return now.addingTimeInterval(3600)
        case .tonight:
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: now)
                ?? now.addingTimeInterval(3600)
        case .tomorrowMorning:
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
                ?? tomorrow
        case .inThreeDays:
            let threeDays = cal.date(byAdding: .day, value: 3, to: now)!
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: threeDays)
                ?? threeDays
        }
    }

    private static func notificationId(billId: UUID, personId: UUID) -> String {
        "reminder-\(billId.uuidString)-\(personId.uuidString)"
    }
}

// MARK: - Reminder Option

enum ReminderOption: CaseIterable {
    case inOneHour, tonight, tomorrowMorning, inThreeDays

    var label: String {
        switch self {
        case .inOneHour:       return "In 1 Hour"
        case .tonight:         return "Tonight (8:00 PM)"
        case .tomorrowMorning: return "Tomorrow Morning (9:00 AM)"
        case .inThreeDays:     return "In 3 Days"
        }
    }
}
