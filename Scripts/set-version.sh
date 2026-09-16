#!/bin/bash
# 设置 App 版本号：同步修改 Xcode 项目中 Debug/Release 两处 MARKETING_VERSION。
# 用法：./Scripts/set-version.sh 0.1.3
# 发版流程：运行本脚本 → commit → 打 tag v0.1.3 并推送，CI 会校验两者一致后自动发布 Release。

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "用法: $0 <版本号>  (例: $0 0.1.3)"
    exit 1
fi

NEW_VERSION="$1"

# 简单校验格式：x.y.z 形式（允许多位数字）
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误: 版本号需为 x.y.z 格式，收到 '$NEW_VERSION'"
    exit 1
fi

PROJECT="AgentRing.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJECT" ]]; then
    echo "错误: 找不到 $PROJECT，请在仓库根目录运行"
    exit 1
fi

COUNT=$(grep -c "MARKETING_VERSION = " "$PROJECT" || true)
if [[ "$COUNT" -eq 0 ]]; then
    echo "错误: $PROJECT 中未找到 MARKETING_VERSION"
    exit 1
fi

# 兼容 macOS(BSD sed) 与 Linux(GNU sed) 的就地替换
if sed --version >/dev/null 2>&1; then
    # GNU sed
    sed -i "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${NEW_VERSION};/g" "$PROJECT"
else
    # BSD sed (macOS)
    sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${NEW_VERSION};/g" "$PROJECT"
fi

echo "已将 $PROJECT 中 ${COUNT} 处 MARKETING_VERSION 设为 ${NEW_VERSION}"
echo "下一步: git add -A && git commit -m 'chore: bump version to ${NEW_VERSION}' && git tag v${NEW_VERSION} && git push --follow-tags"
