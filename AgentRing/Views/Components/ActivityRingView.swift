//
//  ActivityRingView.swift
//  Agent Ring
//

import SwiftUI

/// Apple Watch 风格双环：按设置展示剩余或已用进度；未填充区间以半透明底轨补全成整圆。
/// 中心不放百分比——明细行已展示数值，圆环只做纯视觉仪表。
struct ActivityRingView: View {
    let outerPercentage: Double
    let innerPercentage: Double?
    let outerColor: Color
    let innerColor: Color
    let isRefreshing: Bool
    let rotationAngle: Double
    let showRemainingMode: Bool
    let remainingModeAnimationTrigger: Int
    var animationType: UsageDetailView.LoadingAnimationType = .rainbow
    var diameter: CGFloat = 110
    /// 环线宽度：去掉中心文字后稍加粗，环在毛玻璃底上更扎实
    var lineWidth: CGFloat = 13
    /// 内外环之间的间隙：同心几何（规范第 10 节），双环留出呼吸感
    private let ringSpacing: CGFloat = 5

    private var innerDiameter: CGFloat {
        diameter - (lineWidth + ringSpacing) * 2
    }

    var body: some View {
        ZStack {
            ring(
                diameter: diameter,
                percentage: outerPercentage,
                color: outerColor,
                isInner: false
            )

            if let innerPercentage {
                ring(
                    diameter: innerDiameter,
                    percentage: innerPercentage,
                    color: innerColor,
                    isInner: true
                )
            }

            if !isRefreshing {
                DetailUsageRingSweep(
                    trigger: remainingModeAnimationTrigger,
                    diameter: diameter + lineWidth,
                    lineWidth: 3,
                    color: outerColor
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private let usedPortionOpacity: Double = 0.08

    @ViewBuilder
    private func ring(diameter: CGFloat, percentage: Double, color: Color, isInner: Bool) -> some View {
        let range = UsageRingDisplay.displayedTrimRange(
            usedPercentage: percentage,
            showRemainingMode: showRemainingMode
        )
        let trackRange = UsageRingDisplay.trackTrimRange(
            usedPercentage: percentage,
            showRemainingMode: showRemainingMode
        )

        if isRefreshing {
            loadingStroke(diameter: diameter, color: color, reverse: isInner)
        } else {
            if let trackRange, abs(trackRange.to - trackRange.from) >= 0.002 {
                ringStroke(
                    diameter: diameter,
                    range: trackRange,
                    color: color.opacity(usedPortionOpacity)
                )
            }

            if abs(range.to - range.from) >= 0.002 {
                ringStroke(diameter: diameter, range: range, color: color)
            } else {
                // 弧长为 0 时不要整个消失：在 12 点位置留一个环色小点，
                // 用 round 线帽的极小弧段画出，天然继承环色与动画
                ringStroke(
                    diameter: diameter,
                    range: UsageRingTrimRange(from: 0, to: 0.002),
                    color: color
                )
            }
        }
    }

    private func ringStroke(diameter: CGFloat, range: UsageRingTrimRange, color: Color) -> some View {
        Circle()
            .trim(from: range.from, to: range.to)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(-90))
            .animation(
                .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05),
                value: range
            )
    }

    @ViewBuilder
    private func loadingStroke(diameter: CGFloat, color: Color, reverse: Bool) -> some View {
        let angle = reverse ? -rotationAngle : rotationAngle
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        // 高光用环色自身提亮而非纯白，暗色模式毛玻璃底上不过曝
                        gradient: Gradient(colors: [color, color.opacity(0.4), color.opacity(0.9), color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        case .dashed:
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [8, 6]))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        case .pulse:
            Circle()
                .trim(from: 0, to: 0.55)
                .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        }
    }
}
