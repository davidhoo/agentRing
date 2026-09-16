//
//  Account.swift
//  Agent Ring
//

import Foundation

struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var credentialToken: String
    var accountIdentifier: String
    var accountName: String
    var alias: String?
    let createdAt: Date
    var provider: ProviderType

    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return alias
        }
        return accountName
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id, credentialToken, accountIdentifier, accountName, alias, createdAt, provider
        case legacySessionKey = "sessionKey"
        case legacyOrganizationId = "organizationId"
        case legacyOrganizationName = "organizationName"
    }

    // MARK: - Codable

    // 自定义解码：兼容旧 keychain 数据，重新保存后会写入 Codex-only 字段名。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let storedToken = try container.decodeIfPresent(String.self, forKey: .credentialToken) {
            credentialToken = storedToken
        } else {
            credentialToken = try container.decode(String.self, forKey: .legacySessionKey)
        }
        if let storedIdentifier = try container.decodeIfPresent(String.self, forKey: .accountIdentifier) {
            accountIdentifier = storedIdentifier
        } else {
            accountIdentifier = try container.decode(String.self, forKey: .legacyOrganizationId)
        }
        if let storedName = try container.decodeIfPresent(String.self, forKey: .accountName) {
            accountName = storedName
        } else {
            accountName = try container.decode(String.self, forKey: .legacyOrganizationName)
        }
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        provider = try container.decodeIfPresent(ProviderType.self, forKey: .provider) ?? .codex
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(credentialToken, forKey: .credentialToken)
        try container.encode(accountIdentifier, forKey: .accountIdentifier)
        try container.encode(accountName, forKey: .accountName)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(provider, forKey: .provider)
    }

    // MARK: - Initialization

    init(
        credentialToken: String,
        accountIdentifier: String,
        accountName: String,
        alias: String? = nil,
        provider: ProviderType = .codex
    ) {
        self.id = UUID()
        self.credentialToken = credentialToken
        self.accountIdentifier = accountIdentifier
        self.accountName = accountName
        self.alias = alias
        self.createdAt = Date()
        self.provider = provider
    }

    init(
        id: UUID,
        credentialToken: String,
        accountIdentifier: String,
        accountName: String,
        alias: String?,
        createdAt: Date,
        provider: ProviderType = .codex
    ) {
        self.id = id
        self.credentialToken = credentialToken
        self.accountIdentifier = accountIdentifier
        self.accountName = accountName
        self.alias = alias
        self.createdAt = createdAt
        self.provider = provider
    }

    // MARK: - Equatable

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
}
