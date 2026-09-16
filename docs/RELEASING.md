# 发布指南

面向仓库维护者：如何用 GitHub Actions 编译并发布 `AgentRing.app`。

## 工作流

| 文件 | 触发 | 作用 |
| --- | --- | --- |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | push / PR 到 `main` | 云端 Debug 编译，验证能否构建 |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | 推送 `v*` 标签 | Release 编译 → 打 dmg 与 zip → 上传到 GitHub Releases |

## 发布新版本

1. 确认 `main` 上 CI 通过
2. 打标签并推送：

```bash
git tag v0.1.0
git push origin v0.1.0
```

3. 在 [Actions](https://github.com/haorui-lab/agentRing/actions) 查看 **Release** 工作流
4. 完成后到 [Releases](https://github.com/haorui-lab/agentRing/releases) 查看并下载 `AgentRing-*-macos.dmg`（或 `AgentRing-*-macos.zip`）

## 试打包（不创建 Release）

在 Actions 页面手动运行 **Release** 工作流，选择 `workflow_dispatch`。仅上传 artifact，不创建 GitHub Release。

## 签名说明

当前 Release 构建使用 ad-hoc 签名（与本地 `CODE_SIGN_IDENTITY="-"` 一致），**未做 Apple 公证**。

应用内更新（`GitHubUpdateManager` + `AppUpdateInstaller`）会：

1. 优先下载 `*-macos.zip`
2. 清除 `com.apple.quarantine` 隔离属性（避免「无法打开」）
3. 退出当前进程，用 helper 脚本 `ditto` 替换 `/Applications` 中的 App 并自动重新打开

若用户从浏览器手动下载 DMG/ZIP 后仍提示无法打开：右键 App → **打开** → **仍要打开**。

若要无警告安装，需后续接入 Developer ID 证书并完成 notarization，并更新 `release.yml` 中的签名步骤。

## 版本号

应用版本来自 Xcode 工程中的 `MARKETING_VERSION`（当前见 `AgentRing.xcodeproj`）。发版前请确认版本号已更新。
