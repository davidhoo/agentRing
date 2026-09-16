# Agent Ring

[English](README_EN.md) · 简体中文

<p align="center">
  <img src="AgentRing/Resources/Assets.xcassets/AppIcon.appiconset/256.png" width="128" alt="Agent Ring icon" />
</p>

<p align="center">
  <strong>macOS 菜单栏上的 AI 用量环形监视器</strong><br />
  一眼看清 Codex、Cursor、Antigravity 还剩多少额度。
</p>

<p align="center">
  <a href="https://github.com/haorui-lab/agentRing/releases/latest"><img alt="Download" src="https://img.shields.io/badge/download-latest%20release-0A84FF?style=for-the-badge" /></a>
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black" />
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-green" />
  <img alt="Latest release" src="https://img.shields.io/github/v/release/haorui-lab/agentRing?include_prereleases" />
  <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/haorui-lab/agentRing/ci.yml?branch=main&label=CI" />
</p>

## 下载

1. 打开 [Latest Release](https://github.com/haorui-lab/agentRing/releases/latest)
2. 下载 `AgentRing-*-macos.dmg`（推荐）或 `AgentRing-*-macos.zip`
3. 双击打开 DMG，将 `Agent Ring` 拖入「应用程序」（或解压 zip 使用）
4. 若系统提示无法验证开发者：右键 App → **打开** → **仍要打开**

> 当前公开发布包为 ad-hoc 签名，尚未 Apple 公证。接入 Developer ID 并完成公证后，此步骤将不再需要。

## 功能

- **AI 编程助手额度聚合监控**：菜单栏同屏圆环监视，当前支持：Codex、Cursor、Antigravity
- **原生设置质感**：侧边栏 + 分段认证页
- **跟随系统**：深浅色、时间格式；界面语言为简体中文 / English
- **多账户**：登录、切换、别名；Antigravity 使用本机凭证探测
- **智能刷新**：用量变化时加快，空闲时放慢
- **极简入口**：数据面板 `…` 直接进入设置

## 从源码构建

**要求**：macOS 13+、Xcode 15+

```bash
git clone https://github.com/haorui-lab/agentRing.git
cd agentRing
open AgentRing.xcodeproj
```

在 Xcode 中选择 scheme **AgentRing**，按 `⌘R` 运行。应用图标将出现在菜单栏。

命令行构建：

```bash
xcodebuild -project AgentRing.xcodeproj -scheme AgentRing \
  -configuration Debug -derivedDataPath ./build-temp build \
  && open ./build-temp/Build/Products/Debug/AgentRing.app
```

## 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel

## 开源协议

[MIT License](LICENSE)

基于 [f-is-h/Usage4Claude](https://github.com/f-is-h/Usage4Claude) 分支演进，致谢上游作者。

## 说明

- Bundle ID 为 `app.agentring.AgentRing`；首次升级会从旧 ID `app.agentsring.AgentsRing` 迁移钥匙串与偏好设置。对外显示名为 **Agent Ring**。
- 维护者发布流程见 [`docs/RELEASING.md`](docs/RELEASING.md)。
