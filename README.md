# HMaps – công cụ địa chính cho MicroStation V8i

> **Chưa có bản phát hành.** Kho này mới được dựng; bộ cài sẽ dùng được khi bản đầu tiên (`HMaps.dll` và `version.json`) được đưa lên.

## Cài đặt
1. Tải file [`HMaps-Setup.cmd`](HMaps-Setup.cmd) về máy (nút **Download raw file**).
2. Nháy đúp để chạy. Nếu Windows hỏi quyền Administrator thì bấm **Yes**.
3. Mở lại MicroStation. HMaps tự nạp; gõ key-in `hmaps info` để kiểm tra.

Yêu cầu: MicroStation V8i SELECTseries 3 (32-bit), Windows 10 trở lên.

## Cập nhật
HMaps tự kiểm tra bản mới mỗi ngày một lần khi mở MicroStation và tự tải về.
Bản mới có hiệu lực ở lần mở MicroStation kế tiếp. Muốn kiểm tra ngay: key-in `hmaps update`.

## Gỡ
Chạy `HMaps-Setup.cmd -Uninstall`, đóng MicroStation rồi xóa thư mục `%LOCALAPPDATA%\HMaps`.
