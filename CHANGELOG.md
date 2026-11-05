# Changelog — NTFS Menu

Quy tắc version (theo yêu cầu của anh): **mọi thứ tạo ra đều hiện version +
ngày ở chỗ dễ thấy; mỗi lần sửa xong là TĂNG version** (menu app, hộp Giới
thiệu, đầu README và hướng dẫn đều phải đổi theo).

## v1.1 · 05/11/2026 — App build sẵn + setup thật

- App ĐÃ BUILD SẴN bằng GitHub Actions (macOS runner): không cần Xcode
  Command Line Tools, không build lại trên máy anh.
- DMG `NTFS-Menu-v1.1.dmg` gồm app build sẵn + `Cài đặt NTFS Menu.command`
  (setup thật: Homebrew → macFUSE → ntfs-3g → chép app vào /Applications,
  gỡ cờ kiểm dịch để mở thẳng) + `Kiểm tra.command` + hướng dẫn.
- Chưa có: tự gắn khi cắm ổ; test thật trên máy Mac (vẫn phải test ổ trống trước).

## v1.0 · 03/11/2026 — Bản đầu tiên

- App menu-bar Swift (AppKit, tiếng Việt): liệt kê ổ NTFS đang cắm
  (tên, dung lượng trống/tổng, trạng thái), gắn để ghi bằng NTFS-3G qua
  macFUSE, gắn lại chỉ đọc, tháo ra, đẩy ổ ra, kiểm tra chỉ đọc
  (ntfsfix --no-action), mở trong Finder.
- Backend FSKit thử trước (`-o backend=fskit`, không cần Recovery /
  Reduced Security), fallback backend kernel nếu FSKit thất bại.
- Không bao giờ tự gắn cờ `force` / `remove_hiberfile` với ổ bẩn/ngủ đông.
- Nhật ký tại `~/Library/Logs/NTFSMenu/ntfs-menu.log`.
- Installer double-click: Homebrew (nếu thiếu) → macFUSE → ntfs-3g →
  build app bằng swiftc → cài vào ~/Applications → tạo .dmg trên Desktop.
- Chưa có: tự gắn khi cắm ổ; bản build sẵn (build ngay trên Mac lúc cài).
