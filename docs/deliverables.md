# Kỳ vọng theo thành viên & theo demo (Deliverables)

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu này nói rõ **mỗi thành viên phải làm gì cho từng demo**, chia theo khu vực:
> `conf.d` → `scripts` → `tests` → tài nguyên → minh chứng.
> Bổ sung cho [`tasks.md`](./tasks.md) (thứ tự) và [`files.md`](./files.md) (vai trò file).

---

## 0. Quy trình chung cho MỌI demo

Mỗi người làm demo của mình theo đúng vòng lặp:

1. Viết/sửa file trong **phạm vi của mình** (xem [`collaboration.md`](./collaboration.md) mục 6).
2. Nạp config: `bash scripts/02_deploy_config.sh` (script copy vào `/etc/nginx/...`).
3. Xác nhận `sudo nginx -t` → `test is successful`.
4. Chạy test tương ứng trong `tests/`.
5. Lấy minh chứng (log/ảnh/số liệu) vào `docs/logs/`, `docs/screenshots/`, ghi vào [`report.md`](./report.md).
6. Mở PR, nhờ người review chéo.

**Định nghĩa "demo hoàn thành":** config chạy được + test pass + có minh chứng + đã merge.

Quy ước giá trị (không tự bịa): xem [`interfaces.md`](./interfaces.md).

---

## 1. Demo 1 — Virtual Host (TV2)

**Mục tiêu:** 2 Server Block phục vụ 2 site tĩnh trên cùng 1 IP.
**Phụ thuộc:** Giai đoạn 0 (đã xong).

| Khu vực | Việc cần làm | Điều kiện hoàn thành (DoD) |
|---------|--------------|----------------------------|
| **`nginx/conf.d/01_vhost_sites.conf`** | 2 `server` block: `listen 80;` + `server_name site1.local;`/`site2.local;`, mỗi block `root /usr/share/nginx/html/site1` (và `site2`), `index index.html;` | `sudo nginx -t` pass |
| **`www/`** | `www/site1/index.html`, `www/site2/index.html` — nội dung khác nhau, ghi rõ tên site | 2 trang hiển thị phân biệt được |
| **`scripts/`** | Không tạo script mới — dùng `02_deploy_config.sh` có sẵn | Deploy nạp được config |
| **`tests/test_vhost.sh`** | `curl -H "Host: site1.local" http://127.0.0.1/` và `site2.local`, so sánh nội dung | Script exit 0, in PASS/FAIL rõ ràng |
| **Minh chứng** | Ảnh trình duyệt 2 site (`wkhtmltoimage` / browser) | `docs/screenshots/demo1_site1.png`, `demo1_site2.png` |

**Không được đụng:** `nginx/nginx.conf`, `02_*.conf`, `03_*.conf`, `backend/`, `docs/` (ngoài mục của mình).

---

## 2. Demo 2 — Reverse Proxy & HTTPS (TV3)

**Mục tiêu:** `app.local` → proxy `127.0.0.1:3000` + TLS self-signed.
**Phụ thuộc:** Giai đoạn 0.

| Khu vực | Việc cần làm | Điều kiện hoàn thành (DoD) |
|---------|--------------|----------------------------|
| **`nginx/conf.d/02_reverse_proxy.conf`** | Server `app.local:80` → `return 301 https://$host$request_uri;`. Server `app.local:443 ssl;`, `ssl_certificate /etc/nginx/ssl/server.crt;` + key; `proxy_pass http://127.0.0.1:3000;`; `proxy_set_header Host $host; X-Real-IP $remote_addr; X-Forwarded-For $proxy_add_x_forwarded_for;` (Kèm phần error page cho Demo 4 — xem mục 4.) | `sudo nginx -t` pass |
| **`backend/app.py`** | HTTP server Python stdlib bind `127.0.0.1:3000`, in `Host`/`X-Real-IP`/`X-Forwarded-For` | `python3 backend/app.py` + `curl 127.0.0.1:3000` → 200 |
| **`scripts/01_generate_ssl.sh`** | OpenSSL sinh self-signed vào `ssl/server.crt`, `ssl/server.key`, **có SAN** `DNS:app.local, DNS:localhost, IP:127.0.0.1`; idempotent | Chạy 2 lần không lỗi; cert có SAN đúng |
| **`tests/test_https_proxy.sh`** | `curl -I http://app.local` → 301; `curl -k https://app.local` → 200 và có `X-Forwarded-For` | Script exit 0 |
| **Minh chứng** | Ảnh HTTPS + cảnh báo cert self-signed | `docs/screenshots/demo2_https.png` |

