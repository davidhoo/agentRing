import Foundation

let args = CommandLine.arguments
let root = URL(fileURLWithPath: args[1])
let identifier = args[2]
let publicKey = args[3]
let port = args[4]
let fm = FileManager.default
let entitlements: [String: Any] = [
    "com.apple.security.app-sandbox": true,
    "com.apple.security.network.client": true,
    "com.apple.security.temporary-exception.mach-lookup.global-name": [identifier + "-spks", identifier + "-spki"]
]
try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0).write(to: root.appendingPathComponent("host.entitlements"))
for (folder, version) in [("installed", "1.0.0"), ("payload", "2.0.0")] {
    let app = root.appendingPathComponent(folder + "/AgentRing.app")
    try fm.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    try fm.createDirectory(at: app.appendingPathComponent("Contents/Frameworks"), withIntermediateDirectories: true)
    var plist: [String: Any] = [
        "CFBundleIdentifier": identifier, "CFBundleName": "AgentRing Update Test", "CFBundleExecutable": "Smoke",
        "CFBundlePackageType": "APPL", "CFBundleVersion": version, "CFBundleShortVersionString": version,
        "LSUIElement": true, "LSMinimumSystemVersion": "13.0", "SUPublicEDKey": publicKey,
        "SUFeedURL": "http://127.0.0.1:\(port)/appcast.xml",
        "SUEnableInstallerLauncherService": true, "SUEnableDownloaderService": false,
        "SUVerifyUpdateBeforeExtraction": true, "SURequireSignedFeed": true,
        "SUEnableAutomaticChecks": false, "SUAutomaticallyUpdate": false
    ]
    // Loopback HTTP is allowed only in this isolated fixture, never in the production app.
    plist["NSAppTransportSecurity"] = ["NSAllowsArbitraryLoads": true]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
}
