//
//  AppUpdateInstaller.swift
//  Agent Ring
//
//  类似 Buddy(electron-updater quitAndInstall) 的原生安装流：
//  下载 ZIP → 解压 → 清除隔离属性 → 替换当前 .app → 自动重启。
//

import AppKit
import Foundation

enum AppUpdateInstallerError: LocalizedError {
    case zipNotFound
    case appBundleNotFound
    case cannotWriteInstallScript
    case destinationNotWritable(URL)

    var errorDescription: String? {
        switch self {
        case .zipNotFound:
            return "Update zip package not found."
        case .appBundleNotFound:
            return "AgentRing.app not found inside the update package."
        case .cannotWriteInstallScript:
            return "Failed to write the install helper script."
        case .destinationNotWritable(let url):
            return "Cannot write to \(url.path). Move Agent Ring into /Applications and try again."
        }
    }
}

enum AppUpdateInstaller {

    /// 清除 Gatekeeper 隔离属性。下载后的 ad-hoc 包若不清除，常会直接提示「无法打开」。
    @discardableResult
    static func clearQuarantine(at url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", url.path]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 从 ZIP 解压出 AgentRing.app，返回解压后的 .app URL。
    static func extractApp(fromZip zipURL: URL, to directory: URL) throws -> URL {
        let extractRoot = directory.appendingPathComponent("extracted-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: extractRoot.path) {
            try FileManager.default.removeItem(at: extractRoot)
        }
        try FileManager.default.createDirectory(at: extractRoot, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, extractRoot.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateInstallerError.appBundleNotFound
        }

        guard let appURL = findAppBundle(in: extractRoot) else {
            throw AppUpdateInstallerError.appBundleNotFound
        }

        clearQuarantine(at: appURL)
        return appURL
    }

    /// Buddy 式：退出当前进程 → 外部脚本替换 .app → 重新打开。
    static func quitAndInstall(fromNewApp newAppURL: URL) throws {
        clearQuarantine(at: newAppURL)

        let destination = Bundle.main.bundleURL
        let destinationParent = destination.deletingLastPathComponent()
        let inApplications = destination.path.hasPrefix("/Applications/")

        // /Applications 依赖 entitlements 临时例外；其他路径需本身可写
        guard inApplications
                || FileManager.default.isWritableFile(atPath: destinationParent.path)
                || FileManager.default.isWritableFile(atPath: destination.path) else {
            throw AppUpdateInstallerError.destinationNotWritable(destination)
        }

        let scriptURL = try writeInstallScript()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            newAppURL.path,
            destination.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        // 立刻退出，让脚本接管替换与重启
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    /// 若无法原地替换，至少清除隔离并打开新包（用户可手动替换）。
    static func openPreparedApp(_ appURL: URL) {
        clearQuarantine(at: appURL)
        NSWorkspace.shared.open(appURL)
    }

    // MARK: - Private

    private static func findAppBundle(in directory: URL) -> URL? {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    return fileURL
                }
            }
        }
        let direct = directory.appendingPathComponent("AgentRing.app")
        if fm.fileExists(atPath: direct.path) {
            return direct
        }
        return nil
    }

    private static func writeInstallScript() throws -> URL {
        let script = """
        #!/bin/bash
        set -euo pipefail
        PID="$1"
        SRC="$2"
        DST="$3"

        # 等待旧进程退出
        while /bin/kill -0 "$PID" 2>/dev/null; do
          /bin/sleep 0.2
        done
        /bin/sleep 0.4

        if [[ ! -d "$SRC" ]]; then
          exit 1
        fi

        /usr/bin/xattr -cr "$SRC" || true

        TMP_BACKUP="${DST}.agentring-backup-$$"
        if [[ -d "$DST" ]]; then
          /bin/rm -rf "$TMP_BACKUP" 2>/dev/null || true
          /bin/mv "$DST" "$TMP_BACKUP"
        fi

        if /usr/bin/ditto "$SRC" "$DST"; then
          /usr/bin/xattr -cr "$DST" || true
          /bin/rm -rf "$TMP_BACKUP" 2>/dev/null || true
          /usr/bin/open "$DST"
          exit 0
        fi

        # 失败则尽量回滚
        if [[ -d "$TMP_BACKUP" ]]; then
          /bin/mv "$TMP_BACKUP" "$DST" 2>/dev/null || true
        fi
        exit 1
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentring-install-\(UUID().uuidString).sh")
        guard let data = script.data(using: .utf8) else {
            throw AppUpdateInstallerError.cannotWriteInstallScript
        }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        return url
    }
}
