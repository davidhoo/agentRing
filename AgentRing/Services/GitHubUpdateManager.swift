//
//  GitHubUpdateManager.swift
//  Agent Ring
//

import AppKit
import Foundation
import UserNotifications
import Combine

/// GitHub Release 数据模型
struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// GitHub 版本更新管理器
/// 手动检测 + 每小时自动检测；开启「自动更新」时发现新版本会下载安装包并通知。
final class GitHubUpdateManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = GitHubUpdateManager()

    @Published var isChecking = false
    @Published var lastCheckTime: Date?
    @Published var lastCheckMessage: String?
    @Published var availableRelease: GitHubRelease?
    @Published var isDownloading = false

    private let repoOwner = "haorui-lab"
    private let repoName = "agentRing"
    private let notificationPrefix = "github_update_"
    private var autoCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastDownloadedPackageURL: URL?
    private var lastPreparedAppURL: URL?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private override init() {
        super.init()
        NotificationCenter.default.publisher(for: .autoUpdateSettingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupAutoUpdateTimer()
            }
            .store(in: &cancellables)
    }

    /// 启动自动更新调度
    func start() {
        UNUserNotificationCenter.current().delegate = self
        setupAutoUpdateTimer()

        // 启动后延时 5 秒进行初次静默检查（仅在勾选自动更新时）
        if UserSettings.shared.autoUpdateEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.checkForUpdates(isUserInitiated: false)
            }
        }
    }

    /// 设置每 1 小时 (3600 秒) 自动检测定时器
    func setupAutoUpdateTimer() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil

        guard UserSettings.shared.autoUpdateEnabled else { return }

        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates(isUserInitiated: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        autoCheckTimer = timer
    }

    /// 核心检查更新方法
    func checkForUpdates(isUserInitiated: Bool) {
        guard !isChecking else { return }

        DispatchQueue.main.async {
            self.isChecking = true
            if isUserInitiated {
                self.lastCheckMessage = L.SettingsUpdate.checking
            }
        }

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isChecking = false
                self.lastCheckMessage = L.SettingsUpdate.checkFailed
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AgentRing-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                self.lastCheckTime = Date()

                if let error {
                    self.lastCheckMessage = L.SettingsUpdate.checkFailed
                    if isUserInitiated {
                        self.showErrorAlert(error: error.localizedDescription)
                    }
                    return
                }

                guard let data,
                      let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self.lastCheckMessage = L.SettingsUpdate.checkFailed
                    if isUserInitiated {
                        self.showErrorAlert(error: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    }
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self.handleFetchedRelease(release, isUserInitiated: isUserInitiated)
                } catch {
                    self.lastCheckMessage = L.SettingsUpdate.checkFailed
                    if isUserInitiated {
                        self.showErrorAlert(error: error.localizedDescription)
                    }
                }
            }
        }.resume()
    }

    private func handleFetchedRelease(_ release: GitHubRelease, isUserInitiated: Bool) {
        let isNewer = Self.isNewer(remoteTag: release.tagName, currentVersion: currentVersion)

        if isNewer {
            availableRelease = release
            lastCheckMessage = L.SettingsUpdate.updateAvailable(release.tagName)
            AppDelegate.shared?.menuBarManager?.applyUpdateAvailable(version: release.tagName)

            if isUserInitiated {
                showUpdateAlert(release: release)
            } else {
                // 自动更新：静默下载安装包，完成后通知用户打开
                downloadAndInstall(release: release, silent: true)
            }
        } else {
            availableRelease = nil
            lastCheckMessage = L.SettingsUpdate.alreadyLatest(currentVersion)
            AppDelegate.shared?.menuBarManager?.applyUpdateNotFound()

            if isUserInitiated {
                showUpToDateAlert()
            }
        }
    }

    // MARK: - Semantic Version Comparison

    static func isNewer(remoteTag: String, currentVersion: String) -> Bool {
        let cleanRemote = remoteTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .components(separatedBy: "-").first ?? ""
        let cleanCurrent = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .components(separatedBy: "-").first ?? ""

        let remoteComponents = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let currentComponents = cleanCurrent.split(separator: ".").compactMap { Int($0) }

        let maxLen = max(remoteComponents.count, currentComponents.count)
        for i in 0..<maxLen {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    // MARK: - Alerts & Notifications

    private func showUpdateAlert(release: GitHubRelease) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L.SettingsUpdate.alertTitle(release.tagName)
        var info = L.SettingsUpdate.alertCurrentAndLatest(current: currentVersion, latest: release.tagName)
        if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            info.append("\n\n")
            info.append(L.SettingsUpdate.releaseNotesTitle)
            info.append("\n")
            info.append(body)
        }
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.SettingsUpdate.restartAndInstall)
        alert.addButton(withTitle: L.SettingsUpdate.viewOnGitHub)
        alert.addButton(withTitle: L.SettingsUpdate.later)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            downloadAndInstall(release: release, silent: false)
        } else if response == .alertSecondButtonReturn {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showUpToDateAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L.SettingsUpdate.upToDateTitle
        alert.informativeText = L.SettingsUpdate.upToDateMessage(currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.Update.okButton)
        alert.runModal()
    }

    private func showErrorAlert(error: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L.SettingsUpdate.checkFailed
        alert.informativeText = error
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.Update.okButton)
        alert.runModal()
    }

    private func sendUpdateNotification(release: GitHubRelease, downloaded: Bool) {
        let content = UNMutableNotificationContent()
        content.title = L.SettingsUpdate.alertTitle(release.tagName)
        content.body = downloaded
            ? L.SettingsUpdate.notificationDownloadedBody(release.tagName)
            : L.SettingsUpdate.notificationBody(release.tagName)
        content.sound = .default
        content.userInfo = [
            "tag": release.tagName,
            "html_url": release.htmlUrl,
            "downloaded": downloaded
        ]

        let request = UNNotificationRequest(
            identifier: "\(notificationPrefix)\(release.tagName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Download and Install

    /// 沙盒可写目录：Application Support/Agent Ring/Updates
    private func updatesDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Agent Ring/Updates", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func downloadAndInstall(release: GitHubRelease, silent: Bool = false) {
        // 优先 ZIP：便于解压后原地替换并自动重启（Buddy quitAndInstall 同思路）。
        // DMG 仅作兜底，打开后仍需用户手动拖入「应用程序」。
        let zipAsset = release.assets.first(where: {
            $0.name.lowercased().hasSuffix(".zip") && $0.name.lowercased().contains("macos")
        }) ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") })
        let dmgAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })

        guard let asset = zipAsset ?? dmgAsset,
              let downloadUrl = URL(string: asset.browserDownloadUrl) else {
            if !silent, let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            } else if silent {
                sendUpdateNotification(release: release, downloaded: false)
            }
            return
        }

        guard !isDownloading else { return }
        isDownloading = true

        URLSession.shared.downloadTask(with: downloadUrl) { [weak self] tempUrl, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDownloading = false

                if let error {
                    self.handleDownloadFailure(error.localizedDescription, release: release, silent: silent)
                    return
                }

                guard let tempUrl else { return }

                do {
                    let destinationUrl = try self.updatesDirectory().appendingPathComponent(asset.name)
                    if FileManager.default.fileExists(atPath: destinationUrl.path) {
                        try FileManager.default.removeItem(at: destinationUrl)
                    }
                    try FileManager.default.moveItem(at: tempUrl, to: destinationUrl)
                    self.lastDownloadedPackageURL = destinationUrl
                    AppUpdateInstaller.clearQuarantine(at: destinationUrl)

                    if asset.name.lowercased().hasSuffix(".zip") {
                        let appURL = try AppUpdateInstaller.extractApp(
                            fromZip: destinationUrl,
                            to: try self.updatesDirectory()
                        )
                        self.lastPreparedAppURL = appURL

                        if silent {
                            self.sendUpdateNotification(release: release, downloaded: true)
                        } else {
                            self.promptRestartAndInstall(release: release, appURL: appURL)
                        }
                    } else {
                        // DMG 兜底：清隔离后打开，无法做到静默替换重启
                        if silent {
                            self.sendUpdateNotification(release: release, downloaded: true)
                        } else {
                            NSWorkspace.shared.open(destinationUrl)
                            let successAlert = NSAlert()
                            successAlert.messageText = L.SettingsUpdate.downloadSuccessTitle
                            successAlert.informativeText = L.SettingsUpdate.downloadSuccessMessage(asset.name)
                            successAlert.alertStyle = .informational
                            successAlert.addButton(withTitle: L.Update.okButton)
                            successAlert.runModal()
                        }
                    }
                } catch {
                    self.handleDownloadFailure(error.localizedDescription, release: release, silent: silent)
                }
            }
        }.resume()
    }

    private func promptRestartAndInstall(release: GitHubRelease, appURL: URL) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L.SettingsUpdate.readyToInstallTitle(release.tagName)
        alert.informativeText = L.SettingsUpdate.readyToInstallMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.SettingsUpdate.restartAndInstall)
        alert.addButton(withTitle: L.SettingsUpdate.later)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            performInstall(appURL: appURL)
        }
    }

    private func performInstall(appURL: URL) {
        do {
            try AppUpdateInstaller.quitAndInstall(fromNewApp: appURL)
        } catch {
            // 无法原地替换时：清隔离并打开新包，同时提示用户
            AppUpdateInstaller.openPreparedApp(appURL)
            let errAlert = NSAlert()
            errAlert.messageText = L.SettingsUpdate.installFallbackTitle
            errAlert.informativeText = error.localizedDescription + "\n\n" + L.SettingsUpdate.installFallbackMessage
            errAlert.alertStyle = .warning
            errAlert.addButton(withTitle: L.Update.okButton)
            errAlert.runModal()
        }
    }

    private func handleDownloadFailure(_ message: String, release: GitHubRelease, silent: Bool) {
        if silent {
            sendUpdateNotification(release: release, downloaded: false)
        } else {
            let errAlert = NSAlert()
            errAlert.messageText = L.SettingsUpdate.downloadFailedTitle
            errAlert.informativeText = message
            errAlert.alertStyle = .warning
            errAlert.addButton(withTitle: L.Update.okButton)
            errAlert.runModal()
        }
    }

    private func openDownloadedPackageOrReleasePage(for release: GitHubRelease) {
        if let appURL = lastPreparedAppURL,
           FileManager.default.fileExists(atPath: appURL.path) {
            performInstall(appURL: appURL)
            return
        }
        if let package = lastDownloadedPackageURL,
           FileManager.default.fileExists(atPath: package.path) {
            if package.pathExtension.lowercased() == "zip" {
                do {
                    let appURL = try AppUpdateInstaller.extractApp(
                        fromZip: package,
                        to: try updatesDirectory()
                    )
                    lastPreparedAppURL = appURL
                    performInstall(appURL: appURL)
                    return
                } catch {
                    handleDownloadFailure(error.localizedDescription, release: release, silent: false)
                    return
                }
            }
            AppUpdateInstaller.clearQuarantine(at: package)
            NSWorkspace.shared.open(package)
            return
        }
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        guard id.hasPrefix(notificationPrefix) else {
            completionHandler()
            return
        }

        DispatchQueue.main.async {
            if let release = self.availableRelease {
                self.openDownloadedPackageOrReleasePage(for: release)
            } else if let html = response.notification.request.content.userInfo["html_url"] as? String,
                      let url = URL(string: html) {
                NSWorkspace.shared.open(url)
            }
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier.hasPrefix(notificationPrefix) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
