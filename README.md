# HMaps – công cụ địa chính cho MicroStation V8i

## Cài đặt
1. Tải file [`HMaps-Setup.cmd`](HMaps-Setup.cmd) về máy (nút **Download raw file**).
2. Nháy đúp để chạy. Nếu Windows hỏi quyền Administrator thì bấm **Yes**.
3. Mở MicroStation bằng shortcut **HMaps** trên Desktop: hộp mở file chọn sẵn User (profile) **HMaps**,
   thanh giao diện HMaps (menu tiếng Việt, nút có biểu tượng) nằm phía trên.
   Ở User khác (LandMap, gCadas...) HMaps vẫn tự nạp, dùng menu **HMaps** trên thanh menu.

Yêu cầu: MicroStation V8i SELECTseries 3 (32-bit), Windows 10 trở lên.

## Cập nhật
HMaps tự kiểm tra bản mới mỗi ngày một lần khi mở MicroStation và tự tải về.
Bản mới có hiệu lực ở lần mở MicroStation kế tiếp. Muốn kiểm tra ngay: *Hệ thống > Kiểm tra bản cập nhật* trên thanh HMaps.
Máy đã cài bản cũ nên chạy lại `HMaps-Setup.cmd` một lần để có shortcut, profile HMaps và tự nạp với mọi User.

## Gỡ
Chạy `HMaps-Setup.cmd -Uninstall`, đóng MicroStation rồi xóa thư mục `%LOCALAPPDATA%\HMaps`.
