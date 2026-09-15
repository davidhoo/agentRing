//
//  UsageProvider.swift
//  agentsRing
//

import Foundation

protocol UsageProvider: AnyObject {
    var providerType: ProviderType { get }
    func cancelAllRequests()
}
