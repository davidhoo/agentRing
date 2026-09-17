import AppKit
import Combine
import OSLog
import Sparkle

/// Owns update UI state. Sparkle owns scheduling, signature checks, installation and relaunch.
/// Keep this object alive for the lifetime of the application (Sparkle's delegates are weak).
final class AppUpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = AppUpdateManager()

    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var lastCheckTime: Date?
    @Published private(set) var lastCheckMessage: String?
    @Published private(set) var availableVersion: String?

    private var controller: SPUStandardUpdaterController?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "app.agentring.AgentRing", category: "Update")

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private override init() {
        super.init()
        NotificationCenter.default.publisher(for: .autoUpdateSettingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.controller?.updater.automaticallyChecksForUpdates = UserSettings.shared.autoUpdateEnabled
            }
            .store(in: &cancellables)
    }

    func start() {
        guard controller == nil else { return }
        // Local builds without a release key stay usable, but cannot install unverified updates.
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else {
            lastCheckMessage = L.SettingsUpdate.notConfigured
            logger.error("Updates disabled: missing or invalid SUPublicEDKey")
            return
        }

        // Migrate the old opt-out before Sparkle schedules its first check.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUEnableAutomaticChecks") == nil {
            defaults.set(UserSettings.shared.autoUpdateEnabled, forKey: "SUEnableAutomaticChecks")
        }
        let newController = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: self, userDriverDelegate: self
        )
        do {
            try newController.updater.start()
            controller = newController
            lastCheckTime = newController.updater.lastUpdateCheckDate
        } catch {
            lastCheckMessage = L.SettingsUpdate.checkFailed
            logger.error("Cannot start updater: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates(isUserInitiated: Bool) {
        if controller == nil { start() }
        guard let controller else {
            if isUserInitiated {
                let alert = NSAlert()
                alert.messageText = L.SettingsUpdate.checkFailed
                alert.informativeText = lastCheckMessage ?? L.SettingsUpdate.notConfigured
                alert.runModal()
            }
            return
        }
        if isUserInitiated {
            // Also brings an already-presented update window back into focus.
            controller.checkForUpdates(nil)
        } else if controller.updater.automaticallyChecksForUpdates && !controller.updater.sessionInProgress {
            controller.updater.checkForUpdatesInBackground()
        }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        isChecking = true
        lastCheckMessage = L.SettingsUpdate.checking
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isChecking = false
        lastCheckTime = Date()
        availableVersion = item.displayVersionString
        lastCheckMessage = L.SettingsUpdate.updateAvailable(item.displayVersionString)
        AppDelegate.shared?.menuBarManager?.applyUpdateAvailable(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        isChecking = false
        lastCheckTime = Date()
        availableVersion = nil
        // Sparkle also reports unsupported OS/hardware here; don't call that "up to date".
        lastCheckMessage = error.localizedDescription
        AppDelegate.shared?.menuBarManager?.applyUpdateNotFound()
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        isDownloading = true
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        isDownloading = false
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isChecking = false
        isDownloading = false
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain,
           [SUError.noUpdateError, .installationCanceledError, .installationAuthorizeLaterError]
            .contains(where: { Int($0.rawValue) == nsError.code }) {
            return
        }
        lastCheckMessage = L.SettingsUpdate.checkFailed
        logger.error("Update failed: \(error.localizedDescription, privacy: .public)")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        isChecking = false
        isDownloading = false
        lastCheckTime = Date()
    }

    // Agent Ring is a menu bar app: its existing badge is the gentle reminder.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
        AppDelegate.shared?.menuBarManager?.applyUpdateAvailable(version: update.displayVersionString)
    }
}
