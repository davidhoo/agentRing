//
//  CodexColumnView.swift
//  Agent Ring
//

import SwiftUI

/// Codex 用量列视图（双 Provider 模式右列）
struct CodexColumnView: View {
    let codexUsageData: CodexUsageData
    let showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?

    private var activeCodexTypes: [LimitType] {
        UserSettings.shared.getActiveDisplayTypes(codexUsageData: codexUsageData)
    }

    private var primaryRingType: LimitType? {
        if activeCodexTypes.contains(.codexPrimary) {
            return .codexPrimary
        }
        if activeCodexTypes.contains(.codexSecondary) {
            return .codexSecondary
        }
        return nil
    }

    private var primaryRingData: CodexUsageData.LimitData? {
        let placeholder = CodexUsageData.LimitData(percentage: 0, resetsAt: nil)
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover

        switch primaryRingType {
        case .codexPrimary:
            return codexUsageData.primary ?? (showPlaceholder ? placeholder : nil)
        case .codexSecondary:
            return codexUsageData.secondary ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var secondaryData: CodexUsageData.LimitData? { codexUsageData.secondary }

    private var showSecondaryRing: Bool {
        primaryRingType == .codexPrimary && activeCodexTypes.contains(.codexSecondary) && secondaryData != nil
    }

    private var isCodexRefreshing: Bool {
        refreshState.isRefreshingProvider(.codex)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                if let ringData = primaryRingData {
                    let outerColor = primaryRingType == .codexSecondary
                        ? UsageColorScheme.codexSecondaryColorSwiftUI(ringData.percentage)
                        : UsageColorScheme.codexPrimaryColorSwiftUI(ringData.percentage)
                    ActivityRingView(
                        outerPercentage: ringData.percentage,
                        innerPercentage: showSecondaryRing ? secondaryData?.percentage : nil,
                        outerColor: outerColor,
                        innerColor: UsageColorScheme.codexPairedInnerColorSwiftUI(secondaryData?.percentage ?? 0),
                        isRefreshing: isCodexRefreshing,
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

            limitRows(for: activeCodexTypes) { type in
                UnifiedLimitRow(
                    type: type,
                    codexData: codexUsageData,
                    showRemainingMode: showRemainingMode
                )
            }
            .padding(.horizontal, 14)
        }
    }
}
