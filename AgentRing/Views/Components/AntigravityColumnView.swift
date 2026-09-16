//
//  AntigravityColumnView.swift
//  agentsRing
//

import SwiftUI

struct AntigravityColumnView: View {
    let antigravityUsageData: AntigravityUsageData
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private var activeTypes: [LimitType] {
        UserSettings.shared.getActiveAntigravityDisplayTypes(antigravityUsageData: antigravityUsageData)
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.antigravity)
    }

    private var ringLayers: [AntigravityQuadRingView.Layer] {
        activeTypes.compactMap { type in
            guard let percentage = percentage(for: type) else { return nil }
            return AntigravityQuadRingView.Layer(
                id: type,
                percentage: percentage,
                color: color(for: type, percentage: percentage),
                dashed: type.usesDashedStyle
            )
        }
    }

    private var centerUsedPercentage: Double {
        if let primary = antigravityUsageData.geminiPrimary?.percentage ?? antigravityUsageData.primary?.percentage {
            return primary
        }
        return ringLayers.first?.percentage ?? 0
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if !ringLayers.isEmpty {
                    AntigravityQuadRingView(
                        layers: ringLayers,
                        centerUsedPercentage: centerUsedPercentage,
                        isRefreshing: isRefreshing,
                        rotationAngle: rotationAngle,
                        showRemainingMode: showRemainingMode,
                        remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                        animationType: animationType
                    )
                }
            }
            .frame(height: 114)
            .contentShape(Circle())
            .onTapGesture {
                if refreshState.canRefresh && !refreshState.isRefreshing {
                    onRefresh?()
                }
            }
            .onLongPressGesture(minimumDuration: 3.0) {
                let allTypes = UsageDetailView.LoadingAnimationType.allCases
                let currentIndex = allTypes.firstIndex(of: animationType) ?? 0
                animationType = allTypes[(currentIndex + 1) % allTypes.count]
                onAnimationHint?(animationType.name)
            }

            VStack(spacing: 5) {
                ForEach(activeTypes, id: \.self) { type in
                    UnifiedLimitRow(
                        type: type,
                        antigravityData: antigravityUsageData,
                        showRemainingMode: showRemainingMode
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleRemainingMode?()
            }
            .padding(.horizontal, 8)
        }
    }

    private func percentage(for type: LimitType) -> Double? {
        switch type {
        case .antigravityPrimary:
            return antigravityUsageData.geminiPrimary?.percentage ?? antigravityUsageData.primary?.percentage
        case .antigravitySecondary:
            return antigravityUsageData.geminiSecondary?.percentage ?? antigravityUsageData.secondary?.percentage
        case .antigravityThirdPartyPrimary:
            return antigravityUsageData.thirdPartyPrimary?.percentage
        case .antigravityThirdPartySecondary:
            return antigravityUsageData.thirdPartySecondary?.percentage
        default:
            return nil
        }
    }

    private func color(for type: LimitType, percentage: Double) -> Color {
        switch type {
        case .antigravityPrimary:
            return UsageColorScheme.antigravityPrimaryColorSwiftUI(percentage)
        case .antigravitySecondary:
            return UsageColorScheme.antigravitySecondaryColorSwiftUI(percentage)
        case .antigravityThirdPartyPrimary:
            return UsageColorScheme.antigravityThirdPartyPrimaryColorSwiftUI(percentage)
        case .antigravityThirdPartySecondary:
            return UsageColorScheme.antigravityThirdPartySecondaryColorSwiftUI(percentage)
        default:
            return .secondary
        }
    }
}
