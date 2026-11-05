# NTFS Menu — v1.1 · 05/11/2026

App menu-bar miễn phí cho Mac Apple Silicon: cắm ổ cứng NTFS của Windows vào là
đọc/ghi đầy đủ, bấm một cái là gắn, không cần gõ lệnh Terminal.

## App này KHÔNG phải cái gì

- **Không tự viết driver NTFS mới.** Viết driver ghi NTFS từ số 0 mà sai một chỗ
  là mất dữ liệu. Engine ghi ở đây là **ntfs-3g** (mã nguồn mở, dùng cả chục năm
  trên Linux/macOS), chạy qua **macFUSE**. App chỉ là cái vỏ bấm một cái cho tiện:
  tìm ổ NTFS → tháo mount chỉ đọc của macOS → gắn lại bằng ntfs-3g → tháo/đẩy ổ.
- **Không thay thế Paragon về tốc độ.** NTFS-3G qua FUSE chậm hơn driver thương
  mại chạy sát nhân. Đủ nhanh để chép footage qua lại; dựng 4K trực tiếp trên ổ
  thì nên chép về SSD của Mac rồi dựng.

## Kiến trúc

```
Ổ NTFS (USB) ──> macOS tự gắn CHỈ ĐỌC
      │
      ▼  (bấm "Gắn để ghi" trên menu bar)
App NTFS Menu ──> diskutil unmount ──> ntfs-3g mount tại /Volumes/Tên ổ
      │                    │
      │                    ├─ thử trước: backend FSKit  (-o backend=fskit)
      │                    └─ fallback:  backend kernel (nếu FSKit thất bại)
      ▼
Finder thấy ổ, đọc/ghi bình thường. "Tháo ra" trước khi rút cáp.
```

## Vì sao chọn backend FSKit (và fallback là gì)

- macFUSE 5.x có 2 backend. Backend **FSKit** chạy dưới dạng File System
  Extension trong user space: chỉ cần duyệt trong
  **Cài đặt hệ thống → Cài đặt chung → Mục đăng nhập & Tiện ích mở rộng →
  Tiện ích mở rộng hệ thống tập tin**, **không cần vào Recovery, không cần hạ
  bảo mật (Reduced Security)**. Đây là đường mặc định của app (macOS 26).
- Nếu mount FSKit thất bại (vd: extension chưa được duyệt, hoặc ntfs-3g build
  sẵn không hợp backend này), app tự thử lại bằng backend kernel kiểu cũ.
  Đường này cần duyệt trong **Cài đặt hệ thống → Quyền riêng tư & Bảo mật** và
  khởi động lại; trên Apple Silicon có thể cần bật Reduced Security trong
  Recovery trước. App ghi rõ backend nào đã dùng thành công vào nhật ký.
- App **không bao giờ** tự gắn cờ `force` / `remove_hiberfile`: ổ đang ngủ đông
  (Windows Fast Startup) hoặc bẩn thì ntfs-3g từ chối gắn ghi — đó là lưới an
  toàn, không phải lỗi. Cách sửa: cắm lại vào Windows, eject đúng cách, rồi thử lại.

## File trong dự án

| File | Để làm gì |
|---|---|
| `app/main.swift` | Toàn bộ app Swift (AppKit, menu bar, tiếng Việt) |
| `app/Info.plist` | Thông tin bundle (LSUIElement: chỉ hiện menu bar, không hiện Dock) |
| `scripts/Cai-dat-NTFS-Menu.command` | **Double-click file này để cài đặt** (mở Terminal, chạy cai-dat.sh) |
| `scripts/cai-dat.sh` | Setup thật: Cài Homebrew (nếu thiếu), macFUSE, ntfs-3g, rồi chép app **build sẵn** vào /Applications (không cần build lại) |
| `scripts/build-app.sh` | Build app bằng swiftc, cài vào ~/Applications, tạo .dmg trên Desktop |
| `scripts/kiem-tra.command` | Double-click để kiểm tra nhanh: macFUSE, ntfs-3g, app, ổ NTFS |
| `.github/workflows/build.yml` | Build app bằng swiftc + đóng DMG (`NTFS-Menu-v1.1.dmg`) trên GitHub Actions, đăng Release v1.1 |
| `HUONG-DAN-CAI-DAT-VA-TEST.md` | Hướng dẫn cài + kế hoạch test trên ổ trống (đọc trước khi dùng) |
| `CHANGELOG.md` | Lịch sử version |

## Nhật ký

App ghi mọi thao tác vào `~/Library/Logs/NTFSMenu/ntfs-menu.log`
(việc gì, khi nào, kết quả, lỗi). Mở từ menu: **Mở file nhật ký**.

## Giới hạn đã biết (v1.1)

1. **Bản build sẵn được đóng gói bằng GitHub Actions (macOS runner):** file DMG `NTFS-Menu-v1.1.dmg` gồm app build sẵn + setup thật + hướng dẫn, nằm ở Drive 03_App. Không cần Xcode Command Line Tools, không build lại trên máy anh. Cài bằng 1 lần double-click file setup trong DMG.
2. **Chưa test trên máy Mac thật.** Code viết theo API AppKit/Foundation chuẩn,
   nhưng lần chạy đầu tiên phải theo kế hoạch test trên ổ trống trong hướng dẫn.
   **Tuyệt đối không test thẳng lên ổ footage.**
3. v1.0 gắn ổ bằng tay (bấm menu). Chưa tự gắn khi vừa cắm ổ.
4. App ký ad-hoc (không có Developer ID): setup đã gỡ cờ kiểm dịch nên mở
   thẳng được; nếu máy vẫn chặn thì **chuột phải → Mở**, hoặc dùng mo-khoa.
5. App không sandbox (bắt buộc, vì phải chạy diskutil/ntfs-3g) nên chỉ cài từ
   nguồn anh tin tưởng — tức là chính gói này.
6. Ổ trong máy (nếu có phân vùng NTFS) vẫn hiện trong menu, kèm nhãn "Ổ trong".
   Chỉ dùng cho ổ ngoài, trừ khi anh biết rõ mình đang làm gì.

## Version

Badge version hiện trong menu (cuối menu), hộp Giới thiệu, và đầu các file
hướng dẫn. Quy tắc: **mỗi lần sửa xong là tăng version + ghi ngày**
(xem `CHANGELOG.md`).
