import Foundation

do {
    guard CommandLine.arguments.count == 3,
          let previous = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as? [String: Any],
          let tag = previous["tag_name"] as? String else {
        throw NSError(domain: "Release", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read previous release"])
    }
    let version = CommandLine.arguments[2]
    let oldVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    guard oldVersion.compare(version, options: .numeric) == .orderedAscending else {
        throw NSError(domain: "Release", code: 2, userInfo: [NSLocalizedDescriptionKey: "Refusing to publish \(version): latest is already \(tag). Use a newer version."])
    }
    print("Release version increases: \(tag) -> \(version)")
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
