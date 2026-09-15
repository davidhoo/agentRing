//
//  UsageRowComponents.swift
//  CodexRings
//

import SwiftUI

// MARK: - Detail Usage Ring Helpers

struct UsageRingTrimRange: Equatable {
    let from: CGFloat
    let to: CGFloat
}

enum UsageRingDisplay {
    static func clampedPercentage(_ percentage: Double) -> Double {
        min(100, max(0, percentage))
    }

    static func remainingPercentage(usedPercentage: Double) -> Double {
        100 - clampedPercentage(usedPercentage)
    }

    static func displayedPercentage(usedPercentage: Double, showRemainingMode: Bool) -> Double {
        let used = clampedPercentage(usedPercentage)
        return showRemainingMode ? remainingPercentage(usedPercentage: used) : used
    }

    static func usedFraction(_ usedPercentage: Double) -> CGFloat {
        CGFloat(clampedPercentage(usedPercentage) / 100.0)
    }

    static func displayedTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange {
        let used = usedFraction(usedPercentage)

        if showRemainingMode {
            // 剩余模式：从 12 点起填充「还剩多少」，满环=额度充足，空环=用尽
            return UsageRingTrimRange(from: 0, to: 1 - used)
        }

        return UsageRingTrimRange(from: 0, to: used)
    }
}

/// 大圆环中心百分比与语义标签。
struct DetailUsageRingCenterText: View {
    let usedPercentage: Double
    let showRemainingMode: Bool

    private var displayPercentage: Double {
        UsageRingDisplay.displayedPercentage(
            usedPercentage: usedPercentage,
            showRemainingMode: showRemainingMode
        )
    }

    private var modeLabel: String {
        showRemainingMode ? L.Usage.available : L.Usage.used
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(displayPercentage))%")
                .font(.system(size: 28, weight: .bold))
            Text(modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .id(showRemainingMode ? "remaining" : "used")
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }
}

/// 剩余/已用模式切换时的一次性外侧扫光。
struct DetailUsageRingSweep: View {
    let trigger: Int
    let diameter: CGFloat
    let lineWidth: CGFloat
    let color: Color

    @State private var rotation: Double = -90
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.18)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.0),
                        color.opacity(0.35),
                        Color.white.opacity(0.95),
                        color.opacity(0.85),
                        color.opacity(0.0)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .scaleEffect(opacity > 0 ? 1.03 : 0.98)
            .allowsHitTesting(false)
            .onChange(of: trigger) { newValue in
                guard newValue > 0 else { return }
                runSweep()
            }
    }

    private func runSweep() {
        rotation = -90
        opacity = 1

        withAnimation(.easeOut(duration: 0.45)) {
            rotation = 270
            opacity = 0
        }
    }
}

// MARK: - Animation Type Hint View

/// 动画类型切换提示（长按圆环后显示）
struct AnimationTypeHintView: View {
    let animationTypeName: String

    private let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: rainbowColors, startPoint: .leading, endPoint: .trailing)
                )
            Text(L.LoadingAnimation.current(animationTypeName))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(colors: rainbowColors, startPoint: .leading, endPoint: .trailing)
                )
        }
        .padding(.horizontal, 12)
        .fixedSize(horizontal: true, vertical: true)
    }
}

// MARK: - Provider Divider

/// 柔和竖线，视觉与设置页标签分隔线一致
struct ProviderDivider: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.secondary.opacity(0.0),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: height)
    }
}

// MARK: - Unified Limit Row Component

/// 统一的 Codex 限制行组件
struct UnifiedLimitRow: View {
    let type: LimitType
    var codexData: CodexUsageData? = nil
    var cursorData: CursorUsageData? = nil
    var antigravityData: AntigravityUsageData? = nil
    let showRemainingMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(percentageLabel)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(iconColor)
                .frame(width: 36, alignment: .trailing)

