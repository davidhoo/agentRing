//
//  WebLoginWindowManager.swift
//  Agent Ring
//

import AppKit
import SwiftUI

/// Web 登录窗口管理单例
/// 负责创建、显示和关闭登录窗口
/// 登录 WebView 使用 nonPersistent 数据存储，确保多账号添加时不会因已有 session 而 auto-SSO
final class WebLoginWindowManager {
    static let shared = WebLoginWindowManager()

    private var codexLoginWindow: NSWindow?

    private var cursorLoginWindow: NSWindow?

    private init() {}

    // MARK: - Codex Login

    func showCodexLoginWindow(onAccountCreated: ((Account) -> Void)? = nil) {
        if let window = codexLoginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 改用 OAuth（系统浏览器）登录，替代内嵌 WKWebView，
        // 以支持 Google / 微软 / 企业 SSO / passkey 等在嵌入式 WebView 中受限的登录方式
        let loginView = CodexOAuthLoginView(onAccountCreated: onAccountCreated)
        let window = makeCompactWindow(title: L.WebLogin.codexWindowTitle, content: loginView, width: 440, height: 300)
        self.codexLoginWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.codexLoginWindow = nil }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeCodexLoginWindow() {
        codexLoginWindow?.close()
        codexLoginWindow = nil
    }

    // MARK: - Cursor Login

    func showCursorLoginWindow(onAccountCreated: ((Account) -> Void)? = nil) {
        if let window = cursorLoginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = CursorWebLoginView(onAccountCreated: onAccountCreated)
        let window = makeBrowserWindow(title: L.WebLogin.cursorWindowTitle, content: loginView, width: 520, height: 680)
        self.cursorLoginWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.cursorLoginWindow = nil }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeCursorLoginWindow() {
        cursorLoginWindow?.close()
        cursorLoginWindow = nil
    }

    // MARK: - Private

    /// 固定尺寸的小窗口（用于 OAuth 进度展示，不可缩放）
    private func makeCompactWindow<V: View>(title: String, content: V, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: content)
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        return window
    }

    /// WKWebView 登录窗口（Cursor cookie 登录）
    private func makeBrowserWindow<V: View>(title: String, content: V, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: content)
        window.title = title
        window.minSize = NSSize(width: 420, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        return window
    }
}
