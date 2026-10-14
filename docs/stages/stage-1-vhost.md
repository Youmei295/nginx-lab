# Giai đoạn 1 — Virtual Host (Server Block)

> Trạng thái: ✅ **Đã hoàn thành**. Nhiệm vụ: **Task 1.1–1.3** trong `../tasks.md`. Phụ trách: **TV2**.

## 1. Mục tiêu
Cấu hình 2 Server Block để phục vụ 2 trang web tĩnh (`site1.local` và `site2.local`) độc lập trên cùng một địa chỉ IP (`127.0.0.1`).

## 2. File liên quan
- `nginx/conf.d/01_vhost_sites.conf`: File cấu hình Server Block.
- `www/site1/` và `www/site2/`: Thư mục chứa mã nguồn giao diện của 2 trang web.
- `tests/test_vhost.sh`: Kịch bản kiểm thử tự động.

## 3. Bức tranh tổng thể
Khi Client gửi request HTTP chứa thông tin `Host: site1.local` -> Nginx nhận request tại cổng 80 -> Phân tích HTTP Header `Host` -> Định tuyến vào đúng Server Block có khai báo `server_name` tương ứng để xử lý.

## 4. Nguyên lý cốt lõi
Nginx phân giải request dựa trên 2 yếu tố: cổng `listen` và `server_name`. Nếu có nhiều block cùng chung IP và cổng, Nginx sẽ đối chiếu header `Host` của client với chỉ thị `server_name`. Thứ tự ưu tiên so khớp là: Tên miền chính xác (exact) → Có dấu `*` ở đầu (wildcard) → Có dấu `*` ở cuối → Biểu thức chính quy (regex) → Trả về default server.

## 5. Chi tiết code/directive
- `listen 80;`: Yêu cầu Nginx lắng nghe các kết nối đến ở cổng 80 (HTTP).
- `server_name site1.local;`: Xác định tên miền mà block này sẽ xử lý.
- `root /usr/share/nginx/html/site1;`: Chỉ định thư mục gốc chứa file mã nguồn (HTML) trên máy ảo để Nginx tìm kiếm và trả về cho người dùng.
- `index index.html;`: File mặc định sẽ được tải nếu người dùng chỉ gõ tên miền mà không chỉ định đường dẫn cụ thể.

## 6. Chạy & kiểm chứng
Sử dụng lệnh `curl` kèm theo header Host để kiểm tra:
- Lệnh: `curl -H "Host: site1.local" http://127.0.0.1/`
- Kết quả mong đợi: Trả về đoạn mã HTML chứa nội dung "Day la Site 1 - Thanh vien 2".

## 7. Lỗi thường gặp
- Quên xóa file cấu hình mặc định của Nginx (`/etc/nginx/sites-enabled/default`), dẫn đến xung đột cổng 80.
- Cấu hình sai đường dẫn `root`, khiến Nginx báo lỗi 404 Not Found hoặc 403 Forbidden do sai phân quyền thư mục.

## 8. Liên hệ
- Phụ thuộc vào Giai đoạn 0 (hạ tầng, cài đặt Nginx và xóa site mặc định).
- Là tiền đề để hiểu cách cấu hình Server Block trước khi tiến hành làm Giai đoạn 2 (Reverse Proxy).