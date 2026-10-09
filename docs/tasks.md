# Danh sách nhiệm vụ (Task List) — Nginx Web Server & Reverse Proxy

> Lab CSC-11117 — Linux OS And Applications
> Nhóm 5 thành viên (TV1–TV5). Các task được sắp xếp **theo thứ tự thời gian**:
> task sau chỉ bắt đầu khi task trước đã hoàn thành (trừ các task ghi rõ `// song song`).

## Quy ước

- `[ ]` chưa làm — `[x]` đã xong.
- **Phụ thuộc**: task cần hoàn thành trước.
- **Bàn giao**: minh chứng cụ thể để tính là hoàn thành.
- Port backend cố định: `127.0.0.1:3000`. Domain test khai báo trong `/etc/hosts`.
- **Giao diện chung (domain, cổng, đường dẫn, thông số):** xem [`interfaces.md`](./interfaces.md) — bắt buộc tuân theo.
- **Sơ đồ làm việc song song & timeline:** xem mục *"Sơ đồ làm việc & Timeline"* ở cuối tài liệu này.
- **Tài liệu kỹ thuật từng giai đoạn:** xem [`stages/`](./stages/README.md).
- **Kỳ vọng chi tiết theo demo (conf.d/scripts/tests/minh chứng):** xem [`deliverables.md`](./deliverables.md).
- **Quy trình làm việc (nhánh, commit, PR, review):** xem [`collaboration.md`](./collaboration.md).

---

## Giai đoạn 0 — Hạ tầng & chuẩn bị (TV1)

### [ ] 0.1. Tạo VM và swap
- **Giải thích:** VM chỉ 512MB RAM, Nginx + backend có thể bị OOM khi benchmark 100 request đồng thời. Thêm swap 1GB giúp hệ thống không sập, đảm bảo số liệu benchmark ổn định.
- **Thực hiện:** TV1 **viết** `scripts/00_setup_vm.sh`; **mỗi thành viên chạy** script một lần trên Ubuntu 22.04 của mình. Hướng dẫn tạo VM cho từng host (Hyper-V/VirtualBox/VMware/UTM/WSL2) xem `docs/environment.md`.
- **Phụ thuộc:** không (việc tạo VM là bước thủ công, không do script thực hiện).
- **Bàn giao:** script chạy được (idempotent), `free -h` hiển thị swap 1GB.

### [ ] 0.2. Cài đặt công cụ
- **Giải thích:** Cần `nginx`, `curl`, `apache2-utils` (chứa `ab`), `openssl`, `python3` phục vụ các demo sau. Cài tập trung một lần để tránh lệch phiên bản giữa các thành viên.
- **Thực hiện:** bổ sung vào `scripts/00_setup_vm.sh`.
- **Phụ thuộc:** 0.1.
- **Bàn giao:** `nginx -v`, `ab -V`, `python3 --version` đều in ra phiên bản.

### [ ] 0.3. Khai báo domain test
- **Giải thích:** Demo 1 và Demo 2 cần nhiều tên miền trỏ về cùng 1 IP. Vì không có DNS thật, ta dùng `/etc/hosts` để mô phỏng: `site1.local`, `site2.local`, `app.local`, `limit.local` → `127.0.0.1` (chi tiết [`interfaces.md`](./interfaces.md) mục 1).
- **Thực hiện:** `scripts/00_setup_vm.sh` tự thêm dòng hosts (idempotent, có kiểm tra trùng).
- **Phụ thuộc:** không. `// song song` với 0.1–0.2.
- **Bàn giao:** `getent hosts site1.local` trả về `127.0.0.1`; `getent hosts limit.local` tương tự.

### [ ] 0.4. Cấu hình nền `nginx.conf`
- **Giải thích:** Cần định nghĩa `worker_processes`, `events.worker_connections` và đặc biệt là `log_format` để `access.log` ghi thêm thời gian xử lý (`$request_time`, `$upstream_response_time`) — phục vụ phân tích 502/503/504 ở TV4 và TV5.
- **Thực hiện:** `nginx/nginx.conf` + `scripts/02_deploy_config.sh`.
- **Phụ thuộc:** 0.2.
- **Bàn giao:** `nginx -t` báo `syntax is ok`; `access.log` chứa cột thời gian.

