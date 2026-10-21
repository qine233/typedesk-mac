#!/bin/zsh
# 编译 → 打包 .app → 产出可分发的 dmg（每次发版都用它）
set -e
cd "$(dirname "$0")/.."

# 本机装了完整 Xcode 但未同意许可时，命令行工具是唯一可用工具链
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"

./Scripts/make_app.sh

APP="build/NLtypedesk.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="build/NLtypedesk-$VERSION.dmg"
STAGE="build/dmg-stage"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet \
    -volname "NLtypedesk $VERSION" \
    -srcfolder "$STAGE" \
    -format UDZO \
    -ov "$DMG"

rm -rf "$STAGE"
echo "已生成 $DMG（$(du -h "$DMG" | cut -f1)）"
[ "$1" = "--open" ] && open "$DMG"
exit 0
