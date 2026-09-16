//
//  AboutView.swift
//  Agent Ring
//

import SwiftUI

/// 关于页面
/// 显示应用信息、版本号和 fork 说明
struct AboutView: View {
    @ObservedObject private var updateManager = GitHubUpdateManager.shared

    /// 从 Bundle 中读取应用版本号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标（不使用template模式）
            if let icon = ImageHelper.createAppIcon(size: 100) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(radius: 5)
            }
            
            // 应用名称和版本
            VStack(spacing: 6) {
                Text(L.App.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(L.SettingsAbout.version(appVersion))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    updateManager.checkForUpdates(isUserInitiated: true)
                }) {
                    if updateManager.isChecking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text(L.SettingsUpdate.checking)
                        }
                    } else {
                        Text(L.SettingsUpdate.checkNow)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(updateManager.isChecking || updateManager.isDownloading)
                .padding(.top, 4)
            }
            
            Divider()
                .padding(.horizontal, 60)
            
            // 信息列表
            VStack(alignment: .leading, spacing: 12) {
                AboutInfoRow(icon: "doc.text", title: L.SettingsAbout.license, value: L.SettingsAbout.licenseValue)
                AboutInfoRow(icon: "arrow.triangle.branch", title: "Fork", value: "Forked from f-is-h/Usage4Claude")
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
