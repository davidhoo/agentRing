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

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                let primaryRingData: AntigravityUsageData.LimitData? = {
                    if activeTypes.contains(.antigravityPrimary) {
                        return antigravityUsageData.geminiPrimary ?? antigravityUsageData.primary
                    }
                    if activeTypes.contains(.antigravitySecondary) {
                        return antigravityUsageData.geminiSecondary ?? antigravityUsageData.secondary
                    }
                    return antigravityUsageData.geminiPrimary ?? antigravityUsageData.primary ?? antigravityUsageData.geminiSecondary ?? antigravityUsageData.secondary
                }()

                if let primary = primaryRingData {
                    let isSecondaryOnly = !activeTypes.contains(.antigravityPrimary) && activeTypes.contains(.antigravitySecondary)
                    let outerColor = isSecondaryOnly
                        ? UsageColorScheme.antigravitySecondaryColorSwiftUI(primary.percentage)
                        : UsageColorScheme.antigravityPrimaryColorSwiftUI(primary.percentage)
                    let secondaryData = antigravityUsageData.geminiSecondary ?? antigravityUsageData.secondary
                    let innerPercentage = !isSecondaryOnly && activeTypes.contains(.antigravitySecondary)
                        ? secondaryData?.percentage
                        : nil

                    ActivityRingView(
                        outerPercentage: primary.percentage,
                        innerPercentage: innerPercentage,
                        outerColor: outerColor,
                        innerColor: UsageColorScheme.antigravitySecondaryColorSwiftUI(secondaryData?.percentage ?? 0),
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
            .padding(.horizontal, 14)
        }
    }
}
