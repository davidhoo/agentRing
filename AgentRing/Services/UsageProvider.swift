//
//  UsageProvider.swift
//  Agent Ring
//

import Foundation

protocol UsageProvider: AnyObject {
    var providerType: ProviderType { get }
    func cancelAllRequests()
}
