#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$repo_root/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/FinderRight-build.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
cd "$repo_root"

if ! xcodebuild -project FinderRight.xcodeproj -scheme FinderRight -configuration Release \
  -derivedDataPath "$build_root/derived" CODE_SIGNING_ALLOWED=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build > "$build_root/build.log" 2>&1; then
  tail -100 "$build_root/build.log"
  exit 1
fi
app="$build_root/package/FinderRight.app"
mkdir -p "$build_root/package"
ditto --norsrc "$build_root/derived/Build/Products/Release/FinderRight.app" "$app"
# Generated local bundles can inherit File Provider metadata in synced checkouts.
xattr -cr "$app"
codesign --force --sign - --entitlements FinderRightSync/FinderRightSync.entitlements "$app/Contents/PlugIns/FinderRightSync.appex"
codesign --force --sign - --entitlements FinderRight/FinderRight.entitlements "$app"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/FinderRight" -verify_arch arm64 x86_64
lipo "$app/Contents/PlugIns/FinderRightSync.appex/Contents/MacOS/FinderRightSync" -verify_arch arm64 x86_64
zip_name='FinderRight-1.2.0-preview-universal.zip'
ditto -c -k --norsrc --keepParent "$app" "$output_dir/$zip_name"
(cd "$output_dir" && shasum -a 256 "$zip_name" > "$zip_name.sha256")
printf 'Built and verified: %s\n' "$output_dir/$zip_name"
