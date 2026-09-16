//
//  UsageData+Formatting.swift
//  CodexRings
//

import Foundation

struct UsageLimitData {
    let percentage: Double
    let resetsAt: Date?
}

extension UsageLimitData {
    var formattedCompactRemaining: String {
        guard let resetsAt else { return "-" }
        let resetsIn = resetsAt.timeIntervalSinceNow
        guard resetsIn > 0 else { return L.UsageData.compactResettingSoon }

        let totalMinutes = Int(ceil(resetsIn / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let totalHours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if totalHours < 24 {
            if remainingMinutes == 0 {
                return "\(totalHours)h"
            }
            return "\(totalHours)h \(remainingMinutes)m"
        }

        let days = totalHours / 24
        let hours = totalHours % 24
        if hours == 0 {
            return "\(days)d"
        }
        return "\(days)d \(hours)h"
    }

    var formattedCompactResetDateWithMinutes: String {
        guard let resetsAt else { return "-" }
        var calendar = Calendar.current
        calendar.locale = UserSettings.shared.appLocale
        let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

        if calendar.isDateInToday(resetsAt) {
            return "\(L.DetailRow.today) \(timeString)"
        }
        if calendar.isDateInTomorrow(resetsAt) {
            return "\(L.UsageData.tomorrow) \(timeString)"
        }
        return TimeFormatHelper.formatDateMinute(resetsAt, dateTemplate: "MMMd")
    }

    /// 剩余时间展示：短格式形式
    var formattedCompactRemainingWithMinutes: String {
        formattedCompactRemaining
    }
}
