//
//  AntigravityUsageData.swift
//  Agent Ring
//

import Foundation

// MARK: - 内部数据模型

/// Antigravity 使用量数据（应用内部使用的标准化结构）
struct AntigravityUsageData: Sendable {
    /// 5小时主窗口用量（Gemini 核心模型）
    let primary: LimitData?
    /// 7天/周级次窗口用量（Gemini 核心模型）
    let secondary: LimitData?
    /// 所有模型分组的详细额度列表
    let groups: [ModelGroup]

    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 剩余比例 (0.0 - 1.0)
        let remainingFraction: Double
        /// 重置时间
        let resetsAt: Date?
        /// 描述信息
        let description: String?
    }

    struct ModelGroup: Sendable {
        let displayName: String
        let description: String?
        let fiveHourLimit: LimitData?
        let weeklyLimit: LimitData?
    }

    /// 便捷访问 Gemini 核心模型组
    var geminiGroup: ModelGroup? {
        groups.first { $0.displayName.localizedCaseInsensitiveContains("gemini") } ?? groups.first
    }

    /// 便捷访问 Claude 与 GPT 第三方模型组
    var thirdPartyGroup: ModelGroup? {
        groups.first { $0.displayName.localizedCaseInsensitiveContains("claude") || $0.displayName.localizedCaseInsensitiveContains("gpt") }
            ?? (groups.count > 1 ? groups[1] : nil)
    }

    /// Gemini 5小时主窗口额度
    var geminiPrimary: LimitData? { geminiGroup?.fiveHourLimit ?? primary }
    /// Gemini 周级额度
    var geminiSecondary: LimitData? { geminiGroup?.weeklyLimit ?? secondary }

    /// Claude / GPT 5小时主窗口额度
    var thirdPartyPrimary: LimitData? { thirdPartyGroup?.fiveHourLimit }
    /// Claude / GPT 周级额度
    var thirdPartySecondary: LimitData? { thirdPartyGroup?.weeklyLimit }
}

extension AntigravityUsageData.LimitData {
    func asUsageLimitData() -> UsageLimitData {
        UsageLimitData(percentage: percentage, resetsAt: resetsAt)
    }
}

// MARK: - API 响应模型

nonisolated struct AntigravityQuotaResponse: Codable, Sendable {
    let groups: [GroupResponse]?
    let description: String?

    // 兼容本地 ConnectRPC 包装：{"response": {"groups": [...]}}
    let response: InnerResponse?

    struct InnerResponse: Codable, Sendable {
        let groups: [GroupResponse]?
        let description: String?
    }

    struct GroupResponse: Codable, Sendable {
        let displayName: String?
        let description: String?
        let buckets: [BucketResponse]?
    }

    struct BucketResponse: Codable, Sendable {
        let bucketId: String?
        let displayName: String?
        let description: String?
        let window: String?
        let remainingFraction: Double?
        let resetTime: String?
    }

    var effectiveGroups: [GroupResponse] {
        response?.groups ?? groups ?? []
    }

    func toUsageData() -> AntigravityUsageData {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let backupFormatter = ISO8601DateFormatter()
        backupFormatter.formatOptions = [.withInternetDateTime]

        let parseDate: (String?) -> Date? = { dateString in
            guard let dateString else { return nil }
            return isoFormatter.date(from: dateString) ?? backupFormatter.date(from: dateString)
        }

        let parsedGroups: [AntigravityUsageData.ModelGroup] = effectiveGroups.map { group in
            var fiveHour: AntigravityUsageData.LimitData?
            var weekly: AntigravityUsageData.LimitData?

            for bucket in group.buckets ?? [] {
                let remaining = bucket.remainingFraction ?? 1.0
                let usedPercent = max(0.0, min(100.0, (1.0 - remaining) * 100.0))
                let resetsAt = parseDate(bucket.resetTime)
                let limit = AntigravityUsageData.LimitData(
                    percentage: usedPercent,
                    remainingFraction: remaining,
                    resetsAt: resetsAt,
                    description: bucket.description
                )

                let window = bucket.window?.lowercased() ?? ""
                let bucketId = bucket.bucketId?.lowercased() ?? ""
                let displayName = bucket.displayName?.lowercased() ?? ""

                let isFiveHour = window.contains("5h")
                    || window.contains("5 hour")
                    || bucketId.contains("5h")
                    || displayName.contains("5 hour")
                    || displayName.contains("five hour")
                    || displayName.contains("5小时")

                let isWeekly = window.contains("week")
                    || window.contains("7d")
                    || window.contains("7 day")
                    || bucketId.contains("week")
                    || bucketId.contains("7d")
                    || displayName.contains("week")
                    || displayName.contains("7 day")
                    || displayName.contains("7天")
                    || displayName.contains("周")

                if isFiveHour {
                    fiveHour = limit
                } else if isWeekly {
                    weekly = limit
                }
            }

            return AntigravityUsageData.ModelGroup(
                displayName: group.displayName ?? "Models",
                description: group.description,
                fiveHourLimit: fiveHour,
                weeklyLimit: weekly
            )
        }

        // 默认将 Gemini 组（或第一个组）作为主菜单栏显示的 primary (5h) 和 secondary (weekly)
        let primaryGroup = parsedGroups.first { $0.displayName.localizedCaseInsensitiveContains("gemini") } ?? parsedGroups.first

        return AntigravityUsageData(
            primary: primaryGroup?.fiveHourLimit,
            secondary: primaryGroup?.weeklyLimit,
            groups: parsedGroups
        )
    }
}
