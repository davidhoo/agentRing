//
//  ProviderType.swift
//  agentsRing
//

import Foundation

enum ProviderType: String, Codable, CaseIterable, Hashable {
    case codex
    case cursor
    case antigravity

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        }
    }
}
