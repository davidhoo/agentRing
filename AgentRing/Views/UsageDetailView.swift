//
//  UsageDetailView.swift
//  CodexRings
//

import SwiftUI

struct UsageDetailView: View {
    @Binding var codexUsageData: CodexUsageData?
    @Binding var cursorUsageData: CursorUsageData?
    @Binding var antigravityUsageData: AntigravityUsageData?
    @Binding var errorMessage: String?
    @Binding var codexNeedsRelogin: Bool
    @Binding var cursorNeedsRelogin: Bool
    @Binding var antigravityNeedsRelogin: Bool
    @ObservedObject var refreshState: RefreshState
    var onMenuAction: ((MenuAction) -> Void)? = nil
    @StateObject private var localization = LocalizationManager.shared
    @Binding var hasAvailableUpdate: Bool
    @Binding var shouldShowUpdateBadge: Bool

    enum LoadingAnimationType: Int, CaseIterable {
        case rainbow = 0
        case dashed = 1
        case pulse = 2

        var name: String {
            switch self {
            case .rainbow: return L.LoadingAnimation.rainbow
            case .dashed: return L.LoadingAnimation.dashed
            case .pulse: return L.LoadingAnimation.pulse
            }
        }
    }

    enum MenuAction {
        case generalSettings
        case authSettings
        case checkForUpdates
        case about
        case codexStatus
        case quit
        case refresh
        case codexRelogin
        case cursorRelogin
        case antigravityRelogin
        case cursorStatus
    }

    @State var codexAnimationType: LoadingAnimationType = .rainbow
    @State var cursorAnimationType: LoadingAnimationType = .rainbow
    @State var antigravityAnimationType: LoadingAnimationType = .rainbow
    @State var rotationAngle: Double = 0
    @State var animationTimer: Timer?
    @State private var showAnimationTypeHint = false
    @State private var animationTypeHintName = ""
    @State private var animationTypeHintDismissWorkItem: DispatchWorkItem?
    @State private var showUpdateNotification = false
    @AppStorage("showRemainingMode") private var savedRemainingMode = true
    @State private var showRemainingMode = true
    @State private var remainingModeAnimationTrigger = 0

    private var activeProviders: [ProviderType] {
        var providers: [ProviderType] = []
        if UserSettings.shared.hasValidCodexCredentials || codexUsageData != nil {
            providers.append(.codex)
        }
        if UserSettings.shared.hasValidCursorCredentials || cursorUsageData != nil {
            providers.append(.cursor)
        }
        if UserSettings.shared.hasValidAntigravityCredentials || antigravityUsageData != nil {
            providers.append(.antigravity)
        }
        return providers
    }

    private var showsMultipleProviders: Bool {
        activeProviders.count > 1
    }

    private var popoverWidth: CGFloat {
        switch activeProviders.count {
        case 3: return 760
        case 2: return 520
        default: return 290
        }
    }

    private var activeDisplayTypes: [LimitType] {
        var types: [LimitType] = []
        if let codexUsageData {
            types.append(contentsOf: UserSettings.shared.getActiveCodexDisplayTypes(codexUsageData: codexUsageData))
        }
        if let cursorUsageData {
            types.append(contentsOf: UserSettings.shared.getActiveCursorDisplayTypes(cursorUsageData: cursorUsageData))
        }
        if let antigravityUsageData {
            types.append(contentsOf: UserSettings.shared.getActiveAntigravityDisplayTypes(antigravityUsageData: antigravityUsageData))
        }
        return types
    }

    private var contentSpacing: CGFloat {
        activeDisplayTypes.count >= 2 ? 10 : 16
    }

    private var contentHeight: CGFloat {
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5
        // 多列并排时高度应按「最高那一列」算，不能把各 provider 行数加总（会撑出大片空白）
        let maxRowsPerProvider = [
            UserSettings.shared.getActiveCodexDisplayTypes(codexUsageData: codexUsageData).count,
            UserSettings.shared.getActiveCursorDisplayTypes(cursorUsageData: cursorUsageData).count,
            UserSettings.shared.getActiveAntigravityDisplayTypes(antigravityUsageData: antigravityUsageData).count
        ].max() ?? 0
        let hasAnyData = codexUsageData != nil || cursorUsageData != nil || antigravityUsageData != nil
        let rowCount = max(maxRowsPerProvider, hasAnyData || !activeProviders.isEmpty ? 1 : 0)
        let textHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing
        return baseHeight + textHeight
    }