**Không được đụng:** `nginx.conf`, `01_*.conf`, `03_*.conf`, `www/site*`.

---

## 3. Demo 3 — Rate Limiting & Benchmark (TV4)

**Mục tiêu:** giới hạn tải trên `limit.local` + benchmark 100 request đồng thời, thống kê 200 vs 503.
**Phụ thuộc:** Giai đoạn 0 (độc lập với Demo 2).

| Khu vực | Việc cần làm | Điều kiện hoàn thành (DoD) |
|---------|--------------|----------------------------|
| **`nginx/conf.d/03_rate_limit.conf`** | Trong `http`: `limit_req_zone $binary_remote_addr zone=perip:10m rate=10r/s;`. Server `limit.local:80`, `limit_req zone=perip burst=20 nodelay;`, `root /usr/share/nginx/html; index index.html;` (nội dung không quan trọng) | `sudo nginx -t` pass; `curl http://limit.local` → 200 khi tải thấp |
| **`scripts/03_run_benchmark.sh`** | `ab -n 100 -c 100 http://limit.local/`, trích `Complete requests`, `Non-2xx responses`, in thống kê 200 vs 503 | Chạy được, in cả 2 con số |
| **`tests/test_rate_limit.sh`** | Gửi loạt request vượt ngưỡng, xác nhận **có 503** | Script exit 0 khi thấy 503 |
| **Minh chứng** | Trích `limiting requests` từ `error.log` + dòng 503 từ `access.log`; ảnh kết quả `ab` | `docs/logs/rate_limit_503.log`, `docs/screenshots/demo3_benchmark.png` |

**Không được đụng:** `nginx.conf`, `01_*.conf`, `02_*.conf`, `backend/`.

---

## 4. Demo 4 — Troubleshooting backend down (TV3 + TV5)

**Mục tiêu:** tắt backend → Nginx trả 502 → trang lỗi tùy chỉnh + dòng `error.log`.
**Phụ thuộc:** Demo 2 (TV3) hoàn tất.

| Khu vực | Việc cần làm | Người | DoD |
|---------|--------------|-------|-----|
| **`nginx/conf.d/02_reverse_proxy.conf`** (phần error page) | `error_page 502 503 504 /50x.html;` + `location = /50x.html { alias /usr/share/nginx/error_pages/custom_50x.html; internal; }` | TV3 | `nginx -t` pass |
| **`www/error_pages/custom_50x.html`** | Trang lỗi thân thiện cho 502/503/504 | TV5 | HTML hợp lệ, hiển thị khi lỗi |
| **`scripts/04_collect_logs.sh`** | Trích `connect() failed` (502) và `limiting requests` (503) từ `/var/log/nginx/error.log` vào `docs/logs/` | TV5 | Tạo được `docs/logs/backend_down_502.log` |
| **`tests/test_troubleshooting.sh`** | Dừng backend → `curl -k https://app.local` mong đợi 502 → khởi động lại backend | TV3/TV5 | Script exit 0, phục hồi backend sau test |
| **Minh chứng** | Ảnh trang lỗi tùy chỉnh trên trình duyệt | TV5 | `docs/screenshots/demo4_error_page.png` |

**Không được đụng:** `nginx.conf`, `01_*.conf`, `03_*.conf`.

---

## 5. Phần dùng chung (không thuộc riêng demo)

| Thành viên | Trách nhiệm chung |
|------------|-------------------|
| **TV1** | `nginx/nginx.conf`, `scripts/00_setup_vm.sh`, `scripts/02_deploy_config.sh`; điều phối, review |
| **TV5** | `scripts/04_collect_logs.sh`, `docs/report.md`, `docs/logs/`, `docs/screenshots/`; thu log tất cả demo |
| **Cả nhóm** | `README.md`, `docs/tasks.md`, `docs/interfaces.md` (sửa phải báo nhóm) |

