#!/usr/bin/env swift
import CryptoKit
import Foundation

// Read secrets via stdin, never command-line arguments. Prints ONLY the public key.
// generate is for disposable test keys; production keys should live in Sparkle's Keychain account.
do {
    let key: Curve25519.Signing.PrivateKey
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "generate" {
        key = Curve25519.Signing.PrivateKey()
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        // The containing directory must be private (mktemp -d); refuse to overwrite any key.
        try Data(key.rawRepresentation.base64EncodedString().utf8).write(to: url, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    } else if CommandLine.arguments.count == 1 {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let text = String(data: input, encoding: .utf8),
              let bytes = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              bytes.count == 32 else {
            throw NSError(domain: "AgentRingSigning", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected a Sparkle 32-byte base64 Ed25519 seed. Export with generate_keys from Sparkle 2.10.0."])
        }
        key = try Curve25519.Signing.PrivateKey(rawRepresentation: bytes)
    } else {
        throw NSError(domain: "AgentRingSigning", code: 2, userInfo: [NSLocalizedDescriptionKey: "Usage: swift Scripts/sparkle-key.swift < key-file (or: generate TEST-KEY-FILE)"])
    }
    print(key.publicKey.rawRepresentation.base64EncodedString())
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