            Text(limitName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(0)

            Spacer(minLength: 4)

            // 日期/额度优先完整显示，避免被左侧名称挤成省略号
            Text(displayValue)
                .font(.system(size: 12).monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .id(showRemainingMode ? "remaining" : "reset")
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var limitName: String {
        type.detailDisplayName
    }

    private var percentageLabel: String {
        guard let percentageValue else { return "—" }
        let displayed = UsageRingDisplay.displayedPercentage(
            usedPercentage: percentageValue,
            showRemainingMode: showRemainingMode
        )
        return "\(Int(displayed.rounded()))%"
    }

    private var iconColor: Color {
        switch type {
        case .codexPrimary:
            return UsageColorScheme.codexPrimaryColorSwiftUI(percentageValue ?? 0)
        case .codexSecondary:
            return UsageColorScheme.codexSecondaryColorSwiftUI(percentageValue ?? 0)
        case .codexExtraUsage:
            return UsageColorScheme.codexExtraUsageColorSwiftUI(percentageValue ?? 0)
        case .cursorIncluded:
            return UsageColorScheme.cursorIncludedColorSwiftUI(percentageValue ?? 0)
        case .cursorOnDemand:
            return UsageColorScheme.cursorOnDemandColorSwiftUI(percentageValue ?? 0)
        case .antigravityPrimary:
            return UsageColorScheme.antigravityPrimaryColorSwiftUI(percentageValue ?? 0)
        case .antigravitySecondary:
            return UsageColorScheme.antigravitySecondaryColorSwiftUI(percentageValue ?? 0)
        }
    }

    private var percentageValue: Double? {
        switch type {
        case .codexPrimary: return codexData?.primary?.percentage
        case .codexSecondary: return codexData?.secondary?.percentage
        case .codexExtraUsage: return codexData?.extraUsage?.percentage
        case .cursorIncluded: return cursorData?.included?.percentage
        case .cursorOnDemand: return cursorData?.onDemand?.percentage
        case .antigravityPrimary: return antigravityData?.primary?.percentage
        case .antigravitySecondary: return antigravityData?.secondary?.percentage
        }
    }

    private var displayValue: String {
        switch type {
        case .codexPrimary:
            guard let limitData = codexData?.primary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemaining : detailCompactResetTime(limitData)

        case .codexSecondary:
            guard let limitData = codexData?.secondary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemainingWithMinutes : limitData.formattedCompactResetDateWithMinutes

        case .codexExtraUsage:
            guard let extra = codexData?.extraUsage else { return "-" }
            return showRemainingMode ? extra.formattedDetailRemainingAmount : extra.formattedDetailCompactAmount

        case .cursorIncluded:
            guard let included = cursorData?.included else { return "-" }
            let limitData = UsageLimitData(percentage: included.percentage, resetsAt: included.resetsAt)
            return showRemainingMode ? limitData.formattedCompactRemainingWithMinutes : limitData.formattedCompactResetDateWithMinutes

        case .cursorOnDemand:
            guard let onDemand = cursorData?.onDemand else { return "-" }
            if showRemainingMode {
                let remaining = max(0, onDemand.limitDollars - onDemand.usedDollars)
                return L.ExtraUsage.remainingAmount(remaining)
            }
            return L.ExtraUsage.usageAmount(onDemand.usedDollars, onDemand.limitDollars)

        case .antigravityPrimary:
            guard let limitData = antigravityData?.primary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemaining : detailCompactResetTime(limitData)

        case .antigravitySecondary:
            guard let limitData = antigravityData?.secondary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemainingWithMinutes : limitData.formattedCompactResetDateWithMinutes
        }
    }

    private func detailCompactResetTime(_ limitData: UsageLimitData) -> String {
        guard let resetsAt = limitData.resetsAt else {
            return "-"
        }

        var calendar = Calendar.current
        calendar.locale = UserSettings.shared.appLocale
        let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

        if calendar.isDateInToday(resetsAt) {
            return "\(L.DetailRow.today) \(timeString)"
        }
        if calendar.isDateInTomorrow(resetsAt) {
            return "\(L.UsageData.tomorrow) \(timeString)"
        }
        return TimeFormatHelper.formatDateTime(resetsAt, dateTemplate: "Md")
    }
}
