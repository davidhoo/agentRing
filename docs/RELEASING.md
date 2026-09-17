# 发布指南

面向仓库维护者：如何用 GitHub Actions 编译并发布 `AgentRing.app`。

## 工作流

| 文件 | 触发 | 作用 |
| --- | --- | --- |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | push / PR 到 `main` | Debug 编译和发布工具负例测试 |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | 推送 `v*` 标签 | Release 编译 → ad-hoc 签名 → DMG + EdDSA appcast → 验证 → GitHub Release |

首次发布前，必须完成 [Sparkle 密钥与 GitHub Actions 配置](auto-update.md)。不需要 Apple 开发者账号。

## 发布新版本

1. 确认 `main` 上 CI 通过
2. 打标签并推送：

```bash
git tag v0.1.6
git push origin v0.1.6
```

3. 在 [Actions](https://github.com/haorui-lab/agentRing/actions) 查看 **Release** 工作流
4. 完成后到 [Releases](https://github.com/haorui-lab/agentRing/releases) 查看 DMG 和 `appcast.xml`。版本号须高于最新公开版本。

## 试打包（不创建 Release）

在 Actions 页面手动运行 **Release** 工作流，保持 `dry_run` 开启（默认）。它仍要求有效的生产签名配置，但仅上传 artifact，不公开 Release。

## 签名说明

当前 Release 构建使用 ad-hoc 签名（与本地 `CODE_SIGN_IDENTITY="-"` 一致），**未做 Apple 公证**。

应用内更新（`AppUpdateManager` + Sparkle 2）会：

1. 获取并验证已签名的 appcast
2. 用户确认后下载 DMG，在解包前验证 EdDSA 签名
3. 通过沙盒外的 Installer XPC 安装并重新打开 App

旧版用户手动覆盖安装首个 Sparkle 版本一次。正式 Release 不上传 ZIP，避免仍在使用旧版的用户误入旧 shell 安装器。

首次手动打开未经公证的 App 仍可能需要「隐私与安全性 → 仍要打开」。生产私钥务必备份；不要在后续版本中重新生成或替换它。

## 版本号

应用版本来自 Xcode 工程中的 `MARKETING_VERSION`（当前见 `AgentRing.xcodeproj`）。发版前请确认版本号已更新。
