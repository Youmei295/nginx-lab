# Cấu trúc Repo & Vai trò từng File

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu này giải thích **mục đích của từng file** và file đó phục vụ **task/demo nào**.
> Danh sách task chi tiết xem tại [`tasks.md`](./tasks.md).

---

## 1. Tóm tắt yêu cầu bài lab

**Hạ tầng:** 1 VM (512MB RAM).

### A. Nội dung lý thuyết
1. Vai trò của Web Server và Reverse Proxy; lý do không để backend nhận request trực tiếp từ Internet.
2. Kiến trúc event-driven của Nginx so với mô hình process/thread của Apache; hệ quả khi tải đồng thời lớn.
3. Cơ chế Server Block (Virtual Host): Nginx phân biệt nhiều site trên cùng 1 IP.
4. Vị trí, cấu trúc và cách phân tích `access.log`, `error.log`; phân biệt lỗi 502, 503, 504.

### B. Các demo bắt buộc
1. **Virtual Host:** 2 Server Block phục vụ 2 trang HTML tĩnh cho 2 tên miền trên cùng 1 IP.
2. **Reverse Proxy & HTTPS:** Nginx chuyển tiếp traffic về app Node.js/Python trên `127.0.0.1` + HTTPS bằng self-signed certificate.
3. **Rate Limiting & Benchmark:** cấu hình `burst` + `nodelay`, dùng `ab`/`wrk` gửi 100 request đồng thời, thống kê HTTP 200 và 503.
4. **Troubleshooting:** tắt backend, chụp trang lỗi tùy chỉnh, xuất dòng log lỗi trong `error.log`.

---

## 2. Bảng ánh xạ file → task

### Thư mục gốc

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `README.md` | Giới thiệu dự án, phân công, cách chạy nhanh. | — |
| `AGENTS.md` | Tóm tắt quy tắc cho AI agent, trỏ tới `docs/ai-agents.md`. | Quản lý chung |
| `LICENSE` | Giấy phép mã nguồn. | — |
| `.gitignore` | Loại trừ cert/key, `__pycache__`, log runtime, file môi trường. Bảo vệ khóa riêng tư khỏi bị commit. | Giai đoạn 0 |

### `nginx/` — Cấu hình Nginx

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `nginx/nginx.conf` | File cấu hình nền: `worker_processes`, `events.worker_connections`, `log_format` (thêm `$request_time`, `$upstream_response_time`). | Task 0.4 |
| `nginx/conf.d/01_vhost_sites.conf` | 2 Server Block cho `site1.local` và `site2.local`, mỗi block trỏ `root` riêng. | Demo 1 — Task 1.2 |
| `nginx/conf.d/02_reverse_proxy.conf` | `proxy_pass` tới `127.0.0.1:3000`, header `X-Real-IP`/`X-Forwarded-For`, TLS self-signed, redirect HTTP→HTTPS, `error_page 502 503 504`. | Demo 2 — Task 2.3; Demo 4 — Task 4.1 |
| `nginx/conf.d/03_rate_limit.conf` | `limit_req_zone` theo `$binary_remote_addr`, vhost riêng `limit.local` (HTTP:80) với `limit_req` `burst` + `nodelay`. | Demo 3 — Task 3.1 |

### `www/` — Nội dung web tĩnh

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `www/site1/index.html` | Trang HTML của Site 1. | Demo 1 — Task 1.1 |
| `www/site2/index.html` | Trang HTML của Site 2. | Demo 1 — Task 1.1 |
| `www/error_pages/custom_50x.html` | Trang lỗi tùy chỉnh cho 502/503/504, phục vụ qua `location = /50x.html` (alias, `internal`). | Demo 4 — Task 4.1 |

### `backend/` — Ứng dụng mock

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `backend/app.py` | HTTP server tối giản (Python 3 stdlib) chạy `127.0.0.1:3000`, làm upstream cho reverse proxy. Bind loopback để mô phỏng backend không lộ ra ngoài. | Demo 2 — Task 2.1 |

### `ssl/` — Chứng chỉ TLS

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `ssl/.gitkeep` | Giữ thư mục trong Git khi chưa có cert. | — |
| `ssl/server.crt` | Chứng chỉ self-signed, SAN `app.local` (sinh runtime, **không commit** — đã ignore). | Demo 2 — Task 2.2 |
| `ssl/server.key` | Khóa riêng tư (sinh runtime, **không commit** — đã ignore). | Demo 2 — Task 2.2 |

