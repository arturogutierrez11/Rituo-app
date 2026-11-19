import Foundation

/// Calendar-based boundaries preserve local wall-clock times across DST changes.
enum LiveActivitySchedulePlanner {
    static func next(weekdays: [Int], startHour: Int, startMinute: Int,
                     endHour: Int, endMinute: Int, now: Date,
                     calendar: Calendar = .current) -> DateInterval? {
        guard startHour != endHour || startMinute != endMinute else { return nil }
        let starts = weekdays.filter { (1...7).contains($0) }.compactMap { day in
            calendar.nextDate(after: now, matching: DateComponents(hour: startHour,
                minute: startMinute, second: 0, weekday: day),
                matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }
        guard let start = starts.min() else { return nil }
        let overnight = endHour * 60 + endMinute < startHour * 60 + startMinute
        let endDay = overnight ? calendar.date(byAdding: .day, value: 1, to: start) : start
        guard let endDay,
              let end = calendar.date(bySettingHour: endHour, minute: endMinute,
                  second: 0, of: endDay, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }
}