---

## 6. Ma trận tổng hợp: ai làm gì ở đâu

| TV | `nginx/conf.d` | `scripts/` | `tests/` | Tài nguyên | Minh chứng |
|----|----------------|------------|----------|------------|------------|
| **TV1** | — (`nginx.conf`) | `00_setup_vm.sh`, `02_deploy_config.sh` | — | — | — |
| **TV2** | `01_vhost_sites.conf` | (dùng chung 02) | `test_vhost.sh` | `www/site1`, `www/site2` | ảnh demo1 |
| **TV3** | `02_reverse_proxy.conf` | `01_generate_ssl.sh` | `test_https_proxy.sh` | `backend/app.py`, `ssl/` | ảnh demo2 |
| **TV4** | `03_rate_limit.conf` | `03_run_benchmark.sh` | `test_rate_limit.sh` | — | log 503, ảnh demo3 |
| **TV5** | (chung 02 với TV3) | `04_collect_logs.sh` | `test_troubleshooting.sh` | `www/error_pages/` | log 502, ảnh demo4, report |

> Thứ tự/phụ thuộc thời gian: xem [`tasks.md`](./tasks.md) mục *"Sơ đồ làm việc & Timeline"*.

---

## 7. Checklist minh chứng (trước khi nộp)

`[ ]` chưa có — `[x]` đã lấy. Lưu tại `docs/logs/`, `docs/screenshots/`; kết quả điền vào [`report.md`](./report.md).

### Chung
- [ ] `README.md` có phân công và quick-start.
- [ ] `docs/report.md` điền đủ Phần A (4 mục lý thuyết) + Phần B (4 demo).
- [ ] Tất cả config đã merge vào `main` và `nginx -t` pass.
- [ ] Không commit secret: `git ls-files | grep -i key` → rỗng.

### Demo 1 — Virtual Host
- [ ] `curl -H "Host: site1.local" http://127.0.0.1/` → nội dung Site 1.
- [ ] `curl -H "Host: site2.local" http://127.0.0.1/` → nội dung Site 2.
- [ ] Ảnh `docs/screenshots/demo1_site1.png`, `demo1_site2.png`.

### Demo 2 — Reverse Proxy & HTTPS
- [ ] `curl -I http://app.local/` → `301`.
- [ ] `curl -k https://app.local/` → `200` + nội dung backend.
- [ ] Header tới backend có `X-Forwarded-For` / `X-Real-IP`.
- [ ] `openssl s_client -connect app.local:443 -servername app.local` → cert có SAN `app.local`.
- [ ] Ảnh `docs/screenshots/demo2_https.png`.

### Demo 3 — Rate Limiting & Benchmark
- [ ] `scripts/03_run_benchmark.sh` chạy `ab -n 100 -c 100 http://limit.local/`.
- [ ] Output `ab` có `Complete requests: 100`, `Non-2xx responses` (~79), `Requests per second`.
- [ ] Có cả mã 200 lẫn 503.
- [ ] `docs/logs/rate_limit_503.log` (503 + `limiting requests`).
- [ ] Ảnh `docs/screenshots/demo3_benchmark.png`.

### Demo 4 — Troubleshooting
- [ ] `tests/test_troubleshooting.sh` dừng backend → `curl -k https://app.local/` trả `502`.
- [ ] Trang lỗi tùy chỉnh hiển thị (không phải trang mặc định).
- [ ] `docs/logs/backend_down_502.log` (`connect() failed (111: Connection refused)`).
- [ ] Ảnh `docs/screenshots/demo4_error_page.png`.

### Phần lý thuyết & trình bày
- [ ] A.1 Vai trò Web Server / Reverse Proxy + lý do không expose backend.
- [ ] A.2 Event-driven Nginx vs Process/Thread Apache.
- [ ] A.3 Cơ chế Server Block.
- [ ] A.4 access.log/error.log + phân biệt 502/503/504.
- [ ] Slide thuyết trình; demo chạy live trên VM Ubuntu 22.04; có ảnh + log dự phòng.