### `scripts/` — Tự động hóa

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `scripts/00_setup_vm.sh` | Tạo swap 1GB, thêm domain test vào `/etc/hosts`, cài `nginx`, `curl`, `apache2-utils` (`ab`), `openssl`, `python3`. | Giai đoạn 0 — Task 0.1, 0.2, 0.3 |
| `scripts/01_generate_ssl.sh` | Sinh cert self-signed (có SAN `app.local`) bằng OpenSSL vào `ssl/`. | Demo 2 — Task 2.2 |
| `scripts/02_deploy_config.sh` | Xoá site default, copy `nginx/conf.d/*` và `www/*` vào hệ thống, chạy `nginx -t` rồi `systemctl reload nginx`. | Giai đoạn 0 — Task 0.5 |
| `scripts/03_run_benchmark.sh` | Chạy `ab -n 100 -c 100`, tách thống kê 200 và 503. | Demo 3 — Task 3.2 |
| `scripts/04_collect_logs.sh` | Trích `access.log`/`error.log` từ `/var/log/nginx/` vào `docs/logs/`. | Giai đoạn 5 — Task 5.1 |

### `tests/` — Kiểm thử từng demo

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `tests/test_vhost.sh` | `curl -H "Host: ..."` xác nhận Nginx định tuyến đúng server block. | Demo 1 — Task 1.3 |
| `tests/test_https_proxy.sh` | Kiểm tra HTTPS 200, header `X-Forwarded-For`, redirect 301 từ HTTP. | Demo 2 — Task 2.4 |
| `tests/test_rate_limit.sh` | Gửi request vượt ngưỡng, xác nhận có phản hồi 503. | Demo 3 — Task 3.3 |
| `tests/test_troubleshooting.sh` | Dừng backend → xác nhận 502 → khởi động lại. | Demo 4 — Task 4.2 |

### `docs/` — Tài liệu & minh chứng

| File | Mục đích | Task / Demo |
|------|----------|-------------|
| `docs/tasks.md` | Danh sách task, phân công, sơ đồ làm việc song song & timeline theo ngày. | Quản lý chung |
| `docs/deliverables.md` | Kỳ vọng từng thành viên theo từng demo (conf.d, scripts, tests, minh chứng) + checklist minh chứng. | Quản lý chung |
| `docs/stages/` | Tài liệu kỹ thuật theo giai đoạn (`stage-0-infra.md` … `stage-5-*.md`) giải thích code & nguyên lý. | Quản lý chung |
| `docs/interfaces.md` | Giao diện chung đã chốt: domain, cổng, đường dẫn deploy, error page, cert, thông số rate limit. | Quản lý chung |
| `docs/ai-agents.md` | Quy tắc cho AI agent: thứ tự đọc, phạm vi file, kiểm chứng, điều cấm, mẫu prompt. | Quản lý chung |
| `docs/collaboration.md` | Quy tắc cộng tác Git: nhánh, commit, PR, review, xử lý conflict, ranh giới file. | Quản lý chung |
| `docs/environment.md` | Nền tảng chuẩn Ubuntu 22.04, hướng dẫn tạo VM theo từng host (Hyper-V/VirtualBox/VMware/UTM/WSL2) và cách chạy script setup. | Giai đoạn 0 — Task 0.1, 0.2 |
| `docs/files.md` | Tài liệu này — giải thích từng file. | Quản lý chung |
| `docs/report.md` | Báo cáo lý thuyết A (4 mục), kết quả demo, biểu đồ benchmark. | Giai đoạn 5 — Task 5.2, 5.3 |
| `docs/logs/rate_limit_503.log` | Trích log 503 + dòng `limiting requests` từ `error.log`. | Demo 3 — Task 3.3 |
| `docs/logs/backend_down_502.log` | Trích log `connect() failed (Connection refused)` khi backend down. | Demo 4 — Task 4.3 |
| `docs/logs/.gitkeep` | Giữ thư mục log trong Git. | — |
| `docs/screenshots/` | Ảnh trang lỗi tùy chỉnh, HTTPS, kết quả benchmark. | Demo 4 — Task 4.3 |
| `docs/screenshots/.gitkeep` | Giữ thư mục ảnh trong Git. | — |

---

## 3. Sơ đồ luồng phục vụ request

```
Client ──HTTP/HTTPS──> Nginx (conf.d)
                          │
        ┌─────────────────┼──────────────────────┐
        ▼                 ▼                       ▼
   01_vhost_sites    02_reverse_proxy        03_rate_limit
   site1/site2        app.local                  burst+nodelay
   (www/site*)        proxy_pass ──> 127.0.0.1:3000 (backend/app.py)
                       │
                       └─ lỗi upstream → error_page → custom_50x.html
                                        → ghi /var/log/nginx/error.log
                                        → scripts/04_collect_logs.sh → docs/logs/
```
