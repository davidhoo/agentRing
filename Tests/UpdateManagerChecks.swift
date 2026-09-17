import AppKit
import Sparkle

// Small host stubs let us test the real AppUpdateManager without opening Agent Ring or reading accounts.
extension Notification.Name { static let autoUpdateSettingChanged = Notification.Name("test.autoUpdateChanged") }
final class UserSettings {
    static let shared = UserSettings()
    var autoUpdateEnabled = false
}
final class TestMenuBar {
    var hasUpdate = false
    func applyUpdateAvailable(version: String?) { hasUpdate = true }
    func applyUpdateNotFound() { hasUpdate = false }
}
final class AppDelegate {
    static let shared: AppDelegate? = AppDelegate()
    var menuBarManager: TestMenuBar? = TestMenuBar()
}
enum L {
    enum SettingsUpdate {
        static let checking = "checking"
        static let checkFailed = "failed"
        static let notConfigured = "not configured"
        static func updateAvailable(_ version: String) -> String { "update \(version)" }
    }
}

@main
struct UpdateManagerChecks {
    @MainActor static func main() throws {
        let manager = AppUpdateManager.shared
        // Optional ObjC delegate misspellings otherwise compile silently.
        for selector in [
            "updater:mayPerformUpdateCheck:error:", "updater:didFindValidUpdate:",
            "updaterDidNotFindUpdate:error:", "updater:willDownloadUpdate:withRequest:",
            "updater:didDownloadUpdate:", "updater:didAbortWithError:",
            "updater:didFinishUpdateCycleForUpdateCheck:error:",
            "supportsGentleScheduledUpdateReminders",
            "standardUserDriverShouldHandleShowingScheduledUpdate:andInImmediateFocus:",
            "standardUserDriverWillHandleShowingUpdate:forUpdate:state:"
        ] {
            precondition(manager.responds(to: NSSelectorFromString(selector)), "Missing Sparkle callback: \(selector)")
        }
        manager.start()
        precondition(manager.lastCheckMessage == L.SettingsUpdate.notConfigured, "No-key local build must not start updating")
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let updater = controller.updater
        try manager.updater(updater, mayPerform: .updates)
        precondition(manager.isChecking)
        let noUpdate = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue), userInfo: [NSLocalizedDescriptionKey: "No compatible update"])
        manager.updaterDidNotFindUpdate(updater, error: noUpdate)
        manager.updater(updater, didAbortWithError: noUpdate)
        precondition(!manager.isChecking && manager.lastCheckMessage == "No compatible update", "No-update must not become failure")
        let cancelled = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.installationCanceledError.rawValue))
        manager.updater(updater, didAbortWithError: cancelled)
        precondition(manager.lastCheckMessage == "No compatible update", "Cancellation must not become failure")
        manager.updater(updater, didAbortWithError: NSError(domain: SUSparkleErrorDomain, code: Int(SUError.validationError.rawValue)))
        precondition(manager.lastCheckMessage == L.SettingsUpdate.checkFailed)
        print("PASS: Sparkle delegate selectors, missing key, no-update, cancellation and failure states")
    }
}
