#!/usr/bin/env swift
import Foundation

// Usage:
//   swift Scripts/generate-changelog.swift [<previous_tag>] [<current_ref>] [<notes_file>] [<repo>]
//
// Generates a categorized Markdown changelog comparing <previous_tag> and <current_ref>.

func runGit(_ args: [String]) -> String {
    let pipe = Pipe()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    proc.arguments = args
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return ""
    }
}

/// git log 失败（如 tag 不存在）必须让脚本以非零退出，
/// 否则会静默产出一份没有变更记录的空 changelog 直接发布出去。
func runGitOrDie(_ args: [String], _ context: String) -> String {
    let pipe = Pipe()
    let errPipe = Pipe()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    proc.arguments = args
    proc.standardOutput = pipe
    proc.standardError = errPipe
    do {
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard proc.terminationStatus == 0 else {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            FileHandle.standardError.write(Data(("generate-changelog: \(context) failed: \(err)\n").utf8))
            exit(1)
        }
        return output
    } catch {
        FileHandle.standardError.write(Data(("generate-changelog: \(context) failed: \(error.localizedDescription)\n").utf8))
        exit(1)
    }
}

let args = CommandLine.arguments

// 1. Current ref (default: HEAD)
let currentRef = args.count > 2 && !args[2].isEmpty ? args[2] : "HEAD"

// 2. Previous tag (if not specified, auto-detect using git describe)
let previousTag: String
if args.count > 1 && !args[1].isEmpty {
    previousTag = args[1]
} else {
    // Try to find the tag immediately preceding currentRef
    let detected = runGit(["describe", "--tags", "--abbrev=0", "\(currentRef)^"])
    previousTag = detected.isEmpty ? runGit(["describe", "--tags", "--abbrev=0"]) : detected
}

// 3. Notes template file
let notesFilePath = args.count > 3 && !args[3].isEmpty ? args[3] : "docs/release-installation.md"

// 4. Repository slug (owner/repo)
let repoSlug: String
if args.count > 4 && !args[4].isEmpty {
    repoSlug = args[4]
} else if let envRepo = ProcessInfo.processInfo.environment["GITHUB_REPOSITORY"], !envRepo.isEmpty {
    repoSlug = envRepo
} else {
    let remoteUrl = runGit(["config", "--get", "remote.origin.url"])
    // 只认真正的 GitHub remote（ssh 的 git@github.com: 或 https 的 https://github.com/），
    // 避免 file:///.../github.com/... 这类本地路径被误当成仓库 slug
    if let match = remoteUrl.range(of: "github\\.com[:/]([^/]+/[^/]+?)(?:\\.git)?$", options: .regularExpression),
       remoteUrl.hasSuffix(".git") || remoteUrl.contains("@github.com") || remoteUrl.contains("https://github.com") {
        let matchedString = String(remoteUrl[match])
        let cleaned = matchedString
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: "github.com:", with: "")
            .replacingOccurrences(of: "github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")
        repoSlug = cleaned
    } else {
        repoSlug = "haorui-lab/agentRing"
    }
}

// Extract git commits between previousTag and currentRef
let gitLogOutput: String
if previousTag.isEmpty {
    // If no previous tag found, log all commits up to currentRef
    gitLogOutput = runGitOrDie(["log", currentRef, "--pretty=format:%h%x09%s%x09%an"], "git log \(currentRef)")
} else {
    gitLogOutput = runGitOrDie(["log", "\(previousTag)..\(currentRef)", "--pretty=format:%h%x09%s%x09%an"], "git log \(previousTag)..\(currentRef)")
}

var feats: [String] = []
var fixes: [String] = []
var perfs: [String] = []
var refactors: [String] = []
var docs: [String] = []
var chores: [String] = []
var others: [String] = []

let lines = gitLogOutput.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

for line in lines {
    let parts = line.components(separatedBy: "\t")
    guard parts.count >= 2 else { continue }
    let hash = parts[0]
    let subject = parts[1]
    
    // Skip version bump commits (e.g. chore(release): v0.1.8) to keep changelog noise-free
    let lower = subject.lowercased()
    if lower.starts(with: "chore(release):") || lower.starts(with: "chore: bump version") || lower.starts(with: "chore(release) ") {
        continue
    }
    
    let commitLink = "[\(hash)](https://github.com/\(repoSlug)/commit/\(hash))"
    let item = "- \(subject) (\(commitLink))"
    
    if lower.starts(with: "feat") {
        feats.append(item)
    } else if lower.starts(with: "fix") {
        fixes.append(item)
    } else if lower.starts(with: "perf") {
        perfs.append(item)
    } else if lower.starts(with: "refactor") {
        refactors.append(item)
    } else if lower.starts(with: "docs") {
        docs.append(item)
    } else if lower.starts(with: "chore") || lower.starts(with: "ci") || lower.starts(with: "build") || lower.starts(with: "test") {
        chores.append(item)
    } else {
        others.append(item)
    }
}

var result = ""

let hasChanges = !feats.isEmpty || !fixes.isEmpty || !perfs.isEmpty || !refactors.isEmpty || !docs.isEmpty || !chores.isEmpty || !others.isEmpty

if hasChanges {
    result += "## 变更日志 (What's Changed)\n\n"
    if !feats.isEmpty {
        result += "### 🚀 新特性 / Features\n" + feats.joined(separator: "\n") + "\n\n"
    }
    if !fixes.isEmpty {
        result += "### 🐛 缺陷修复 / Bug Fixes\n" + fixes.joined(separator: "\n") + "\n\n"
    }
    if !perfs.isEmpty {
        result += "### ⚡️ 性能优化 / Performance\n" + perfs.joined(separator: "\n") + "\n\n"
    }
    if !refactors.isEmpty {
        result += "### ♻️ 代码重构 / Refactoring\n" + refactors.joined(separator: "\n") + "\n\n"
    }
    if !docs.isEmpty {
        result += "### 📝 文档更新 / Documentation\n" + docs.joined(separator: "\n") + "\n\n"
    }
    if !chores.isEmpty {
        result += "### 🛠 构建与工程 / Engineering & Chores\n" + chores.joined(separator: "\n") + "\n\n"
    }
    if !others.isEmpty {
        result += "### 📌 其他改动 / Other Changes\n" + others.joined(separator: "\n") + "\n\n"
    }
}

if !previousTag.isEmpty {
    result += "**Full Changelog**: https://github.com/\(repoSlug)/compare/\(previousTag)...\(currentRef)\n\n"
}

// Append installation and Sparkle instructions if template exists
if FileManager.default.fileExists(atPath: notesFilePath) {
    if let notesContent = try? String(contentsOfFile: notesFilePath, encoding: .utf8) {
        result += "---\n\n### 📦 安装与升级说明\n\n" + notesContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}

// Output UTF-8 string to standard output
if let outData = result.data(using: .utf8) {
    FileHandle.standardOutput.write(outData)
}
