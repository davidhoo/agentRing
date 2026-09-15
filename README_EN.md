# Agent Ring

[简体中文](README.md) · English

<p align="center">
  <img src="AgentRing/Resources/Assets.xcassets/AppIcon.appiconset/256.png" width="128" alt="Agent Ring icon" />
</p>

<p align="center">
  <strong>AI usage rings in your macOS menu bar</strong><br />
  See remaining Codex, Cursor, and Antigravity quota at a glance.
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

Display name: **Agent Ring** · Repo: `agentRing` · Binary: `AgentRing.app`

## Download (end users)

1. Open [Latest Release](https://github.com/haorui-lab/agentRing/releases/latest)
2. Download `AgentRing-*-macos.zip`
3. Unzip and drag `AgentRing.app` into Applications
4. If macOS blocks it: right-click → **Open** → **Open Anyway**

> Public builds are **ad-hoc signed**, not Apple-notarized yet. That is intentional honesty for this stage. Developer ID + notarization can be added later.

No release yet? Use the local run steps below, or push a `v*` tag and let GitHub Actions publish one.

## Screenshots

| Menu bar popover | General settings | Auth settings |
| --- | --- | --- |
| ![popover placeholder](AgentRing/Resources/Assets.xcassets/AppIcon.appiconset/128.png) | ![settings placeholder](AgentRing/Resources/Assets.xcassets/AppIcon.appiconset/128.png) | ![auth placeholder](AgentRing/Resources/Assets.xcassets/AppIcon.appiconset/128.png) |

Drop real captures into [`docs/screenshots/`](docs/screenshots/README.md) and update the table. Until then we only show the app icon — no fake UI mockups.

## Highlights

- **Three providers, one glance**: Codex / Cursor / Antigravity rings
- **Native settings feel**: sidebar + segmented auth, System Settings vibe
- **Follows the system**: appearance and clock; UI languages: Simplified Chinese / English
- **Multi-account**: login, switch, aliases; Antigravity uses local credential discovery
- **Smart refresh**: faster when usage moves, slower when idle
- **Short path**: popover `…` opens Settings directly

## Run locally

### Option A: Xcode

```bash
git clone https://github.com/haorui-lab/agentRing.git
cd agentRing
open AgentRing.xcodeproj
```

Select scheme **AgentRing**, press `⌘R`. Quit any older instance first.

### Option B: CLI

```bash
xcodebuild -project AgentRing.xcodeproj -scheme AgentRing \
  -configuration Debug -derivedDataPath ./build-temp build \
  && open ./build-temp/Build/Products/Debug/AgentRing.app
```

## Automatic packaging on GitHub

| Workflow | Trigger | What it does |
| --- | --- | --- |
| [`ci.yml`](.github/workflows/ci.yml) | push / PR to `main` | Cloud build check |
| [`release.yml`](.github/workflows/release.yml) | push `v*` tag | Release zip on GitHub Releases |

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Requirements

- macOS 13.0+
- Xcode 15+ for development builds
- Apple Silicon or Intel

## License

[MIT](LICENSE). Forked from [f-is-h/Usage4Claude](https://github.com/f-is-h/Usage4Claude) — thanks to the upstream author.

## Notes

- Bundle ID stays `app.agentsring.AgentsRing` for Keychain continuity; the display name is always **Agent Ring**.
- Local build folders are gitignored.
