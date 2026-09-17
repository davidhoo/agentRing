import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
if CommandLine.arguments[2] == "tampered-feed" {
    let url = root.appendingPathComponent("appcast.xml")
    let contents = try String(contentsOf: url, encoding: .utf8)
    try contents.replacingOccurrences(of: "2.0.0", with: "3.0.0").write(to: url, atomically: true, encoding: .utf8)
} else {
    let url = root.appendingPathComponent("update.dmg")
    var contents = try Data(contentsOf: url)
    contents[contents.count / 2] ^= 0x01 // Preserve length so verification cannot pass based on size alone.
    try contents.write(to: url)
}
