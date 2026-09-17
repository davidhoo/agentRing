import CryptoKit
import Foundation

// EncryptedCredentialStore 行为测试：加密往返、密钥排除备份、篡改拒绝、迁移回退。
// 独立于 App 运行，用临时目录注入。用法：swiftc EncryptedCredentialStore.swift 本文件 && 运行

@main
struct CredentialStoreChecks {
    static func main() {
        let fm = FileManager.default

        func expect(_ condition: Bool, _ name: String) {
            if !condition {
                print("FAIL: \(name)")
                exit(1)
            }
            print("PASS: \(name)")
        }

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("credential-store-checks-\(UUID().uuidString)")
        try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try! fm.removeItem(at: dir) }

        // 1. 首次保存：生成密钥 + 密文，明文不落盘
        let store = EncryptedCredentialStore(directory: dir)
        let payload = #"{"token":"sk-secret-123","name":"test"}"#
        expect(store.save(payload), "save succeeds")
        let keyURL = dir.appendingPathComponent("credentials.key")
        let dataURL = dir.appendingPathComponent("credentials_accounts.enc")
        expect(fm.fileExists(atPath: keyURL.path), "key file created")
        expect(fm.fileExists(atPath: dataURL.path), "cipher file created")
        let rawCipher = try! Data(contentsOf: dataURL)
        expect(String(data: rawCipher, encoding: .utf8)?.contains("sk-secret-123") != true, "cipher contains no plaintext token")

        // 2. 读取往返
        expect(store.load() == payload, "load round-trips")

        // 3. 密钥权限 0600 + 排除备份标记
        let attrs = try! fm.attributesOfItem(atPath: keyURL.path)
        expect((attrs[.posixPermissions] as? Int) == 0o600, "key file is 0600")
        let values = try! keyURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        expect(values.isExcludedFromBackup == true, "key excluded from backup")

        // 4. 模拟版本更新：新进程视角（同容器目录）仍能解密
        let storeAfterUpdate = EncryptedCredentialStore(directory: dir)
        expect(storeAfterUpdate.load() == payload, "load after app replacement (new instance)")

        // 5. 篡改密文 → 解密失败返回 nil（GCM 认证标签不匹配）
        var tampered = rawCipher
        tampered[10] ^= 0xFF
        try! tampered.write(to: dataURL)
        expect(storeAfterUpdate.load() == nil, "tampered cipher rejected")

        // 6. 删除密钥文件模拟密钥丢失 → 返回 nil 而非崩溃；重新保存可自愈
        try! fm.removeItem(at: keyURL)
        expect(storeAfterUpdate.load() == nil, "missing key returns nil")
        expect(storeAfterUpdate.save(payload) && storeAfterUpdate.load() == payload, "re-save regenerates key")

        // 7. delete 清理密文
        expect(storeAfterUpdate.delete(), "delete succeeds")
        expect(!fm.fileExists(atPath: dataURL.path), "cipher removed")
        expect(storeAfterUpdate.load() == nil, "load after delete is nil")

        // 8. AES-GCM 算法自检：同明文两次加密产生不同密文（随机 nonce）
        let s1 = EncryptedCredentialStore(directory: dir)
        _ = s1.save(payload)
        let c1 = try! Data(contentsOf: dir.appendingPathComponent("credentials_accounts.enc"))
        let s2 = EncryptedCredentialStore(directory: dir)
        _ = s2.save(payload)
        let c2 = try! Data(contentsOf: dir.appendingPathComponent("credentials_accounts.enc"))
        expect(c1 != c2, "random nonce per encryption")

        // 9. 多 key 隔离测试：Codex 与 Cursor 互不覆盖、独立删除
        let multiStore = EncryptedCredentialStore(directory: dir)
        let codexData = #"{"provider":"codex","token":"token_codex"}"#
        let cursorData = #"{"provider":"cursor","token":"token_cursor"}"#
        expect(multiStore.save(key: "accounts_codex", value: codexData), "save codex succeeds")
        expect(multiStore.save(key: "accounts_cursor", value: cursorData), "save cursor succeeds")
        expect(multiStore.load(key: "accounts_codex") == codexData, "load codex isolated")
        expect(multiStore.load(key: "accounts_cursor") == cursorData, "load cursor isolated")
        expect(multiStore.delete(key: "accounts_codex"), "delete codex succeeds")
        expect(multiStore.load(key: "accounts_codex") == nil, "codex deleted")
        expect(multiStore.load(key: "accounts_cursor") == cursorData, "cursor survives codex deletion")

        print("All credential store checks passed.")
    }
}
