import Foundation

public enum DateFormatting {
    public static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    public static func shortDate(_ date: Date?) -> String {
        guard let date else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    public static func localDateTime(_ date: Date?) -> String {
        guard let date else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    public static func relativeResetText(resetAt: Date?, now: Date = Date()) -> String {
        guard let resetAt else {
            return ""
        }
        let seconds = Int(resetAt.timeIntervalSince(now))
        guard seconds > 0 else {
            return "已重置"
        }

        let minutes = max(1, seconds / 60)
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let mins = minutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)天\(hours)小时后" : "\(days)天后"
        }
        if hours > 0 {
            return mins > 0 ? "\(hours)小时\(mins)分后" : "\(hours)小时后"
        }
        return "\(mins)分后"
    }
}
