# nginx-lab — Nginx Web Server & Reverse Proxy

> Lab môn **CSC-11117 — Linux OS And Applications**
> Nhóm 5 thành viên. Hạ tầng: **1 VM Ubuntu 22.04 (512MB RAM)**.

Repo mô phỏng một hệ thống web thực tế: dùng Nginx làm web server cho site tĩnh,
làm reverse proxy + HTTPS cho ứng dụng backend, giới hạn tải (rate limiting) và
xử lý sự cố khi backend gặp lỗi.

---

## Mục tiêu / Demo

| # | Demo | Nội dung |
|---|------|----------|
| 1 | **Virtual Host** | 2 Server Block phục vụ 2 site tĩnh (`site1.local`, `site2.local`) trên cùng 1 IP |
| 2 | **Reverse Proxy & HTTPS** | Proxy `app.local` → app Python `127.0.0.1:3000` + TLS self-signed |
| 3 | **Rate Limiting & Benchmark** | `limit_req` với `burst`/`nodelay`, dùng `ab` gửi 100 request đồng thời, thống kê 200 vs 503 |
| 4 | **Troubleshooting** | Tắt backend → trang lỗi tùy chỉnh 502 + trích `error.log` |

---

## Cấu trúc thư mục

```
.
├── nginx/            # Cấu hình Nginx
│   ├── conf.d/       #   01 vhost, 02 reverse proxy, 03 rate limit
│   └── nginx.conf    #   worker/events + log_format
├── www/              # Nội dung web tĩnh
│   ├── site1/ site2/ #   Site cho Demo 1
│   └── error_pages/  #   Trang lỗi tùy chỉnh (Demo 4)
├── backend/          # Mock app 127.0.0.1:3000 (Python 3)
├── ssl/              # Cert self-signed (không commit)
├── scripts/          # 00 setup env, 01 cert, 02 deploy, 03 benchmark, 04 collect logs
├── tests/            # Script kiểm thử từng demo
└── docs/             # Tài liệu, log, ảnh minh chứng
```

Chi tiết vai trò từng file: [`docs/files.md`](docs/files.md).

---

## Bắt đầu nhanh

```bash
# 1. Cài môi trường (swap, nginx, ab, python3, hosts)
bash scripts/00_setup_vm.sh

# 2. Sinh chứng chỉ self-signed
bash scripts/01_generate_ssl.sh

# 3. Chạy backend (terminal khác)
python3 backend/app.py

# 4. Deploy cấu hình Nginx
bash scripts/02_deploy_config.sh

# 5. Kiểm thử
bash tests/test_vhost.sh
bash tests/test_https_proxy.sh
bash tests/test_rate_limit.sh
bash tests/test_troubleshooting.sh
```

> Hướng dẫn chi tiết theo từng hệ điều hành host (Hyper-V/VirtualBox/VMware/UTM/WSL2):
> [`docs/environment.md`](docs/environment.md).

---

## Phân công

| TV | Phụ trách chính | Demo |
|----|-----------------|------|
| **TV1** | Hạ tầng, deploy, `nginx.conf` | Giai đoạn 0 |
| **TV2** | Virtual Host | Demo 1 |
| **TV3** | Backend, Reverse Proxy, HTTPS | Demo 2 |
| **TV4** | Rate Limit & Benchmark | Demo 3 |
| **TV5** | Troubleshooting, log, báo cáo | Demo 4 + Docs |

Chi tiết & thứ tự thời gian: [`docs/tasks.md`](docs/tasks.md).

---

## Tài liệu

| Tài liệu | Nội dung |
|----------|----------|
| [`docs/interfaces.md`](docs/interfaces.md) | **Giao diện chung đã chốt** (domain, cổng, đường dẫn) — đọc trước khi code |
| [`docs/ai-agents.md`](docs/ai-agents.md) | Quy tắc cho AI agent (và người dùng AI) làm việc trên repo |
| [`docs/tasks.md`](docs/tasks.md) | Danh sách task theo thứ tự thời gian |
| [`docs/timeline.md`](docs/timeline.md) | Sơ đồ làm việc song song, phụ thuộc, timeline theo ngày |
| [`docs/stages/`](docs/stages/README.md) | Tài liệu kỹ thuật giải thích code & nguyên lý từng giai đoạn (Stage 0–5) |
| [`docs/files.md`](docs/files.md) | Giải thích từng file trong repo |
| [`docs/environment.md`](docs/environment.md) | Dựng môi trường Ubuntu 22.04, chạy script |
| [`docs/collaboration.md`](docs/collaboration.md) | Quy tắc làm việc nhóm (branch, PR, review) |
| [`docs/checklist.md`](docs/checklist.md) | Checklist minh chứng cần lấy |
| [`docs/report.md`](docs/report.md) | Báo cáo lý thuyết & kết quả demo |

---

## Tổng quan kiến trúc

```
Client ──HTTP/HTTPS──> Nginx
     ├─ site1.local / site2.local  →  www/site1, www/site2        (Demo 1)
     ├─ app.local:443  → proxy_pass → 127.0.0.1:3000              (Demo 2)
     │                 → lỗi upstream → custom_50x.html           (Demo 4)
     └─ limit.local:80 → rate limit (burst/nodelay) → 200/503     (Demo 3)
```
