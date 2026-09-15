//
//  SensitiveDataRedactor.swift
//  CodexRings
//

import Foundation

/// 敏感数据脱敏工具
/// 提供统一的敏感信息脱敏方法，用于日志记录和诊断报告
/// 支持 Codex session-token、refresh-token、access-token 和文本中的敏感信息脱敏
class SensitiveDataRedactor {
    // MARK: - Public Methods

    /// 脱敏 Codex Session Token（JWE 长串）
    /// - Parameter token: __Secure-next-auth.session-token 的值
    /// - Returns: 脱敏后的字符串，保留前8位和后4位
    static func redactCodexSessionToken(_ token: String) -> String {
        guard token.count > 12 else {
            return String(repeating: "*", count: token.count)
        }
        return "\(token.prefix(8))...\(token.suffix(4)) (\(token.count) chars)"
    }

    /// 脱敏 JWT Access Token（三段式 header.payload.signature）
    /// - Parameter token: Bearer accessToken 字符串
    /// - Returns: 脱敏后的字符串，每段只保留前6字符
    static func redactAccessToken(_ token: String) -> String {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            guard token.count > 12 else { return "***" }
            return "\(token.prefix(8))...\(token.suffix(4)) (\(token.count) chars)"
        }
        let h = String(parts[0].prefix(6))
        let p = String(parts[1].prefix(6))
        let s = String(parts[2].prefix(6))
        return "\(h)...\(p)...\(s)... (\(token.count) chars)"
    }

    /// 脱敏文本中的敏感信息
    /// 使用正则表达式查找并替换文本中的 Codex token
    /// - Parameter text: 包含敏感信息的原始文本
    /// - Returns: 脱敏后的文本
    /// - Note: 用于日志和诊断输出，自动识别并脱敏常见格式
    static func redactText(_ text: String) -> String {
        var sanitized = text

        let replacements: [(pattern: String, template: String)] = [
            ("(__Secure-next-auth\\.session-token\\s*[=:]\\s*)[^;\\s\"']+", "$1***REDACTED***"),
            ("(session-token\\s*[=:]\\s*)[^;\\s\"']+", "$1***REDACTED***"),
            ("(refresh_token\\s*[=:]\\s*)[^;\\s\"']+", "$1***REDACTED***"),
            ("(accessToken\\s*[=:]\\s*)[^;\\s\"']+", "$1***REDACTED***"),
            ("(Authorization:\\s*Bearer\\s+)[^;\\s\"']+", "$1***REDACTED***")
        ]

        for replacement in replacements {
            guard let regex = try? NSRegularExpression(pattern: replacement.pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: replacement.template
            )
        }

        return sanitized
    }
}
