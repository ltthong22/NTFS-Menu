#!/bin/bash
# Build app "NTFS Menu" từ source Swift, cài vào ~/Applications, tạo .dmg trên Desktop.
# Chạy trên Mac (Apple Silicon, macOS 12+). Cần Xcode Command Line Tools.
set -e
cd "$(dirname "$0")/.."
APP_NAME="NTFS Menu"
SRC="app/main.swift"
PLIST="app/Info.plist"
BUILD_DIR="$(mktemp -d /tmp/ntfs-menu-build-XXXXXX)"
APP="$BUILD_DIR/$APP_NAME.app"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "CHƯA CÓ swiftc. Chạy: xcode-select --install, rồi chạy lại script này."
  exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$APP/Contents/MacOS/$APP_NAME" "$SRC" -framework AppKit -framework Foundation
cp "$PLIST" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "Cảnh báo: ký ad-hoc thất bại, vẫn tiếp tục (lần mở đầu cần chuột phải -> Mở)."
rm -rf ~/Applications/"$APP_NAME.app"
cp -R "$APP" ~/Applications/
DMG=~/Desktop/"$APP_NAME v1.1.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null
echo "XONG: đã cài $APP_NAME vào ~/Applications"
echo "File .dmg để cài lại/chia sẻ: $DMG"
echo "Mở app lần đầu: chuột phải vào app -> Mở (do app chưa ký Developer ID)."
rm -rf "$BUILD_DIR"
