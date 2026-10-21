#!/bin/zsh
# 把当前 tag + 刚编译出的 dmg 发成 GitHub Release
# 令牌来源：环境变量 NLTYPEDESK_GH_TOKEN，或钥匙串里的 github.token（不进仓库、不打日志）
set -e
cd "$(dirname "$0")/.."

REPO="qine233/typedesk-mac"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
          build/NLtypedesk.app/Contents/Info.plist 2>/dev/null || echo "")
[ -n "$VERSION" ] || { echo "找不到 build/NLtypedesk.app，先跑 ./Scripts/make_dmg.sh"; exit 1; }
TAG="${1:-v$VERSION}"
DMG="build/NLtypedesk-$VERSION.dmg"
ASSET="NLtypedesk-$VERSION.dmg"

TOKEN="${NLTYPEDESK_GH_TOKEN:-$(security find-generic-password -s github.token -a qine233 -w 2>/dev/null || true)}"
if [ -z "$TOKEN" ]; then
    echo "没有 GitHub 令牌：export NLTYPEDESK_GH_TOKEN=… 或先存进钥匙串："
    echo "  security add-generic-password -U -a qine233 -s github.token -w '<fine-grained PAT，Contents: Write>'"
    exit 1
fi
[ -f "$DMG" ] || { echo "先跑 ./Scripts/make_dmg.sh 生成 $DMG"; exit 1; }

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
git push -q origin "$TAG" 2>/dev/null || true
BODY=$(git log -1 --pretty=%B "$TAG")

api() { curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

RID=$(api "https://api.github.com/repos/$REPO/releases/tags/$TAG" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("id", ""))')

if [ -n "$RID" ]; then
    payload=$(python3 -c 'import json,sys; print(json.dumps({"name": sys.argv[1], "body": sys.argv[2]}))' "$TAG" "$BODY")
    api -X PATCH "https://api.github.com/repos/$REPO/releases/$RID" -d "$payload" >/dev/null
    for AID in $(api "https://api.github.com/repos/$REPO/releases/$RID/assets" | python3 -c '
import json, sys
for a in json.load(sys.stdin):
    print(a["id"], a["name"])' | awk -v n="$ASSET" '$2==n {print $1}'); do
        curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" \
            "https://api.github.com/repos/$REPO/releases/assets/$AID" >/dev/null
    done
else
    payload=$(python3 -c '
import json, sys
print(json.dumps({"tag_name": sys.argv[1], "name": sys.argv[1], "body": sys.argv[2],
                  "draft": False, "prerelease": True}))' "$TAG" "$BODY")
    RID=$(api -X POST "https://api.github.com/repos/$REPO/releases" -d "$payload" | python3 -c '
import json, sys
print(json.load(sys.stdin)["id"])')
fi

UP=$(curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/x-apple-diskimage" \
    --data-binary "@$DMG" \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$ASSET")
DL=$(echo "$UP" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("browser_download_url") or ("上传失败: " + str(d)[:300]))')

echo "Release: https://github.com/$REPO/releases/tag/$TAG"
echo "DMG: $DL"
