# Hướng dẫn cài đặt + test NTFS Menu — v1.1 · 05/11/2026

App menu-bar miễn phí: cắm ổ NTFS của Windows vào Mac là đọc/ghi đầy đủ,
bấm một cái là gắn, không cần gõ lệnh.

## 1. Yêu cầu

- Mac Apple Silicon, macOS 12 trở lên (khuyến nghị macOS 26 như máy anh).
- Mạng internet (để tải Homebrew, macFUSE, ntfs-3g).
- Mật khẩu quản trị của máy (lúc cài sẽ hỏi).
- **Một ổ USB trống (hoặc không chứa dữ liệu quan trọng) để test trước.**

## 2. Cài đặt (không cần gõ lệnh)

1. Tải file `NTFS-Menu-v1.1.dmg` (Drive 03_App) về Mac, double-click để mở.
2. Trong DMG, **double-click `Cài đặt NTFS Menu.command`**. Một cửa
   sổ Terminal mở ra và tự chạy: cài Homebrew (nếu thiếu),
   macFUSE, ntfs-3g, rồi chép app build sẵn vào `/Applications`
   và gỡ cờ kiểm dịch để mở thẳng. Trong lúc chạy máy có thể hỏi
   mật khẩu — gõ mật khẩu máy anh. **Không cần Xcode Command Line
   Tools, không build lại.**
3. **Duyệt extension (macOS bắt buộc, em không bấm thay được):**
   Vào **Cài đặt hệ thống → Cài đặt chung → Mục đăng nhập & Tiện ích mở
   rộng → Tiện ích mở rộng hệ thống tập tin → bật macFUSE**.
   Nếu máy yêu cầu thì **khởi động lại máy**.
4. Mở app **NTFS Menu** trong Applications.
5. Kiểm tra nhanh: double-click `Kiểm tra.command` trong DMG — phải thấy đủ
   macFUSE, ntfs-3g và app.

## 3. Cách dùng

- Bấm icon ổ đĩa trên menu bar → chọn ổ → **Gắn để ghi (NTFS-3G)**.
- Dùng xong: **Tháo ra** (hoặc **Đẩy ổ ra**) rồi mới rút cáp.
- Muốn về chế độ chỉ đọc của macOS: **Gắn lại chỉ đọc (macOS)**.
- Nghi ổ có vấn đề: **Kiểm tra ổ (chỉ đọc)** — chỉ đọc, không sửa gì.
- Mọi thao tác ghi vào nhật ký: menu → **Mở file nhật ký**.

## 4. Kế hoạch test — BẮT BUỘC LÀM TRÊN Ổ TRỐNG TRƯỚC

**Không test thẳng lên ổ footage.** Chỉ khi 8 bước dưới đều đạt mới dùng cho
ổ quan trọng — và vẫn backup trước.

1. Cắm ổ USB trống đã format NTFS (hoặc ổ trống bất kỳ, format NTFS trên
   Windows trước).
2. Mở menu NTFS Menu: phải thấy tên ổ, trạng thái "Chỉ đọc (macOS)".
3. Bấm **Gắn để ghi (NTFS-3G)**: phải báo thành công, trạng thái chuyển
   thành "Đang ghi (NTFS-3G)", ổ mở được trong Finder.
4. Trong Finder, tạo 1 thư mục tên tiếng Việt, chép 1 file ~100MB vào,
   đổi tên file, rồi xóa file đó. Tất cả phải làm được, không báo lỗi.
5. Bấm **Tháo ra**, rút cáp, cắm lại: file/thư mục còn nguyên.
6. Bấm **Gắn lại chỉ đọc (macOS)**: thử tạo file mới phải **bị chặn**
   (đúng bản chất chỉ đọc).
7. (Nếu có máy Windows) Cắm ổ sang Windows: đọc được file/thư mục đã tạo,
   không báo lỗi ổ.
8. Mở **file nhật ký**: các dòng đều OK, không có lỗi lạ.

**Tiêu chí đạt:** cả 8 bước đều đạt. **Rớt 1 bước:** dừng lại, chụp màn hình
lỗi + gửi file nhật ký, đừng cố dùng tiếp lên ổ quan trọng.

## 5. Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Menu không thấy ổ NTFS | Cắm lại cáp, bấm **Làm mới**. Kiểm tra bằng `kiem-tra.command`. |
| Gắn ghi báo lỗi | Đọc kỹ thông báo + nhật ký. Thường là extension macFUSE chưa được duyệt (làm lại bước 3) hoặc chưa khởi động lại máy. |
| App hỏi "thử với quyền quản trị" | Bấm đồng ý, nhập mật khẩu máy. Đây là hộp thoại chuẩn của macOS. |
| Báo ổ hibernated/dirty, không gắn ghi | **Đừng cố ép.** Cắm ổ lại vào Windows, tắt Fast Startup nếu cần, eject đúng cách rồi thử lại. App cố tình không tự ép gắn. |
| Mở app bị chặn (Gatekeeper) | Chuột phải vào app → Mở → Mở. Chỉ làm với app do chính anh build từ gói này. |
| Mount treo, Finder quay vòng | Bấm **Tháo ra**, đợi vài giây, gắn lại. Nếu vẫn treo: tháo ổ, khởi động lại máy, kiểm tra nhật ký. |

## 6. Giới hạn + cảnh báo (đọc kỹ)

- **Tốc độ thấp hơn Paragon.** Chép footage qua lại thì ổn; dựng 4K trực tiếp
  trên ổ thì chép về SSD của Mac rồi dựng.
- **Không có bảo đảm không mất dữ liệu tuyệt đối.** NTFS-3G đã dùng cả chục
  năm và khá ổn, nhưng không hoàn hảo. **Backup ổ quan trọng trước lần ghi
  đầu tiên**, và luôn **Tháo ra** trước khi rút cáp.
- v1.0 chưa tự gắn khi vừa cắm ổ — phải bấm menu.
- Nếu mount FSKit thất bại, app tự thử backend kernel kiểu cũ. Đường này cần
  duyệt trong Quyền riêng tư & Bảo mật + khởi động lại, và trên Apple Silicon
  có thể cần bật Reduced Security trong Recovery trước — chỉ làm khi anh hiểu
  và chấp nhận bước này.

## 7. Gỡ cài đặt

Xóa app `NTFS Menu` khỏi Applications, rồi (nếu muốn gỡ sạch driver):
`brew uninstall ntfs-3g-mac` và `brew uninstall --cask macfuse`.
