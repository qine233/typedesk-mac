#!/bin/zsh
set -e
cd "$(dirname "$0")/.."

swift build -c release

APP="build/InkDesk.app"
BIN=".build/arm64-apple-macosx/release/InkDesk"
[ -f "$BIN" ] || BIN=".build/debug/InkDesk"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/InkDesk"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>InkDesk</string>
    <key>CFBundleDisplayName</key><string>墨桌</string>
    <key>CFBundleIdentifier</key><string>work.zhouzhou.inkdesk</string>
    <key>CFBundleExecutable</key><string>InkDesk</string>
    <key>CFBundleVersion</key><string>0.2.0</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHumanReadableCopyright</key><string>© zhouzhou.work</string>
</dict>
</plist>
EOF

codesign --force --deep -s - "$APP" 2>/dev/null || true
echo "已生成 $APP"
[ "$1" = "--open" ] && open "$APP"
exit 0
