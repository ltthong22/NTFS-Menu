#!/bin/bash
# Double-click file này để cài đặt NTFS Menu (nó sẽ mở Terminal và chạy cai-dat.sh).
cd "$(dirname "$0")"
bash cai-dat.sh
echo ""
read -p "Nhấn Enter để đóng cửa sổ..."