### [ ] 0.5. Cơ chế deploy
- **Giải thích:** Các thành viên viết config trong repo nhưng Nginx đọc ở `/etc/nginx/`. Script deploy copy `nginx/conf.d/*` và `www/*` vào hệ thống rồi `reload`, giúp mọi người kiểm thử cùng luồng, tránh sửa tay. Phải **xoá site mặc định** (`sites-enabled/default`) để port 80 nhường cho các vhost.
- **Thực hiện:** `scripts/02_deploy_config.sh` (xoá default → copy → `nginx -t` → `systemctl reload nginx`). Đường dẫn đích xem [`interfaces.md`](./interfaces.md) mục 3.
- **Phụ thuộc:** 0.4.
- **Bàn giao:** deploy thành công, `systemctl status nginx` active, `curl http://site1.local` không trả trang default.

---

## Giai đoạn 1 — Demo 1: Virtual Host (TV2)

### [ ] 1.1. Tạo nội dung site tĩnh
- **Giải thích:** Cần 2 trang HTML phân biệt rõ để chứng minh Nginx định tuyến đúng server block.
- **Thực hiện:** `www/site1/index.html`, `www/site2/index.html`.
- **Phụ thuộc:** Giai đoạn 0.
- **Bàn giao:** 2 file HTML hiển thị tên site khác nhau.

### [ ] 1.2. Cấu hình 2 Server Block
- **Giải thích:** `server_name` là khóa để Nginx chọn block theo header `Host` của request, cho phép nhiều site dùng chung 1 IP. Cần khai báo `root` riêng và `index index.html`.
- **Thực hiện:** `nginx/conf.d/01_vhost_sites.conf`.
- **Phụ thuộc:** 1.1.
- **Bàn giao:** cấu hình 2 block `site1.local`, `site2.local`.

### [ ] 1.3. Kiểm thử Virtual Host
- **Giải thích:** Xác nhận Nginx phân biệt site dựa trên `Host`, không dựa trên IP.
- **Thực hiện:** `tests/test_vhost.sh` — `curl -H "Host: site1.local" http://127.0.0.1` và ngược lại.
- **Phụ thuộc:** 1.2.
- **Bàn giao:** output trả về đúng nội dung từng site.

---

## Giai đoạn 2 — Demo 2: Reverse Proxy & HTTPS (TV3)

### [ ] 2.1. Mock backend chạy `127.0.0.1:3000`
- **Giải thích:** Mô phỏng ứng dụng backend thật để thấy Nginx làm trung gian. Viết bằng Python 3 (stdlib, không dependency), chỉ bind loopback — minh họa nguyên tắc backend **không** lộ trực tiếp ra Internet.
- **Thực hiện:** `backend/app.py`; chạy bằng `python3 backend/app.py`.
- **Phụ thuộc:** Giai đoạn 0.
- **Bàn giao:** `curl http://127.0.0.1:3000` phản hồi 200 (in `Host`, `X-Real-IP`, `X-Forwarded-For`).

### [ ] 2.2. Sinh chứng chỉ self-signed
- **Giải thích:** Không có CA thật, dùng OpenSSL tự ký để bật TLS. Chứng chỉ lưu trong `ssl/` và bị `.gitignore` (không commit khóa riêng tư).
- **Thực hiện:** `scripts/01_generate_ssl.sh`.
- **Phụ thuộc:** 0.2 (openssl).
- **Bàn giao:** `ssl/server.crt`, `ssl/server.key` tồn tại.

### [ ] 2.3. Cấu hình Reverse Proxy + HTTPS
- **Giải thích:** `proxy_pass` chuyển request tới backend; `proxy_set_header Host/X-Real-IP/X-Forwarded-For` giữ thông tin client cho backend. TLS dùng `ssl_certificate`/`ssl_certificate_key`; chuyển hướng HTTP → HTTPS.
- **Thực hiện:** `nginx/conf.d/02_reverse_proxy.conf`.
- **Phụ thuộc:** 2.1, 2.2.
- **Bàn giao:** `curl -k https://app.local` trả về nội dung backend.

