---
name: agentring-release
description: >-
  Release a new version of Agent Ring. Use this skill whenever the user asks to release,
  publish, tag, or bump the version of Agent Ring.
---

# Agent Ring Release Workflow

This skill automates the release process for Agent Ring, ensuring version consistency across the Xcode project, Git commits, Git tags, and GitHub Actions Release workflow.

## Pre-requisites

Before executing a release, verify:
1. You are in the repository root directory (`/Users/haorui/Code/github.com/agentRing`).
2. The working directory is completely clean (`git status --porcelain` returns empty).
3. The local `main` branch is up-to-date with `origin/main` (`git pull --ff-only`).
4. The target version is higher than the currently released version (semantic versioning `MAJOR.MINOR.PATCH`, e.g., `0.1.7`). Verify with `gh release view --repo haorui-lab/agentRing --json tagName` — the CI also enforces this via `Scripts/check-release-version.swift` and rejects a version that does not increase.
5. The tag `v<VERSION>` does NOT already exist, neither locally (`git tag -l "v<VERSION>"`) nor remotely (`git ls-remote --tags origin "refs/tags/v<VERSION>"` after `git fetch --tags`).

## Release Procedure

Follow these steps in exact sequence:

### Step 1: Validate Version & Environment
Determine the target version (e.g., `0.1.7`). Confirm the format matches `^[0-9]+\.[0-9]+\.[0-9]+$`.

Check existing tags to avoid collision (both local and remote):
```bash
git fetch --tags
git tag -l "v<VERSION>"
git ls-remote --tags origin "refs/tags/v<VERSION>"
```
If the tag exists, stop and request a new version number from the user.

### Step 2: Preview Changelog
Generate and preview the categorized changelog comparing the previous release tag with the commits to be released:
```bash
PREVIOUS_TAG=$(git describe --tags --abbrev=0)
swift Scripts/generate-changelog.swift "$PREVIOUS_TAG" HEAD
```
Verify that all intended bug fixes, features, and documentation changes are properly reflected, and confirm that version bump noise is excluded.

### Step 3: Bump Xcode Version
Execute the version update script:
```bash
bash Scripts/set-version.sh <VERSION>
```
Verify that `AgentRing.xcodeproj/project.pbxproj` has been updated with the new `MARKETING_VERSION`.

### Step 4: Commit the Release Version
Stage all changed files and create the release commit:
```bash
git add -A
git commit -m "chore(release): v<VERSION>"
```

### Step 5: Push to Main Branch
Push the version bump commit to GitHub:
```bash
git push origin main
```

### Step 6: Create and Push the Release Tag
Create the release tag (lightweight, matching the historical convention of this repository) and push it to trigger the automated Release workflow:
```bash
git tag v<VERSION>
git push origin v<VERSION>
```

### Step 7: Monitor GitHub Actions Workflow
Once the tag is pushed, GitHub Actions automatically executes the `.github/workflows/release.yml` workflow:
- Builds universal binaries for `arm64` and `x86_64`
- Performs ad-hoc nested code signing
- Generates and signs `appcast.xml` with the repository's Sparkle EdDSA private key
- Builds and packages `AgentRing-<VERSION>-macos.dmg`
- Generates categorized release notes via `Scripts/generate-changelog.swift` comparing the previous tag with the new release
- Publishes the final GitHub Release (with DMG, appcast.xml, and the categorized changelog attached)

To monitor progress from terminal:
```bash
gh run list --workflow=Release --limit=1
gh run watch $(gh run list --workflow=Release --limit=1 --json databaseId --jq '.[0].databaseId') --exit-status
```

After the workflow succeeds, confirm the release is public with exactly two assets (DMG and appcast.xml — no ZIP):
```bash
gh release view "v<VERSION>" --repo haorui-lab/agentRing --json assets,tagName --jq '{tag: .tagName, assets: [.assets[].name]}'
```

## Safety Rules
- **Never overwrite existing tags**: Tag immutability guarantees update security.
- **Never publish with dirty working trees**: Only clean, reviewed commits should be tagged.
- **Never skip version bump in pbxproj**: The GitHub workflow verifies that the Git tag version matches `MARKETING_VERSION` in `project.pbxproj`. Mismatched versions will fail the workflow.
- **Never release a version that does not increase**: the workflow fetches the latest public release and refuses to publish a lower or equal version (via `Scripts/check-release-version.swift`). Fix the version instead of force-pushing.
- **Never edit a published release's assets**: the DMG and appcast are EdDSA-signed; any post-publish modification breaks client verification. Ship a new version instead.
