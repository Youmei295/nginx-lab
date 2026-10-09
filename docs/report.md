# Báo cáo Lab — Nginx Web Server & Reverse Proxy

> Lab CSC-11117 — Linux OS And Applications
> **Hướng dẫn:** mỗi mục có người phụ trách (xem `tasks.md`). Điền nội dung, dán minh chứng
> (log/ảnh) tương ứng. Giữ `TODO` nếu chưa làm để nhóm biết còn thiếu.

**Nhóm:** _điền tên nhóm_
**Thành viên:** TV1 _..._ · TV2 _..._ · TV3 _..._ · TV4 _..._ · TV5 _..._
**Ngày nộp:** _..._

---

## Phần A — Nội dung lý thuyết

### A.1. Vai trò Web Server & Reverse Proxy; vì sao không để backend nhận request trực tiếp
*(Phụ trách: TV3)*

- **TODO:** Web server là gì, reverse proxy là gì, sự khác biệt proxy thuận/nghịch.
- **TODO:** 4–5 lý do không expose backend trực tiếp: bảo mật (ẩn cấu trúc nội bộ, chỉ mở 80/443), TLS termination, load balancing, caching/static, rate limiting/WAF, che giấu lỗi.
- **Liên hệ demo:** `app.local` proxy tới `127.0.0.1:3000`; backend chỉ bind loopback.

### A.2. Kiến trúc event-driven của Nginx vs process/thread của Apache
*(Phụ trách: TV1)*

- **TODO:** Mô tả mô hình worker + event loop (async, non-blocking) của Nginx.
- **TODO:** Mô tả mô hình process/thread (prefork/worker) của Apache và chi phí context switch, RAM mỗi kết nối.
- **TODO:** Bảng so sánh và hệ quả khi C10K (10.000 kết nối đồng thời) trên VM 512MB.
- **Liên hệ demo:** `worker_connections` trong `nginx/nginx.conf`.

### A.3. Cơ chế Server Block (Virtual Host)
*(Phụ trách: TV2)*

- **TODO:** Nginx chọn server block theo `listen` (IP:port) rồi `server_name` (so khớp header `Host`).
- **TODO:** Thứ tự ưu tiên: exact → wildcard → regex → default server.
- **Liên hệ demo:** `site1.local` và `site2.local` cùng IP, khác `root`.

### A.4. access.log / error.log và phân biệt 502, 503, 504
*(Phụ trách: TV4–TV5)*

- **TODO:** Vị trí (`/var/log/nginx/`), cấu trúc `access.log` (combined + `$request_time`), cấu trúc `error.log` (mức độ, thời gian, message).
- **TODO:** Bảng phân biệt:
  | Mã | Tên | Nguyên nhân thường gặp | Dấu hiệu trong log |
  |----|-----|------------------------|--------------------|
  | 502 | Bad Gateway | Backend chết, sai port | `connect() failed ... Connection refused` |
  | 503 | Service Unavailable | Rate limit, quá tải, `limit_conn` | `limiting requests` |
  | 504 | Gateway Timeout | Backend xử lý quá lâu | `upstream timed out` |
- **Liên hệ demo:** log 502 ở `docs/logs/backend_down_502.log`, log 503 ở `docs/logs/rate_limit_503.log`.

---

## Phần B — Kết quả demo

### B.1. Demo 1 — Virtual Host
- **Lệnh:**
  ```bash
  curl -H "Host: site1.local" http://127.0.0.1/
  curl -H "Host: site2.local" http://127.0.0.1/
  ```
- **Kết quả:** _TODO: dán output_
- **Ảnh:** _TODO: `docs/screenshots/demo1_*.png`_

### B.2. Demo 2 — Reverse Proxy & HTTPS
- **Lệnh:**
  ```bash
  curl -I  http://app.local/     # mong đợi 301 → https
  curl -k https://app.local/     # mong đợi 200 + nội dung backend
  ```
- **Kết quả:** _TODO: dán output, cho thấy `X-Forwarded-For`_
- **Ảnh:** _TODO: `docs/screenshots/demo2_*.png`_

### B.3. Demo 3 — Rate Limiting & Benchmark
- **Lệnh:** `bash scripts/03_run_benchmark.sh`
- **Kết quả `ab`:** _TODO: `Complete requests`, `Non-2xx responses`, `Requests per second`_
- **Thống kê:** 200 ≈ _21_, 503 ≈ _79_
- **Log:** `docs/logs/rate_limit_503.log`
- **Ảnh:** _TODO: `docs/screenshots/demo3_*.png`_

### B.4. Demo 4 — Troubleshooting backend down
- **Lệnh:** `bash tests/test_troubleshooting.sh`
- **Kết quả:** _TODO: 502 + trang lỗi tùy chỉnh_
- **Log:** `docs/logs/backend_down_502.log`
- **Ảnh:** _TODO: `docs/screenshots/demo4_error_page.png`_

---

## Phần C — Kết luận

- **TODO:** Tổng kết đã làm được gì, hạn chế, hướng phát triển (load balancing, real cert Let's Encrypt, HTTP/2, caching).
- **TODO:** Phân chia đóng góp (ai làm phần nào).

## Phụ lục

- Danh sách file: `docs/files.md`
- Giao diện chung: `docs/interfaces.md`
- Checklist minh chứng: `docs/deliverables.md` (mục 7)
