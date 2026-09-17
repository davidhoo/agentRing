//
//  EncryptedCredentialStore.swift
//  Agent Ring
//

import CryptoKit
import Foundation
import OSLog

/// 沙盒容器内的 AES-GCM 加密凭据存储，替代系统钥匙串。
///
/// 背景：App 采用 ad-hoc 签名（无付费 Team ID），钥匙串条目的 ACL 只能绑定
/// 二进制 cdhash。Sparkle 每次更新都更换二进制，导致用户每次升级都要重新
/// 授权钥匙串访问。Data Protection Keychain 需要付费 Team ID（-34018），
/// 同样不可用。
///
/// 方案：凭据加密后存入沙盒容器（内核隔离其他 App，且不受 App 更新影响）：
/// - `credentials.key`：32 字节对称密钥，权限 0600，标记排除备份
/// - `credentials.enc`：AES-GCM 密文（含认证标签，防篡改）
///
/// 安全边界：密钥与密文同在容器内，能防「其他 App 读取」「备份/迁移泄露
/// 明文」，不防已获得本用户权限的攻击者——这是零弹窗前提下可达的最优解。
struct EncryptedCredentialStore {
    private let directory: URL
    private let keyURL: URL
    private let dataURL: URL
    private let logger = Logger(subsystem: "app.agentring.AgentRing", category: "CredentialStore")

    /// 测试可通过自定义目录注入；生产用沙盒 Application Support。
    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AgentRing", isDirectory: true)
        self.directory = base
        self.keyURL = base.appendingPathComponent("credentials.key")
        self.dataURL = base.appendingPathComponent("credentials.enc")
    }

    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("credentials_\(safeKey).enc")
    }

    func hasStoredData(key: String = "accounts") -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: key).path)
    }

    // MARK: - 读写

    /// 读取并解密指定 key。文件不存在返回 nil；解密失败返回 nil。
    func load(key: String) -> String? {
        let dataURL = fileURL(for: key)
        guard let keyData = loadKey(), let sealed = try? Data(contentsOf: dataURL) else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: sealed)
            let plain = try AES.GCM.open(box, using: keyData)
            guard let value = String(data: plain, encoding: .utf8) else { return nil }
            return value
        } catch {
            logger.error("凭据解密失败(\(key, privacy: .public))，回退旧存储: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 加密并落盘指定 key。成功返回 true。
    func save(key: String, value: String) -> Bool {
        let dataURL = fileURL(for: key)
        guard let keyData = loadOrCreateKey(),
              let plain = value.data(using: .utf8) else { return false }
        do {
            let box = try AES.GCM.seal(plain, using: keyData)
            guard let combined = box.combined else { return false }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try combined.write(to: dataURL, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            logger.error("凭据加密写入失败(\(key, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 删除指定 key 的密文文件。
    func delete(key: String) -> Bool {
        let dataURL = fileURL(for: key)
        do {
            try FileManager.default.removeItem(at: dataURL)
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                return true
            }
            logger.error("凭据删除失败(\(key, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - 默认便捷方法（默认 key: accounts）
    func load() -> String? { load(key: "accounts") }
    func save(_ value: String) -> Bool { save(key: "accounts", value: value) }
    func delete() -> Bool { delete(key: "accounts") }

    // MARK: - 密钥管理

    /// 读取既有密钥；不存在则生成 32 字节新密钥并以 0600 落盘、排除备份。
    private func loadOrCreateKey() -> SymmetricKey? {
        if let existing = loadKey() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        guard let raw = newKey.withUnsafeBytes({ Data($0) }) as Data? else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try raw.write(to: keyURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
            excludeFromBackup(keyURL)
            return newKey
        } catch {
            logger.error("密钥文件写入失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func loadKey() -> SymmetricKey? {
        guard let raw = try? Data(contentsOf: keyURL), raw.count == 32 else { return nil }
        return SymmetricKey(data: raw)
    }

    /// 密钥永远留在本机：标记文件排除出 Time Machine 等系统备份。
    /// 密文即使被备份带走，没有密钥也无法解密。
    private func excludeFromBackup(_ url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            // 标记失败不阻断主流程，但必须留下日志
            logger.error("密钥排除备份标记失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}
