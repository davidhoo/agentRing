# Agent Ring

macOS 菜单栏上的 AI 用量环形监视器。一眼看清 Codex、Cursor、Antigravity 还剩多少额度。

正式名称：**Agent Ring**  
仓库名：`agentRing`  
App 产物：`AgentRing.app`

## 它做什么

- 住在菜单栏，点击展开用量圆环与明细
- 同时跟踪 Codex、Cursor、Antigravity（可按需开关）
- 多账户切换、登录、本地凭证探测
- 智能刷新：用量在动就勤刷新，闲下来就放慢

## 设计原则

- 贴近 macOS 原生系统设置观感
- 外观与时间格式一律跟随系统
- 界面语言仅支持简体中文与 English（跟系统；对不上就用 English）
- 交互尽量短：数据面板的 `…` 直接打开设置

## 系统要求

- macOS 13.0+
- Xcode 15+（建议使用当前正式版 Xcode）
- Apple Silicon 或 Intel

## 构建

```bash
git clone https://github.com/haorui-lab/agentRing.git
cd agentRing
open AgentRing.xcodeproj
```

在 Xcode 中选择 scheme **AgentRing**，然后 Run。

或命令行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AgentRing.xcodeproj -scheme AgentRing \
  -configuration Release -derivedDataPath /tmp/AgentRing-dd build
```

产物位于 DerivedData 的 `Build/Products/.../AgentRing.app`。

## 开源协议

本项目以 [MIT License](LICENSE) 发布。

基于 [f-is-h/Usage4Claude](https://github.com/f-is-h/Usage4Claude) 分支演进，上游仍适用其 MIT 许可，致谢原作者。

## 说明

- Bundle Identifier 仍为 `app.agentsring.AgentsRing`，用于兼容已有钥匙串账号。对外显示名始终是 **Agent Ring**。
- `build/`、DerivedData、本地工具目录不进仓库。
