#!/bin/bash
# Cài đặt NTFS Menu v1.1: Homebrew (nếu thiếu), macFUSE, ntfs-3g,
# rồi chép app ĐÃ BUILD SẴN (nằm cạnh file này trong DMG) vào /Applications.
# Không cần Xcode Command Line Tools, không build lại trên máy anh.
# Chạy bằng cách double-click file "Cài đặt NTFS Menu.command" trong DMG.
# Yêu cầu: mạng internet, mật khẩu quản trị của máy (khi được hỏi).
cd "$(dirname "$0")"
APP_NAME="NTFS Menu"
echo "=== NTFS Menu — Cài đặt (v1.1 · 05/11/2026) ==="
echo ""
# 1) Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "[1/4] Chưa có Homebrew, đang cài (sẽ hỏi mật khẩu máy)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
fi
command -v brew >/dev/null 2>&1 || { echo "LỖI: chưa cài được Homebrew."; exit 1; }
echo "[1/4] Đã có Homebrew."
# 2) macFUSE
if brew list --cask macfuse >/dev/null 2>&1; then
  echo "[2/4] macFUSE đã cài."
else
  echo "[2/4] Đang cài macFUSE (sẽ hỏi mật khẩu máy)..."
  brew install --cask macfuse
fi
# 3) ntfs-3g
brew tap gromgit/fuse 2>/dev/null || true
if brew list ntfs-3g-mac >/dev/null 2>&1; then
  echo "[3/4] ntfs-3g đã cài."
else
  echo "[3/4] Đang cài ntfs-3g..."
  brew install ntfs-3g-mac
fi
NTFS_BIN=""
for p in /opt/homebrew/bin/ntfs-3g /usr/local/bin/ntfs-3g; do
  if [ -x "$p" ]; then NTFS_BIN="$p"; break; fi
done
if [ -z "$NTFS_BIN" ]; then
  echo "LỖI: không tìm thấy ntfs-3g sau khi cài. Chạy lại file này hoặc xem HUONG-DAN."
  exit 1
fi
echo "Đã thấy ntfs-3g tại $NTFS_BIN."
# 4) Chép app build sẵn vào /Applications
if [ ! -d "$APP_NAME.app" ]; then
  echo "LỖI: không thấy $APP_NAME.app cạnh file cài đặt. Mở lại file DMG rồi chạy setup trong đó."
  exit 1
fi
echo "[4/4] Đang chép $APP_NAME vào /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_NAME.app" /Applications/
# Gỡ cờ kiểm dịch trên app của chính mình để mở thẳng (không cần chuột phải -> Mở).
xattr -cr "/Applications/$APP_NAME.app" 2>/dev/null || true
echo ""
echo "=== CÀI XONG PHẦN MỀM ==="
echo "Còn 2 bước cần anh tự làm trên máy (macOS bắt buộc):"
echo "  1) Vào Cài đặt hệ thống -> Cài đặt chung -> Mục đăng nhập & Tiện ích mở rộng"
echo "     -> Tiện ích mở rộng hệ thống tập tin -> bật macFUSE (nếu máy hỏi)."
echo "  2) Khởi động lại máy nếu máy yêu cầu."
echo "Sau đó mở app NTFS Menu từ Applications."
echo "TEST TRƯỚC TRÊN Ổ TRỐNG, đừng test thẳng lên ổ footage. Xem HUONG-DAN-CAI-DAT-VA-TEST.md."
