//
//  GitHubUpdateManager.swift
//  AgentRing
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
/// 支持手动检测更新、每 1 小时自动后台定时检测、一键下载 DMG 安装包
final class GitHubUpdateManager: ObservableObject {
    static let shared = GitHubUpdateManager()

    @Published var isChecking = false
    @Published var lastCheckTime: Date?
    @Published var lastCheckMessage: String?
    @Published var availableRelease: GitHubRelease?
    @Published var isDownloading = false

    private let repoOwner = "haorui-lab"
    private let repoName = "agentRing"
    private var autoCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private init() {
        NotificationCenter.default.publisher(for: .autoUpdateSettingChanged)
            .sink { [weak self] _ in
                self?.setupAutoUpdateTimer()
            }
            .store(in: &cancellables)
    }

    /// 启动自动更新调度
    func start() {
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

        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates(isUserInitiated: false)
        }
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
                sendUpdateNotification(release: release)
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
        alert.addButton(withTitle: L.SettingsUpdate.downloadAndInstall)
        alert.addButton(withTitle: L.SettingsUpdate.viewOnGitHub)
        alert.addButton(withTitle: L.SettingsUpdate.later)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            downloadAndInstall(release: release)
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

    private func sendUpdateNotification(release: GitHubRelease) {
        let content = UNMutableNotificationContent()
        content.title = L.SettingsUpdate.alertTitle(release.tagName)
        content.body = L.SettingsUpdate.notificationBody(release.tagName)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "github_update_\(release.tagName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Download and Install

    func downloadAndInstall(release: GitHubRelease) {
        let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
        let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") })

        guard let asset = dmgAsset ?? zipAsset,
              let downloadUrl = URL(string: asset.browserDownloadUrl) else {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
            return
        }

        isDownloading = true
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let destinationUrl = downloadsDir.appendingPathComponent(asset.name)

        URLSession.shared.downloadTask(with: downloadUrl) { [weak self] tempUrl, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isDownloading = false

                if let error {
                    let errAlert = NSAlert()
                    errAlert.messageText = L.SettingsUpdate.downloadFailedTitle
                    errAlert.informativeText = error.localizedDescription
                    errAlert.alertStyle = .warning
                    errAlert.addButton(withTitle: L.Update.okButton)
                    errAlert.runModal()
                    return
                }

                guard let tempUrl else { return }

                do {
                    if FileManager.default.fileExists(atPath: destinationUrl.path) {
                        try FileManager.default.removeItem(at: destinationUrl)
                    }
                    try FileManager.default.moveItem(at: tempUrl, to: destinationUrl)

                    // 打开下载的 DMG / ZIP 安装包
                    NSWorkspace.shared.open(destinationUrl)

                    let successAlert = NSAlert()
                    successAlert.messageText = L.SettingsUpdate.downloadSuccessTitle
                    successAlert.informativeText = L.SettingsUpdate.downloadSuccessMessage(asset.name)
                    successAlert.alertStyle = .informational
                    successAlert.addButton(withTitle: L.Update.okButton)
                    successAlert.runModal()
                } catch {
                    let errAlert = NSAlert()
                    errAlert.messageText = L.SettingsUpdate.downloadFailedTitle
                    errAlert.informativeText = error.localizedDescription
                    errAlert.alertStyle = .warning
                    errAlert.addButton(withTitle: L.Update.okButton)
                    errAlert.runModal()
                }
            }
        }.resume()
    }
}