### [ ] 2.4. Kiểm thử proxy & HTTPS
- **Thực hiện:** `tests/test_https_proxy.sh` — kiểm tra status 200, header `X-Forwarded-For`, và redirect 301 từ HTTP.
- **Phụ thuộc:** 2.3.
- **Bàn giao:** script pass toàn bộ.

---

## Giai đoạn 3 — Demo 3: Rate Limiting & Benchmark (TV4)

### [ ] 3.1. Cấu hình Rate Limit
- **Giải thích:** `limit_req_zone` định nghĩa vùng đếm theo `$binary_remote_addr`; `burst` cho phép xếp hàng tối đa N request vượt ngưỡng; `nodelay` xử lý ngay phần burst thay vì giữ chậm đều. Khi vượt cả burst, Nginx trả `503`.
- **Thực hiện:** `nginx/conf.d/03_rate_limit.conf` — tạo **vhost riêng `limit.local` (HTTP:80)** để tránh trùng `server_name` với `app.local` và để `ab` chạy được (không qua HTTPS/redirect). Thông số chốt: `rate=10r/s burst=20 nodelay` (xem [`interfaces.md`](./interfaces.md) mục 6).
- **Phụ thuộc:** Giai đoạn 0 (không phụ thuộc Demo 2).
- **Bàn giao:** cấu hình có `limit_req_zone`, `burst`, `nodelay`; `curl http://limit.local` trả 200 khi tải thấp.

### [ ] 3.2. Script benchmark 100 request đồng thời
- **Giải thích:** `ab -n 100 -c 100 http://limit.local/` tạo tải đồng thời kích hoạt rate limit; cần thống kê số mã 200 (thành công) và 503 (bị chặn).
- **Thực hiện:** `scripts/03_run_benchmark.sh` (đích HTTP `limit.local`, xem [`interfaces.md`](./interfaces.md) mục 6–7).
- **Phụ thuộc:** 3.1.
- **Bàn giao:** output `ab` có `Complete requests`, `Non-2xx responses` (~79), `Requests per second`.

### [ ] 3.3. Trích log 503
- **Giải thích:** `error.log` ghi `limiting requests ...` kèm zone; `access.log` ghi status 503. Trích ra để đưa vào báo cáo.
- **Thực hiện:** lưu vào `docs/logs/rate_limit_503.log`.
- **Phụ thuộc:** 3.2.
- **Bàn giao:** file log chứa dòng 503 + dòng limit tương ứng.

---

## Giai đoạn 4 — Demo 4: Troubleshooting backend down (TV3 & TV5)

### [ ] 4.1. Trang lỗi tùy chỉnh
- **Giải thích:** `error_page 502 503 504 /50x.html;` thay trang lỗi mặc định bằng trang thân thiện, không lộ thông tin hệ thống.
- **Thực hiện:** `www/error_pages/custom_50x.html` + khai báo trong `02_reverse_proxy.conf`:
  ```nginx
  error_page 502 503 504 /50x.html;
  location = /50x.html { alias /usr/share/nginx/error_pages/custom_50x.html; internal; }
  ```
  (xem [`interfaces.md`](./interfaces.md) mục 4).
- **Phụ thuộc:** 2.3.
- **Bàn giao:** file HTML + `curl -k https://app.local/50x.html` trả 404 do `internal` (truy cập gián tiếp qua lỗi mới hiện).

### [ ] 4.2. Kịch bản gây lỗi 502
- **Giải thích:** Dừng backend khiến Nginx không kết nối được upstream → trả `502 Bad Gateway`. Đây là minh chứng cụ thể cho Demo 4.
- **Thực hiện:** `tests/test_troubleshooting.sh` — dừng app, `curl -k https://app.local`, khởi động lại.
- **Phụ thuộc:** 4.1.
- **Bàn giao:** script mô phỏng dừng/khởi động backend.

### [ ] 4.3. Trích log 502 + chụp màn hình
- **Giải thích:** `error.log` ghi `connect() failed (111: Connection refused)` — đối chiếu với ảnh trang lỗi tùy chỉnh trên trình duyệt.
- **Thực hiện:** lưu `docs/logs/backend_down_502.log` và ảnh trong `docs/screenshots/`.
- **Phụ thuộc:** 4.2.
- **Bàn giao:** 1 file log + ảnh trang lỗi.

