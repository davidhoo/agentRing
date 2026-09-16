//
//  KeychainManager.swift
//  Agent Ring
//

import Foundation
import Security
import OSLog

/// 管理 Keychain 存储的类
/// 用于安全存储 Codex 账户凭据
/// Debug 模式：使用 UserDefaults（便于开发测试，不弹窗）
/// Release 模式：使用 Keychain（安全存储）
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {
        #if !DEBUG
        // 动态获取 Bundle ID，如果获取失败则使用默认值
        if let bundleID = Bundle.main.bundleIdentifier {
            service = bundleID
        }
        migrateFromLegacyServiceIfNeeded()
        #endif
    }
    
    // MARK: - Keychain 配置
    
    #if DEBUG
    /// Debug 模式：UserDefaults key 前缀
    private let debugKeyPrefix = "DEBUG_"
    #else
    /// Keychain 服务标识符（自动从 Bundle 获取）
    private var service: String = "app.agentring.AgentRing"
    /// 旧版 Bundle ID 对应的 Keychain service，用于一次性迁移
    private let legacyService = "app.agentsring.AgentsRing"
    private let migratableAccountKeys = ["accounts", "accounts_codex", "accounts_cursor"]
    #endif
    
    // MARK: - 账户列表存储（v2.1.0 多账户支持）

    #if DEBUG
    /// 保存账户列表到 UserDefaults（Debug 模式）
    /// - Parameter accounts: 账户列表
    /// - Returns: 是否保存成功
    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accounts) else {
            Logger.keychain.error("[Debug] 账户列表编码失败")
            return false
        }
        UserDefaults.standard.set(data, forKey: debugKeyPrefix + "accounts")
        Logger.keychain.debug("[Debug] 保存 \(accounts.count) 个账户到 UserDefaults")
        return true
    }

    /// 从 UserDefaults 读取账户列表（Debug 模式）
    /// - Returns: 账户列表，如果不存在返回 nil
    func loadAccounts() -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: debugKeyPrefix + "accounts") else {
            Logger.keychain.debug("[Debug] 账户列表不存在")
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: data) else {
            Logger.keychain.error("[Debug] 账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("[Debug] 读取 \(accounts.count) 个账户")
        return accounts
    }

    /// 从 UserDefaults 删除账户列表（Debug 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccounts() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "accounts")
        Logger.keychain.debug("[Debug] 删除账户列表")
        return true
    }
    #else
    /// 保存账户列表到 Keychain（Release 模式）
    /// - Parameter accounts: 账户列表
    /// - Returns: 是否保存成功
    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(accounts),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.keychain.error("账户列表编码失败")
            return false
        }
        let result = save(key: "accounts", value: jsonString)
        if result {
            Logger.keychain.debug("保存 \(accounts.count) 个账户到 Keychain")
        }
        return result
    }

    /// 从 Keychain 读取账户列表（Release 模式）
    /// - Returns: 账户列表，如果不存在返回 nil
    func loadAccounts() -> [Account]? {
        guard let jsonString = load(key: "accounts"),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: jsonData) else {
            Logger.keychain.error("账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("读取 \(accounts.count) 个账户")
        return accounts
    }

    /// 从 Keychain 删除账户列表（Release 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccounts() -> Bool {
        return delete(key: "accounts")
    }
    #endif

    // MARK: - Codex 账户列表存储

    #if DEBUG
    @discardableResult
    func saveCodexAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accounts) else {
            Logger.keychain.error("[Debug] Codex 账户列表编码失败")
            return false
        }
        UserDefaults.standard.set(data, forKey: debugKeyPrefix + "accounts_codex")
        Logger.keychain.debug("[Debug] 保存 \(accounts.count) 个 Codex 账户到 UserDefaults")
        return true
    }

    func loadCodexAccounts() -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: debugKeyPrefix + "accounts_codex") else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: data) else {
            Logger.keychain.error("[Debug] Codex 账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("[Debug] 读取 \(accounts.count) 个 Codex 账户")
        return accounts
    }

    @discardableResult
    func deleteCodexAccounts() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "accounts_codex")
        Logger.keychain.debug("[Debug] 删除 Codex 账户列表")
        return true
    }
    #else
    @discardableResult
    func saveCodexAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(accounts),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.keychain.error("Codex 账户列表编码失败")
            return false
        }
        let result = save(key: "accounts_codex", value: jsonString)
        if result {
            Logger.keychain.debug("保存 \(accounts.count) 个 Codex 账户到 Keychain")
        }
        return result
    }

    func loadCodexAccounts() -> [Account]? {
        guard let jsonString = load(key: "accounts_codex"),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: jsonData) else {
            Logger.keychain.error("Codex 账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("读取 \(accounts.count) 个 Codex 账户")
        return accounts
    }

    @discardableResult
    func deleteCodexAccounts() -> Bool {
        return delete(key: "accounts_codex")
    }
    #endif

    // MARK: - Cursor 账户列表存储

    #if DEBUG
    @discardableResult
    func saveCursorAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accounts) else {
            Logger.keychain.error("[Debug] Cursor 账户列表编码失败")
            return false
        }
        UserDefaults.standard.set(data, forKey: debugKeyPrefix + "accounts_cursor")
        return true
    }

    func loadCursorAccounts() -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: debugKeyPrefix + "accounts_cursor") else {
            return nil
        }
        return try? JSONDecoder().decode([Account].self, from: data)
    }

    @discardableResult
    func deleteCursorAccounts() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "accounts_cursor")
        return true
    }
    #else
    @discardableResult
    func saveCursorAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(accounts),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }
        return save(key: "accounts_cursor", value: jsonString)
    }

    func loadCursorAccounts() -> [Account]? {
        guard let jsonString = load(key: "accounts_cursor"),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([Account].self, from: jsonData)
    }

    @discardableResult
    func deleteCursorAccounts() -> Bool {
        return delete(key: "accounts_cursor")
    }
    #endif

    #if !DEBUG
    // MARK: - 通用 Keychain 操作（仅 Release 模式）

    /// 将旧 Bundle ID 下的凭据迁到当前 service，避免改名后要重新登录
    private func migrateFromLegacyServiceIfNeeded() {
        guard service != legacyService else { return }

        for key in migratableAccountKeys {
            if load(key: key, service: service) != nil {
                continue
            }
            guard let legacyValue = load(key: key, service: legacyService) else {
                continue
            }
            if save(key: key, value: legacyValue, service: service) {
                _ = delete(key: key, service: legacyService)
                Logger.keychain.info("已从旧 Keychain service 迁移: \(key)")
            }
        }
    }
    
    /// 保存数据到 Keychain
    /// - Parameters:
    ///   - key: 键名
    ///   - value: 要保存的值
    /// - Returns: 是否保存成功
    private func save(key: String, value: String) -> Bool {
        save(key: key, value: value, service: service)
    }

    private func save(key: String, value: String, service: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // 构建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 先尝试删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            Logger.keychain.error("Keychain 保存失败: \(key), 状态码: \(status)")
            return false
        }
    }
    
    /// 从 Keychain 读取数据
    /// - Parameter key: 键名
    /// - Returns: 读取的值，如果不存在返回 nil
    private func load(key: String) -> String? {
        load(key: key, service: service)
    }

    private func load(key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        } else if status != errSecItemNotFound {
            Logger.keychain.error("Keychain 读取失败: \(key), 状态码: \(status)")
        }

        return nil
    }
    
    /// 从 Keychain 删除数据
    /// - Parameter key: 键名
    /// - Returns: 是否删除成功
    private func delete(key: String) -> Bool {
        delete(key: key, service: service)
    }

    private func delete(key: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            Logger.keychain.error("Keychain 删除失败: \(key), 状态码: \(status)")
            return false
        }
    }
    #endif
}
