//
//  AntigravityQuadRingView.swift
//  Agent Ring
//

import SwiftUI

/// Antigravity 四配额同心圆：Gemini 5h/7d + Claude/GPT 5h/7d 画在同一组圆环里。
struct AntigravityQuadRingView: View {
    struct Layer: Identifiable {
        let id: LimitType
        let percentage: Double
        let color: Color
        let dashed: Bool
    }

    let layers: [Layer]
    let centerUsedPercentage: Double
    let isRefreshing: Bool
    let rotationAngle: Double
    let showRemainingMode: Bool
    let remainingModeAnimationTrigger: Int
    var animationType: UsageDetailView.LoadingAnimationType = .rainbow

    private let diameter: CGFloat = 110
    private let lineWidth: CGFloat = 5
    private let ringGap: CGFloat = 2.5

    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                ringLayer(
                    layer: layer,
                    diameter: ringDiameter(at: index),
                    reverseLoading: index.isMultiple(of: 2)
                )
            }

            if !isRefreshing, let outerColor = layers.first?.color {
                DetailUsageRingSweep(
                    trigger: remainingModeAnimationTrigger,
                    diameter: diameter + 8,
                    lineWidth: 3,
                    color: outerColor
                )
            }

            DetailUsageRingCenterText(
                usedPercentage: centerUsedPercentage,
                showRemainingMode: showRemainingMode,
                fontSize: 24
            )
        }
        .frame(width: diameter, height: diameter)
    }

    private func ringDiameter(at index: Int) -> CGFloat {
        let step = (lineWidth * 2) + (ringGap * 2)
        return diameter - (CGFloat(index) * step)
    }

    @ViewBuilder
    private func ringLayer(layer: Layer, diameter: CGFloat, reverseLoading: Bool) -> some View {
        let range = UsageRingDisplay.displayedTrimRange(
            usedPercentage: layer.percentage,
            showRemainingMode: showRemainingMode
        )

        if isRefreshing {
            loadingStroke(
                diameter: diameter,
                color: layer.color,
                reverse: reverseLoading
            )
        } else if abs(range.to - range.from) >= 0.002 {
            Circle()
                .trim(from: range.from, to: range.to)
                .stroke(
                    layer.color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
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
