//
//  AntigravityColumnView.swift
//  agentsRing
//

import SwiftUI

struct AntigravityColumnView: View {
    let provider: ProviderType
    let antigravityUsageData: AntigravityUsageData
    let showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?

    private var activeTypes: [LimitType] {
        UserSettings.shared.getActiveAntigravityDisplayTypes(
            antigravityUsageData: antigravityUsageData,
            provider: provider
        )
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.antigravity)
    }

    private var outerPercentage: Double {
        if provider == .antigravity {
            return antigravityUsageData.geminiPrimary?.percentage ?? antigravityUsageData.primary?.percentage ?? 0
        } else {
            return antigravityUsageData.thirdPartyPrimary?.percentage ?? 0
        }
    }

    private var innerPercentage: Double? {
        if provider == .antigravity {
            return antigravityUsageData.geminiSecondary?.percentage ?? antigravityUsageData.secondary?.percentage
        } else {
            return antigravityUsageData.thirdPartySecondary?.percentage
        }
    }

    private var outerColor: Color {
        if provider == .antigravity {
            return UsageColorScheme.antigravityPrimaryColorSwiftUI(outerPercentage)
        } else {
            return UsageColorScheme.antigravityThirdPartyPrimaryColorSwiftUI(outerPercentage)
        }
    }

    private var innerColor: Color {
        if provider == .antigravity {
            return UsageColorScheme.antigravitySecondaryColorSwiftUI(innerPercentage ?? 0)
        } else {
            return UsageColorScheme.antigravityThirdPartySecondaryColorSwiftUI(innerPercentage ?? 0)
        }
    }

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                ActivityRingView(
                    outerPercentage: outerPercentage,
                    innerPercentage: innerPercentage,
                    outerColor: outerColor,
                    innerColor: innerColor,
                    isRefreshing: isRefreshing,
                    rotationAngle: rotationAngle,
                    showRemainingMode: showRemainingMode,
                    remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                    animationType: animationType
                )
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
            .padding(.horizontal, 14)
        }
    }
}
