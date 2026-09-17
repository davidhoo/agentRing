import CryptoKit
import Foundation

// Disposable fixtures exercise validation failures; no production signing key or installed app is touched.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let app = root.appendingPathComponent("AgentRing.app")
let fm = FileManager.default
let key = Curve25519.Signing.PrivateKey()
let archive = Data("signed release fixture".utf8)
let signature = try key.signature(for: archive).base64EncodedString()
for path in ["Contents/MacOS/AgentRing", "Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"] {
    let url = app.appendingPathComponent(path)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
let plist: [String: Any] = [
    "CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "1.2.3", "CFBundleExecutable": "AgentRing",
    "SUPublicEDKey": key.publicKey.rawRepresentation.base64EncodedString(),
    "SUEnableInstallerLauncherService": true, "SUEnableDownloaderService": false,
    "SUVerifyUpdateBeforeExtraction": true, "SURequireSignedFeed": true
]
try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
try archive.write(to: root.appendingPathComponent("release.dmg"))
try Data("tampered release bytes".utf8).write(to: root.appendingPathComponent("tampered.dmg"))
let xml = """
<?xml version="1.0"?><rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
<sparkle:version>1.2.3</sparkle:version><enclosure url="https://example.com/release.dmg" length="\(archive.count)" sparkle:edSignature="\(signature)"/>
</item></channel></rss>
"""
try Data(xml.utf8).write(to: root.appendingPathComponent("appcast.xml"))
let wrongSignature = try Curve25519.Signing.PrivateKey().signature(for: archive).base64EncodedString()
try Data(xml.replacingOccurrences(of: signature, with: wrongSignature).utf8).write(to: root.appendingPathComponent("wrong-key.xml"))
try Data(xml.replacingOccurrences(of: "sparkle:edSignature=\"\(signature)\"", with: "").utf8).write(to: root.appendingPathComponent("unsigned.xml"))
