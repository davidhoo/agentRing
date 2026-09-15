//
//  LegacyBundleMigration.swift
//  Agent Ring
//

import Foundation

/// Bundle ID 从 `app.agentsring.AgentsRing` 迁到 `app.agentring.AgentRing` 时，
/// 把旧偏好域里的用户设置拷到当前域（Keychain 由 KeychainManager 自行处理）。
enum LegacyBundleMigration {
    private static let flagKey = "didMigrateFromAgentsRingBundleID"
    private static let legacyBundleID = "app.agentsring.AgentsRing"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }

        if let legacy = UserDefaults(suiteName: legacyBundleID) {
            let skipPrefixes = ["NS", "Apple", "com.apple", "SU"]
            for (key, value) in legacy.dictionaryRepresentation() {
                if skipPrefixes.contains(where: { key.hasPrefix($0) }) {
                    continue
                }
                if defaults.object(forKey: key) == nil {
                    defaults.set(value, forKey: key)
                }
            }
        }

        defaults.set(true, forKey: flagKey)
    }
}
