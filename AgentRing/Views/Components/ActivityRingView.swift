//
//  ActivityRingView.swift
//  agentsRing
//

import SwiftUI

/// Apple Watch 风格双环：默认按「剩余」填充；未用区间不画底轨。
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
    var lineWidth: CGFloat = 11

    private var innerDiameter: CGFloat {
        diameter - lineWidth * 2 - 6
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
                    diameter: diameter + 8,
                    lineWidth: 3,
                    color: outerColor
                )
            }

            DetailUsageRingCenterText(
                usedPercentage: outerPercentage,
                showRemainingMode: showRemainingMode,
                fontSize: 22
            )
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func ring(diameter: CGFloat, percentage: Double, color: Color, isInner: Bool) -> some View {
        let range = UsageRingDisplay.displayedTrimRange(
            usedPercentage: percentage,
            showRemainingMode: showRemainingMode
        )

        if isRefreshing {
            loadingStroke(diameter: diameter, color: color, reverse: isInner)
        } else if abs(range.to - range.from) >= 0.002 {
            // 0% 不描边，避免 round lineCap 在 12 点方向留下假圆点；未用区间也不画灰轨。
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
                        gradient: Gradient(colors: [color, color.opacity(0.4), .white, color]),
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
