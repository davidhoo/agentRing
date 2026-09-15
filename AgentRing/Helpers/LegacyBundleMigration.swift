//
//  LegacyBundleMigration.swift
//  Agent Ring
//

import Foundation
import OSLog

/// Bundle ID 从 `app.agentsring.AgentsRing` 迁到 `app.agentring.AgentRing` 时，
/// 把旧偏好域里的用户设置拷到当前域（Keychain 由 KeychainManager 自行处理）。
enum LegacyBundleMigration {
    private static let flagKey = "didMigrateFromAgentsRingBundleID.v4"
    private static let legacyBundleID = "app.agentsring.AgentsRing"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        var migratedDict: [String: Any] = [:]

        // 1. 优先直接读取旧沙盒容器路径下的 plist 实体文件
        var candidatePaths: [String] = []
        let home = NSHomeDirectory()
        if let range = home.range(of: "/Library/Containers/") {
            let containersRoot = String(home[..<range.upperBound])
            candidatePaths.append("\(containersRoot)\(legacyBundleID)/Data/Library/Preferences/\(legacyBundleID).plist")
        }
        if let user = NSUserName() as String?, let userHome = NSHomeDirectoryForUser(user) {
            candidatePaths.append("\(userHome)/Library/Containers/\(legacyBundleID)/Data/Library/Preferences/\(legacyBundleID).plist")
            candidatePaths.append("\(userHome)/Library/Preferences/\(legacyBundleID).plist")
        }

        for path in candidatePaths {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               !plist.isEmpty {
                for (k, v) in plist {
                    migratedDict[k] = v
                }
                Logger.settings.notice("已从旧沙盒偏好文件成功读取 \(plist.count) 项配置: \(path)")
                break
            }
        }

        // 2. 回退尝试 UserDefaults(suiteName:)
        if migratedDict.isEmpty, let legacy = UserDefaults(suiteName: legacyBundleID) {
            for (k, v) in legacy.dictionaryRepresentation() {
                migratedDict[k] = v
            }
        }

        // 3. 写入当前域（跳过系统自带前缀键）
        let skipPrefixes = ["NS", "Apple", "com.apple", "SU", "didMigrateFrom"]
        var count = 0
        for (key, value) in migratedDict {
            if skipPrefixes.contains(where: { key.hasPrefix($0) }) {
                continue
            }
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
                count += 1
            }
        }

        defaults.set(true, forKey: flagKey)
        defaults.synchronize()
        Logger.settings.notice("完成 Bundle ID 迁移，成功写入 \(count) 项配置")
    }
}
