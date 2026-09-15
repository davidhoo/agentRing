//
//  CursorWebLoginView.swift
//  agentsRing
//

import SwiftUI
import WebKit

struct CursorWebLoginView: View {
    @StateObject private var coordinator = CursorWebLoginCoordinator()
    var onAccountCreated: ((Account) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            CursorWebViewRepresentable(coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if coordinator.loadProgress < 1.0 && coordinator.loadProgress > 0 {
                ProgressView(value: coordinator.loadProgress)
                    .progressViewStyle(.linear)
            }
        }
        .onAppear {
            if let callback = onAccountCreated {
                coordinator.setOnAccountCreated(callback)
            }
            coordinator.loadLoginPage()
        }
        .onDisappear {
            coordinator.cleanup()
        }
        .onChange(of: coordinator.loginState) { newState in
            if case .success = newState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    WebLoginWindowManager.shared.closeCursorLoginWindow()
                }
            }
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        let violet = Color(red: 167/255.0, green: 139/255.0, blue: 250/255.0)

        switch coordinator.loginState {
        case .loading:
            statusRow(icon: "globe", iconColor: violet, text: L.WebLogin.loading, showSpinner: true)
        case .waitingForLogin:
            VStack(alignment: .leading, spacing: 6) {
                statusRow(
                    icon: "person.crop.circle.badge.checkmark",
                    iconColor: .orange,
                    text: L.WebLogin.cursorWaitingForLogin,
                    showSpinner: false
                )
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(L.WebLogin.privacyNotice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .validating:
            statusRow(icon: "checkmark.shield.fill", iconColor: violet, text: L.WebLogin.validating, showSpinner: true)
        case .success(let accountName):
            statusRow(icon: "checkmark.circle.fill", iconColor: .green, text: L.WebLogin.success(accountName), showSpinner: false)
        case .failed(let message):
            statusRow(icon: "exclamationmark.triangle.fill", iconColor: .red, text: message, showSpinner: false)
        }
    }

    private func statusRow(icon: String, iconColor: Color, text: String, showSpinner: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(text)
                .font(.subheadline)
            if showSpinner {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Spacer()
        }
    }
}

struct CursorWebViewRepresentable: NSViewRepresentable {
    let coordinator: CursorWebLoginCoordinator

    func makeNSView(context: Context) -> WKWebView {
        coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
