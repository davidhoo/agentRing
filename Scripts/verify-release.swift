#!/usr/bin/env swift
import CryptoKit
import Foundation

// Validate the actual built app and appcast, including Ed25519 verification using the EMBEDDED public key.
// This catches a missing/wrong signing secret even when generate_appcast exits successfully.
final class Appcast: NSObject, XMLParserDelegate {
    var elements: [String] = []
    var textByElement: [String: String] = [:]
    var enclosures: [[String: String]] = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        elements.append(elementName)
        if elementName == "enclosure" { enclosures.append(attributes) }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let name = elements.last { textByElement[name, default: ""] += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) { elements.removeLast() }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "ReleaseValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

do {
    let args = CommandLine.arguments
    try require(args.count == 3 || args.count == 6, "Usage: verify-release.swift APP VERSION [APPCAST ARCHIVE DOWNLOAD-URL]")
    let app = URL(fileURLWithPath: args[1])
    let plistData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
    guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { fatalError("Invalid Info.plist") }
    for field in ["CFBundleShortVersionString", "CFBundleVersion"] {
        try require(plist[field] as? String == args[2], "\(field) must match version \(args[2])")
    }
    guard let publicText = plist["SUPublicEDKey"] as? String, let publicData = Data(base64Encoded: publicText), publicData.count == 32 else {
        throw NSError(domain: "ReleaseValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid SUPublicEDKey"])
    }
    for key in ["SUEnableInstallerLauncherService", "SUVerifyUpdateBeforeExtraction", "SURequireSignedFeed"] {
        try require(plist[key] as? Bool == true, "\(key) must be enabled")
    }
    try require(plist["SUEnableDownloaderService"] as? Bool == false, "Downloader service must be disabled")
    let fm = FileManager.default
    for relative in ["Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer", "Contents/MacOS/\(plist["CFBundleExecutable"] as? String ?? "AgentRing")"] {
        try require(fm.isExecutableFile(atPath: app.appendingPathComponent(relative).path), "Missing executable: \(relative)")
    }
    if args.count == 6 {
        let parser = XMLParser(data: try Data(contentsOf: URL(fileURLWithPath: args[3])))
        let feed = Appcast()
        parser.delegate = feed
        try require(parser.parse(), "Invalid appcast XML")
        try require(feed.enclosures.count == 1, "Expected exactly one full update in appcast")
        let enclosure = feed.enclosures[0]
        try require(feed.textByElement["sparkle:version"]?.trimmingCharacters(in: .whitespacesAndNewlines) == args[2], "Appcast build version mismatch")
        try require(enclosure["url"] == args[5], "Appcast download URL mismatch")
        let archive = try Data(contentsOf: URL(fileURLWithPath: args[4]))
        try require(enclosure["length"] == String(archive.count), "Archive size mismatch")
        guard let signatureText = enclosure["sparkle:edSignature"], let signature = Data(base64Encoded: signatureText) else {
            throw NSError(domain: "ReleaseValidation", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing EdDSA signature"])
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
        try require(publicKey.isValidSignature(signature, for: archive), "EdDSA signature does not match the embedded public key")
    }
    print("Release validation passed: \(args[2])")
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
