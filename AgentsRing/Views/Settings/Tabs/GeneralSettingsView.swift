//
//  GeneralSettingsView.swift
//  CodexRings
//

import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        SettingsPaneScroll {
            VStack(spacing: 16) {
                limitsCard
                refreshCard
                notificationCard
                launchCard
                resetCard
            }
        }
        .onAppear {
            settings.syncLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchAtLoginError)) { notification in
            handleLaunchError(notification)
        }
        .alert(L.LaunchAtLogin.errorTitle, isPresented: $showErrorAlert) {
            Button(L.Update.okButton, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var limitsCard: some View {
        SettingCard(
            icon: "rectangle.3.group",
            iconColor: .purple,
            title: L.DisplayOptions.title,
            hint: settings.displayMode == .smart ? L.DisplayOptions.smartDisplayDescription : L.DisplayOptions.customDisplayDescription
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.DisplayOptions.displayModeLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    radioGroup(selection: $settings.displayMode, values: DisplayMode.allCases) { $0.localizedName }
                }

                if settings.displayMode == .custom {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.DisplayOptions.selectLimitTypes)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(LimitType.allCases, id: \.self) { limitType in
                                LimitTypeCheckbox(
                                    limitType: limitType,
                                    isSelected: settings.customDisplayTypes.contains(limitType),
                                    isDisabled: shouldDisableCheckbox(for: limitType)
                                ) {
                                    toggleLimitType(limitType)
                                }
                            }
                        }
                        .padding(.leading, 20)

                        if hasOnlyOneCircularIcon {
                            hintRow(L.DisplayOptions.circularIconConstraint, color: .blue)
                        }

                        if !settings.canUseColoredTheme() {
                            hintRow(
                                L.DisplayOptions.coloredThemeUnavailable,
                                color: .orange,
                                textColor: .orange,
                                systemImage: "exclamationmark.circle.fill"
                            )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $settings.customDisplayMenuBarOnly) {
                                Text(L.DisplayOptions.menuBarOnlyToggle)
                                    .font(.subheadline)
                            }
                            .toggleStyle(.checkbox)

                            Text(L.DisplayOptions.menuBarOnlyDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }

    private var refreshCard: some View {
        SettingCard(
            icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90",
            iconColor: .green,
            title: L.SettingsGeneral.refreshSection,
            hint: settings.refreshMode == .smart ? L.SettingsGeneral.refreshHintSmart : L.SettingsGeneral.refreshHintFixed
        ) {
            VStack(alignment: .leading, spacing: 12) {
                radioGroup(selection: $settings.refreshMode, values: RefreshMode.allCases) { $0.localizedName }

                if settings.refreshMode == .fixed {
                    HStack {
                        Text(L.SettingsGeneral.refreshInterval)
                            .foregroundColor(.secondary)

                        Picker("", selection: $settings.refreshInterval) {
                            ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                                Text(interval.localizedName).tag(interval.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    private var notificationCard: some View {
        SettingCard(
            icon: "bell.badge",
            iconColor: .red,
            title: L.SettingsNotification.section,
            hint: L.SettingsNotification.hint
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $settings.notificationsEnabled) {
                    Text(L.SettingsNotification.enable)
                }
                .toggleStyle(.checkbox)
                .focusable(false)

                Text(L.SettingsNotification.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }
        }
    }

    private var launchCard: some View {
        SettingCard(
            icon: "power",
            iconColor: launchStatusColor,
            title: L.SettingsGeneral.launchSection,
            hint: statusText
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text(L.SettingsGeneral.launchAtLogin)
                }
                .toggleStyle(.checkbox)
                .focusable(false)

                HStack(spacing: 6) {
                    Circle()
                        .fill(launchStatusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }
        }
    }

    private var resetCard: some View {
        SettingCard(
            icon: "arrow.counterclockwise",
            iconColor: .orange,
            title: L.SettingsGeneral.resetSection,
            hint: L.SettingsGeneral.resetHint
        ) {
            Button(L.SettingsGeneral.resetButton) {
                settings.resetToDefaults()
            }
            .buttonStyle(.bordered)
        }
    }

    private var hasOnlyOneCircularIcon: Bool {
        let selectedCircular = settings.customDisplayTypes.filter(\.isCircular)
        return selectedCircular.count == 1
    }

    private var launchStatusColor: Color {
        switch settings.launchAtLoginStatus {
        case .enabled: return .green
        case .requiresApproval: return .orange
        case .notRegistered: return .secondary
        case .notFound: return .red
        @unknown default: return .secondary
        }
    }

    private var statusText: String {
        switch settings.launchAtLoginStatus {
        case .enabled: return L.LaunchAtLogin.statusEnabled
        case .requiresApproval: return L.LaunchAtLogin.statusRequiresApproval
        case .notRegistered: return L.LaunchAtLogin.statusDisabled
        case .notFound: return L.LaunchAtLogin.statusNotFound
        @unknown default: return L.LaunchAtLogin.statusDisabled
        }
    }

    private func shouldDisableCheckbox(for limitType: LimitType) -> Bool {
        #if DEBUG
        if settings.debugShowAllShapesIndividually {
            return false
        }
        #endif

        guard limitType.isCircular else { return false }
        let selectedCircular = settings.customDisplayTypes.filter(\.isCircular)
        return selectedCircular.count == 1 && selectedCircular.contains(limitType)
    }

    private func toggleLimitType(_ limitType: LimitType) {
        if settings.customDisplayTypes.contains(limitType) {
            guard !shouldDisableCheckbox(for: limitType) else { return }
            settings.customDisplayTypes.remove(limitType)
        } else {
            settings.customDisplayTypes.insert(limitType)
        }
    }

    private func handleLaunchError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let error = userInfo["error"] as? Error,
              let operation = userInfo["operation"] as? String else {
            return
        }

        let operationType = operation == "enable" ? L.LaunchAtLogin.errorEnable : L.LaunchAtLogin.errorDisable
        errorMessage = "\(operationType)\n\n\(error.localizedDescription)"
        showErrorAlert = true
    }

    private func radioGroup<T: Hashable, S: Sequence>(
        selection: Binding<T>,
        values: S,
        title: @escaping (T) -> String
    ) -> some View where S.Element == T {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(values), id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selection.wrappedValue == value ? "circle.inset.filled" : "circle")
                            .font(.body)
                            .foregroundColor(selection.wrappedValue == value ? .accentColor : .secondary)
                            .frame(width: 16)
                        Text(title(value))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
    }

    private func hintRow(_ text: String, color: Color, textColor: Color = .secondary, systemImage: String = "info.circle.fill") -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 20)
    }

}

struct LimitTypeCheckbox: View {
    let limitType: LimitType
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            if !isDisabled {
                onToggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isDisabled ? .secondary : (isSelected ? .blue : .primary))
                    .font(.body)

                HStack(spacing: 6) {
                    limitTypeIcon
                        .font(.caption)

                    Text(limitType.displayName)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(isDisabled ? L.DisplayOptions.circularIconConstraint : "")
        .fixedSize()
    }

    private var limitTypeIcon: some View {
        Canvas { context, canvasSize in
            let lineWidth: CGFloat = 1.8
            let path = IconShapePaths.pathForLimitType(limitType, in: CGRect(origin: .zero, size: canvasSize))
            context.stroke(path, with: .color(Color.gray.opacity(0.3)), lineWidth: lineWidth)
            context.stroke(path, with: .color(iconColor(for: limitType)), lineWidth: lineWidth)
        }
        .frame(width: 14, height: 14)
    }

    private func iconColor(for type: LimitType) -> Color {
        switch type {
        case .codexPrimary:
            return UsageColorScheme.codexPrimaryColorSwiftUI(0)
        case .codexSecondary:
            return UsageColorScheme.codexSecondaryColorSwiftUI(0)
        case .codexExtraUsage:
            return UsageColorScheme.codexExtraUsageColorSwiftUI(0)
        case .cursorIncluded:
            return UsageColorScheme.cursorIncludedColorSwiftUI(0)
        case .cursorOnDemand:
            return UsageColorScheme.cursorOnDemandColorSwiftUI(0)
        case .antigravityPrimary:
            return UsageColorScheme.antigravityPrimaryColorSwiftUI(0)
        case .antigravitySecondary:
            return UsageColorScheme.antigravitySecondaryColorSwiftUI(0)
        }
    }
}
