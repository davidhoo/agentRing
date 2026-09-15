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
            return L.UsageData.compactRemainingMinutes(totalMinutes)
        }

        let totalHours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if totalHours < 24 {
            return L.UsageData.compactRemainingHours(totalHours, remainingMinutes)
        }

        let days = totalHours / 24
        let hours = totalHours % 24
        return L.UsageData.compactRemainingDays(days, hours)
    }

    var formattedCompactResetDateWithMinutes: String {
        guard let resetsAt else { return "-" }
        return TimeFormatHelper.formatDateMinute(resetsAt, dateTemplate: "MMMd")
    }

    /// 剩余时间展示：不足 1 天保留分；≥1 天只保留天+小时，避免挤扁左侧标签
    var formattedCompactRemainingWithMinutes: String {
        guard let resetsAt else { return "-" }
        let resetsIn = resetsAt.timeIntervalSinceNow
        guard resetsIn > 0 else { return L.UsageData.compactResettingSoon }

        let totalMinutes = Int(ceil(resetsIn / 60))
        if totalMinutes < 60 {
            return L.UsageData.compactRemainingMinutes(totalMinutes)
        }

        let totalHours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        if totalHours < 24 {
            return L.UsageData.compactRemainingHours(totalHours, remainingMinutes)
        }

        let days = totalHours / 24
        let hours = totalHours % 24
        return L.UsageData.compactRemainingDays(days, hours)
    }
}