---

## Giai đoạn 5 — Phân tích log & lý thuyết (TV5 & cả nhóm)

### [ ] 5.1. Script thu thập log
- **Giải thích:** `access.log`/`error.log` nằm ở `/var/log/nginx/`; script trích các dòng cần thiết vào `docs/logs/` để đóng gói minh chứng cùng repo.
- **Thực hiện:** `scripts/04_collect_logs.sh`.
- **Phụ thuộc:** Giai đoạn 3 & 4.
- **Bàn giao:** script copy/`grep` log vào `docs/logs/`.

### [ ] 5.2. Viết phần lý thuyết A
- **Giải thích:** Mỗi thành viên viết 1 mục, ghép vào `docs/report.md`:
  - Vai trò Web Server vs Reverse Proxy; vì sao không expose backend. *(TV3)*
  - Event-driven của Nginx vs Process/Thread của Apache; hệ quả tải đồng thời. *(TV1)*
  - Cơ chế Server Block. *(TV2)*
  - Vị trí/cấu trúc `access.log`, `error.log`; phân biệt 502/503/504. *(TV4–TV5)*
- **Phụ thuộc:** có thể viết `// song song` từ Giai đoạn 1.
- **Bàn giao:** `docs/report.md` đủ 4 mục.

### [ ] 5.3. Tổng hợp & slide thuyết trình
- **Giải thích:** Gom kết quả 4 demo, biểu đồ benchmark, ảnh chụp, log; chuẩn hóa thành slide.
- **Phụ thuộc:** Giai đoạn 3, 4, 5.2.
- **Bàn giao:** slide + demo chạy live trước lớp.

---

## Ma trận phân công tổng hợp

| Giai đoạn | Task | Phụ trách |
|-----------|------|-----------|
| 0 | Hạ tầng, deploy, `nginx.conf` | TV1 |
| 1 | Virtual Host | TV2 |
| 2 | Backend, HTTPS, Reverse Proxy | TV3 |
| 3 | Rate Limit & Benchmark | TV4 |
| 4 | Troubleshooting & trang lỗi | TV3, TV5 |
| 5 | Log, lý thuyết, báo cáo | TV5 + cả nhóm |

---

## Sơ đồ làm việc & Timeline

> Tóm tắt điều phối: **ai làm song song, ai chờ ai, tiến độ theo ngày**.

### Điều phối & phụ thuộc

1. **Giai đoạn 0 là tiên quyết chung** — chưa xong môi trường (swap, nginx, hosts, deploy) thì mọi demo chưa chạy được.
2. Sau Giai đoạn 0 có **3 track độc lập chạy song song**:
   - **Track A — Demo 1 (TV2):** thuần Nginx + file tĩnh.
   - **Track B — Demo 2 (TV3):** backend + cert + reverse proxy.
   - **Track C — Demo 3 (TV4):** rate limit trên `limit.local`, chỉ cần Nginx.
3. **TV5** chuẩn bị trang lỗi + khung báo cáo **song song**, nhưng log/ảnh 502 **chờ TV3** xong Demo 2.
4. **Demo 4 phụ thuộc Demo 2** (phải có proxy mới tắt backend sinh 502).
5. **TV1** xong hạ tầng thì chuyển sang hỗ trợ deploy + review.

| Công việc | Phụ thuộc vào | Người chờ |
|-----------|---------------|-----------|
| Demo 1 (TV2) | Giai đoạn 0 | TV2 |
| Demo 2 (TV3) | Giai đoạn 0 | TV3 |
| Demo 3 (TV4) | Giai đoạn 0 | TV4 |
| Trang lỗi (TV5) | — | TV5 |
| Demo 4 (TV3+TV5) | **Demo 2** | TV3, TV5 |
| Thu log (TV5) | Demo 3 + Demo 4 | TV5 |
| Báo cáo/slide | Tất cả demo | TV5 + nhóm |

