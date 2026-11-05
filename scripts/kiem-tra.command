#!/bin/bash
# Double-click file này để kiểm tra nhanh: macFUSE, ntfs-3g, app, ổ NTFS đang cắm.
echo "=== Kiểm tra NTFS Menu (v1.0 · 03/11/2026) ==="
echo ""
echo "-- macFUSE:"
if command -v brew >/dev/null 2>&1; then
  brew list --cask macfuse 2>/dev/null || echo "  (chưa cài macFUSE)"
else
  echo "  (chưa có Homebrew)"
fi
echo ""
echo "-- ntfs-3g:"
ls -l /opt/homebrew/bin/ntfs-3g /usr/local/bin/ntfs-3g 2>/dev/null || echo "  (chưa thấy ntfs-3g)"
echo ""
echo "-- App:"
ls -ld ~/Applications/"NTFS Menu.app" 2>/dev/null || echo "  (chưa có app trong Applications)"
echo ""
echo "-- Ổ NTFS đang cắm:"
diskutil list | grep -i ntfs || echo "  (không thấy ổ NTFS nào)"
echo ""
read -p "Nhấn Enter để đóng cửa sổ..."
