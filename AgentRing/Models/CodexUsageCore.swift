//
//  CodexUsageCore.swift
//  CodexRings
//

import Foundation

struct CodexCoreUsageData: Equatable, Sendable {
    let primary: LimitData?
    let secondary: LimitData?
    let extraUsage: ExtraUsageData?

    struct LimitData: Equatable, Sendable {
        let percentage: Double
        let resetsAt: Date?
    }

    struct ExtraUsageData: Equatable, Sendable {
        let hasCredits: Bool
        let unlimited: Bool
        let overageLimitReached: Bool
        let spendControlReached: Bool
        let balance: Decimal?
        let approxLocalMessages: [Int]?
        let approxCloudMessages: [Int]?

        var enabled: Bool {
            if hasCredits || unlimited || overageLimitReached || spendControlReached {
                return true
            }
            guard let balance else { return false }
            return balance > 0
        }

        var percentage: Double? {
            if overageLimitReached || spendControlReached {
                return 100
            }
            if enabled {
                return 0
            }
            return nil
        }
    }
}

struct CodexCoreUsageResponse: Codable, Sendable {
    let account_id: String?
    let email: String?
    let plan_type: String?
    let rate_limit: RateLimit?
    let credits: Credits?
    let spend_control: SpendControl?

    struct RateLimit: Codable, Sendable {
        let allowed: Bool?
        let limit_reached: Bool?
        let primary_window: Window?
        let secondary_window: Window?
    }

    struct Window: Codable, Sendable {
        let used_percent: Double
        let limit_window_seconds: Int?
        let reset_after_seconds: Int?
        let reset_at: Int?
    }

    struct Credits: Codable, Sendable {
        let has_credits: Bool?
        let unlimited: Bool?
        let overage_limit_reached: Bool?
        let balance: String?
        let approx_local_messages: [Int]?
        let approx_cloud_messages: [Int]?

        private enum CodingKeys: String, CodingKey {
            case has_credits
            case unlimited
            case overage_limit_reached
            case balance
            case approx_local_messages
            case approx_cloud_messages
        }

        init(
            has_credits: Bool?,
            unlimited: Bool?,
            overage_limit_reached: Bool?,
            balance: String?,
            approx_local_messages: [Int]?,
            approx_cloud_messages: [Int]?
        ) {
            self.has_credits = has_credits
            self.unlimited = unlimited
            self.overage_limit_reached = overage_limit_reached
            self.balance = balance
            self.approx_local_messages = approx_local_messages
            self.approx_cloud_messages = approx_cloud_messages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            has_credits = try container.decodeIfPresent(Bool.self, forKey: .has_credits)
            unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited)
            overage_limit_reached = try container.decodeIfPresent(Bool.self, forKey: .overage_limit_reached)
            approx_local_messages = try container.decodeIfPresent([Int].self, forKey: .approx_local_messages)
            approx_cloud_messages = try container.decodeIfPresent([Int].self, forKey: .approx_cloud_messages)

            if let stringBalance = try? container.decodeIfPresent(String.self, forKey: .balance) {
                balance = stringBalance
            } else if let doubleBalance = try? container.decodeIfPresent(Double.self, forKey: .balance) {
                balance = String(doubleBalance)
            } else if let intBalance = try? container.decodeIfPresent(Int.self, forKey: .balance) {
                balance = String(intBalance)
            } else {
                balance = nil
            }
        }
    }

    struct SpendControl: Codable, Sendable {
        let reached: Bool?
    }

    func toUsageData(now: Date = Date()) -> CodexCoreUsageData {
        func resetDate(for window: Window) -> Date? {
            if let resetAt = window.reset_at {
                return Date(timeIntervalSince1970: TimeInterval(resetAt))
            }
            if let resetAfterSeconds = window.reset_after_seconds {
                return now.addingTimeInterval(TimeInterval(resetAfterSeconds))
            }
            return nil
        }

        let primaryWindow: Window?
        let secondaryWindow: Window?

        if let pw = rate_limit?.primary_window, let sw = rate_limit?.secondary_window {
            primaryWindow = pw
            secondaryWindow = sw
        } else if let pw = rate_limit?.primary_window {
            if let seconds = pw.limit_window_seconds, seconds > 86400 {
                primaryWindow = nil
                secondaryWindow = pw
            } else {
                primaryWindow = pw
                secondaryWindow = nil
            }
        } else if let sw = rate_limit?.secondary_window {
            primaryWindow = nil
            secondaryWindow = sw
        } else {
            primaryWindow = nil
            secondaryWindow = nil
        }

        let primary = primaryWindow.map {
            CodexCoreUsageData.LimitData(percentage: $0.used_percent, resetsAt: resetDate(for: $0))
        }

        let secondary: CodexCoreUsageData.LimitData? = {
            guard let window = secondaryWindow else { return nil }
            if window.used_percent == 0 && window.reset_at == nil && window.reset_after_seconds == nil {
                return nil
            }
            return CodexCoreUsageData.LimitData(percentage: window.used_percent, resetsAt: resetDate(for: window))
        }()

        let extraUsage = credits.map {
            CodexCoreUsageData.ExtraUsageData(
                hasCredits: $0.has_credits ?? false,
                unlimited: $0.unlimited ?? false,
                overageLimitReached: $0.overage_limit_reached ?? false,
                spendControlReached: spend_control?.reached ?? false,
                balance: Self.parseBalance($0.balance),
                approxLocalMessages: $0.approx_local_messages,
                approxCloudMessages: $0.approx_cloud_messages
            )
        }

        return CodexCoreUsageData(primary: primary, secondary: secondary, extraUsage: extraUsage)
    }

    private static func parseBalance(_ value: String?) -> Decimal? {
        guard let value, !value.isEmpty else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}