**Ai song song với ai:** TV2/TV3/TV4 chạy độc lập sau Giai đoạn 0; TV5 song song có điều kiện; TV1 điều phối.
**Review chéo:** TV1 ↔ TV2, TV3 ↔ TV4, TV5 review tổng.
**Dùng VM chung:** chỉ **một người deploy/reload Nginx tại một thời điểm**.

### Timeline theo ngày

| Ngày | TV1 | TV2 | TV3 | TV4 | TV5 |
|------|-----|-----|-----|-----|-----|
| **1** | Setup, hosts, `nginx.conf`, deploy (0.1–0.5) | Đọc `interfaces.md`, chuẩn bị HTML | Chuẩn bị `app.py`*, cert | Đọc spec rate limit | Chuẩn bị `custom_50x.html`, khung report |
| **2** | Hoàn tất deploy, hỗ trợ chung | Demo 1: config + test + ảnh | Demo 2: cert + proxy + HTTPS + test | Demo 3: config rate limit | Viết lý thuyết A (phần mình) |
| **3** | Review TV2 | **CHỐT Demo 1** + review TV3 | **CHỐT Demo 2**, bắt đầu Demo 4 | Benchmark `ab`, trích log 503 | Viết lý thuyết A (tiếp) |
| **4** | Hỗ trợ tích hợp | Hỗ trợ tích hợp | **CHỐT Demo 4** (502) | **CHỐT Demo 3**, review TV4 | Trích log 502, chụp ảnh trang lỗi |
| **5** | Review tổng, dry-run | Dry-run | Dry-run | Dry-run | **CHỐT báo cáo + slide** |

\* `backend/app.py` đã dựng sẵn như scaffolding — TV3 chỉ cần chạy/kiểm chứng và **tập trung vào 2.2–2.4**.

```
Ngày:      1        2        3        4        5
TV1   [M0 setup─────][deploy/review────][review──────]
TV2   [chuẩn bị──────][── Demo 1 ──────][review TV3───]
TV3   [app*+cert─────][── Demo 2 ──────][Demo 4───────]
TV4   [đọc spec──────][── Demo 3 ──────][log 503──────]
TV5   [error+report──][lý thuyết A──────][── Demo 4 ───][report+slide]
```

### Đường găng (critical path)

```
M0 (hạ tầng) ──> Demo 2 (TV3) ──> Demo 4 (TV3+TV5) ──> Báo cáo/slide ──> Nộp
```

- **Trên đường găng:** TV1 (M0) → TV3 (Demo 2, Demo 4) → TV5 (minh chứng, báo cáo).
- **Không trên đường găng:** Demo 1 (TV2), Demo 3 (TV4) — phải xong trước ngày 5.

### Mốc đồng bộ (milestones)

| Mốc | Khi nào | Điều kiện đạt | Người xác nhận |
|-----|---------|---------------|----------------|
| **M0** | Cuối ngày 1 | `nginx -t` pass, hosts resolve, deploy chạy | TV1 |
| **M1** | Đầu ngày 2 | Cả 3 track khởi động được | Cả nhóm |
| **M2** | Cuối ngày 2 | Demo 1, 2, 3 có bản chạy thử | TV2/TV3/TV4 |
| **M3** | Cuối ngày 3 | Demo 2 hoàn tất → mở Demo 4 | TV3 |
| **M4** | Cuối ngày 4 | Demo 4 (502) + log/ảnh đầy đủ | TV3 + TV5 |
| **M5** | Cuối ngày 5 | Report + slide + dry-run live | TV5 + cả nhóm |

### Trạng thái hiện tại (scaffolding đã có)

- **TV1:** Giai đoạn 0 đã dựng xong ở mức code — `scripts/00_setup_vm.sh` (0.1–0.3), `nginx/nginx.conf` (0.4), `scripts/02_deploy_config.sh` (0.5). Còn lại: **chạy trên VM thật** và tick bàn giao.
- **TV3:** `backend/app.py` (task 2.1) → còn 2.2 (cert), 2.3 (proxy), 2.4 (test).
- **TV5:** bộ `docs/*` nền → còn `report.md`, log, ảnh.

> Chứng thực: `nginx.conf` + `02_deploy_config.sh` đã kiểm tra bằng `nginx -t` trên Ubuntu 22.04 / nginx 1.18; deploy idempotent.