    private var updateNotificationView: some View {
        Group {
            if showUpdateNotification {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    rainbowText(L.Update.Notification.available)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.top, -8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var headerView: some View {
        HStack {
            if showsMultipleProviders {
                Text(L.App.name)
                    .font(.headline)
            } else if let provider = activeProviders.first {
                switch provider {
                case .antigravity:
                    if let icon = ImageHelper.createAntigravityIcon(size: 18, isTemplate: false) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    Text(L.Usage.antigravityTitle)
                        .font(.headline)
                case .cursor:
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L.Usage.cursorTitle)
                        .font(.headline)
                case .codex:
                    if let icon = ImageHelper.createCodexIcon(size: 18) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    Text(L.Usage.codexTitle)
                        .font(.headline)
                }
            } else {
                Text(L.App.name)
                    .font(.headline)
            }

            Spacer()
            refreshAndMenuButtons
        }
        .frame(height: 20, alignment: .center)
        .padding(.horizontal)
        .padding(.top)
    }

    private var refreshAndMenuButtons: some View {
        HStack(spacing: 10) {
            Button(action: { onMenuAction?(.refresh) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(refreshState.canRefresh ? 1 : 0.3)
                    .rotationEffect(.degrees(refreshState.isRefreshing ? rotationAngle : 0))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!refreshState.canRefresh || refreshState.isRefreshing)
            .focusable(false)

            ZStack(alignment: .topTrailing) {
                Button(action: { onMenuAction?(.generalSettings) }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(L.Menu.generalSettings)

                if shouldShowUpdateBadge {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .offset(x: 5, y: -5)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if showsMultipleProviders {
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(activeProviders.enumerated()), id: \.element) { index, provider in
                    if index > 0 {
                        ProviderDivider(height: 180)
                    }
                    providerColumn(for: provider)
                }
            }
            .padding(.horizontal, 8)
        } else if let singleProvider = activeProviders.first {
            providerColumn(for: singleProvider)
        } else if let errorMessage {
            errorState(
                message: errorMessage,
                needsRelogin: codexNeedsRelogin || cursorNeedsRelogin || antigravityNeedsRelogin,
                reloginAction: codexNeedsRelogin ? .codexRelogin : (cursorNeedsRelogin ? .cursorRelogin : .antigravityRelogin)
            )
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(L.Usage.loading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
        }
    }

    @ViewBuilder
    private func providerColumn(for provider: ProviderType) -> some View {
        switch provider {
        case .codex:
            if let codexUsageData {
                CodexColumnView(
                    codexUsageData: codexUsageData,
                    showRemainingMode: $showRemainingMode,
                    refreshState: refreshState,
                    animationType: $codexAnimationType,
                    rotationAngle: $rotationAngle,
                    remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                    onRefresh: { onMenuAction?(.refresh) },
                    onAnimationHint: { showAnimationHint($0) },
                    onToggleRemainingMode: toggleRemainingMode
                )
                .frame(maxWidth: .infinity)
            } else {
                errorState(
                    message: codexNeedsRelogin ? L.Error.sessionExpired : (errorMessage ?? L.Usage.loading),
                    needsRelogin: codexNeedsRelogin,
                    reloginAction: .codexRelogin
                )
                .frame(maxWidth: .infinity)
            }
        case .cursor:
            if let cursorUsageData {
                CursorColumnView(
                    cursorUsageData: cursorUsageData,
                    showRemainingMode: $showRemainingMode,
                    refreshState: refreshState,
                    animationType: $cursorAnimationType,
                    rotationAngle: $rotationAngle,
                    remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                    onRefresh: { onMenuAction?(.refresh) },
                    onAnimationHint: { showAnimationHint($0) },
                    onToggleRemainingMode: toggleRemainingMode
                )
                .frame(maxWidth: .infinity)
            } else {
                errorState(
                    message: cursorNeedsRelogin ? L.Error.sessionExpired : (errorMessage ?? L.Usage.loading),
                    needsRelogin: cursorNeedsRelogin,
                    reloginAction: .cursorRelogin
                )
                .frame(maxWidth: .infinity)
            }
        case .antigravity:
            if let antigravityUsageData {
                AntigravityColumnView(
                    antigravityUsageData: antigravityUsageData,
                    showRemainingMode: $showRemainingMode,
                    refreshState: refreshState,
                    animationType: $antigravityAnimationType,
                    rotationAngle: $rotationAngle,
                    remainingModeAnimationTrigger: remainingModeAnimationTrigger,
                    onRefresh: { onMenuAction?(.refresh) },
                    onAnimationHint: { showAnimationHint($0) },
                    onToggleRemainingMode: toggleRemainingMode
                )
                .frame(maxWidth: .infinity)
            } else {
                errorState(
                    message: antigravityNeedsRelogin ? L.Error.sessionExpired : (errorMessage ?? L.Usage.loading),
                    needsRelogin: antigravityNeedsRelogin,
                    reloginAction: .antigravityRelogin
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func errorState(message: String, needsRelogin: Bool, reloginAction: MenuAction = .codexRelogin) -> some View {
        VStack(spacing: 12) {
            Image(systemName: needsRelogin ? "lock.open.trianglebadge.exclamationmark.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if needsRelogin {
                Button(action: { onMenuAction?(reloginAction) }) {
                    Label(reloginButtonTitle(for: reloginAction), systemImage: "arrow.counterclockwise.circle.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { onMenuAction?(.authSettings) }) {
                    Label(L.Usage.goToSettings, systemImage: "key.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private func reloginButtonTitle(for action: MenuAction) -> String {
        switch action {
        case .cursorRelogin: return L.Usage.cursorRelogin
        case .antigravityRelogin: return L.Usage.antigravityRelogin
        default: return L.Usage.codexRelogin
        }
    }

    private var animationHintView: some View {
        Group {
            if showAnimationTypeHint {
                AnimationTypeHintView(animationTypeName: animationTypeHintName)
                    .padding(.top, -8)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }

    var body: some View {
        VStack(spacing: contentSpacing) {
            VStack(spacing: contentSpacing) {
                headerView
                mainContent
            }
            .offset(y: showAnimationTypeHint ? -18 : 0)

            animationHintView
            updateNotificationView
            Spacer()
        }
        .frame(width: popoverWidth, height: contentHeight)
        .animation(.easeInOut(duration: 0.25), value: showAnimationTypeHint)
        .id(localization.updateTrigger)
        .onAppear {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // 产品默认改为「剩余」；一次性迁移旧安装
                if !UserDefaults.standard.bool(forKey: "ringShowsRemaining.defaultMigrated") {
                    savedRemainingMode = true
                    showRemainingMode = true
                    UserDefaults.standard.set(true, forKey: "ringShowsRemaining.defaultMigrated")
                } else {
                    showRemainingMode = savedRemainingMode
                }
            }
            if refreshState.isRefreshing {
                startRotationAnimation()
            }
            if refreshState.notificationMessage != nil {
                withAnimation { showUpdateNotification = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showUpdateNotification = false }
                }
            }
        }
        .onChange(of: refreshState.isRefreshing) { newValue in
            newValue ? startRotationAnimation() : stopRotationAnimation()
        }
        .onChange(of: refreshState.notificationMessage) { message in
            withAnimation {
                showUpdateNotification = message != nil
            }
            if message != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showUpdateNotification = false }
                }
            }
        }
        .onDisappear {
            stopRotationAnimation()
            animationTypeHintDismissWorkItem?.cancel()
        }
        #if DEBUG
        .background(UserSettings.shared.debugKeepDetailWindowOpen ? Color.white : Color.clear)
        #endif
    }

    private func showAnimationHint(_ animationTypeName: String) {
        animationTypeHintDismissWorkItem?.cancel()
        animationTypeHintName = animationTypeName
        withAnimation(.easeInOut(duration: 0.25)) {
            showAnimationTypeHint = true
        }

        let dismissWorkItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                showAnimationTypeHint = false
            }
        }
        animationTypeHintDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: dismissWorkItem)
    }

    private func toggleRemainingMode() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05)) {
            showRemainingMode.toggle()
            remainingModeAnimationTrigger += 1
        }
        savedRemainingMode = showRemainingMode
    }
}

private extension UsageDetailView {
    func startRotationAnimation() {
        stopRotationAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            rotationAngle += 3
            if rotationAngle >= 360 {
                rotationAngle = 0
            }
        }
    }

    func stopRotationAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    func rainbowText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

struct UsageDetailView_Previews: PreviewProvider {
    @State static var sampleCodexData: CodexUsageData? = CodexUsageData(
        primary: .init(percentage: 42, resetsAt: Date().addingTimeInterval(3600 * 2)),
        secondary: .init(percentage: 58, resetsAt: Date().addingTimeInterval(3600 * 24 * 3)),
        extraUsage: CodexExtraUsageData(
            hasCredits: true,
            unlimited: false,
            overageLimitReached: false,
            spendControlReached: false,
            balance: Decimal(12),
            approxLocalMessages: nil,
            approxCloudMessages: nil
        )
    )
    @State static var error: String?
    @State static var needsRelogin = false
    @State static var hasUpdate = false
    @State static var showBadge = false

    static var previews: some View {
        UsageDetailView(
            codexUsageData: $sampleCodexData,
            cursorUsageData: .constant(nil),
            antigravityUsageData: .constant(nil),
            errorMessage: $error,
            codexNeedsRelogin: $needsRelogin,
            cursorNeedsRelogin: .constant(false),
            antigravityNeedsRelogin: .constant(false),
            refreshState: RefreshState(),
            hasAvailableUpdate: $hasUpdate,
            shouldShowUpdateBadge: $showBadge
        )
    }
}
