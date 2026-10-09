# Ghi chú cho AI Agent khi làm việc trên repo

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu này dành cho **AI coding agent** (và thành viên dùng AI) để mọi người
> nhận được kết quả nhất quán, không phá vỡ giao diện chung.
> **AI phải đọc file này trước khi sửa bất cứ thứ gì.**

---

## 1. Thứ tự đọc bắt buộc

Trước khi viết code, AI **phải đọc theo thứ tự**:

1. [`interfaces.md`](./interfaces.md) — **giao diện chung đã chốt** (domain, cổng, đường dẫn, thông số).
2. [`tasks.md`](./tasks.md) — task nào của ai, thứ tự, phụ thuộc.
3. [`files.md`](./files.md) — vai trò từng file.
4. [`collaboration.md`](./collaboration.md) — nhánh, commit, PR, ranh giới file.
5. [`environment.md`](./environment.md) — nền tảng Ubuntu 22.04 và script setup.

Nếu các file này mâu thuẫn: **`interfaces.md` thắng**, sau đó hỏi con người.

## 2. Quy tắc bất di bất dịch

1. **Tuân thủ `interfaces.md` tuyệt đối.** Không tự bịa domain, cổng, đường dẫn, tên zone, thông số rate limit.
2. **Chỉ sửa file thuộc phạm vi thành viên đang làm.** Không đụng file của người khác (xem bảng ở mục 4).
3. **Làm trên nhánh của thành viên**, không commit thẳng `main`. Không tự merge.
4. **Không commit bí mật:** `ssl/server.key`, `.env`, `__pycache__/`, log runtime.
5. **Không đổi interface chung** (domain, port, đường dẫn, tên zone, error page) nếu không được con người xác nhận.
6. **Không xoá/đổi tên/format lại file ngoài phạm vi** — gây nhiễu diff và xung đột.
7. **Mỗi lần sửa phải kiểm chứng** (mục 5) trước khi báo hoàn thành.

## 3. Bối cảnh kỹ thuật cố định

| Hạng mục | Giá trị chốt |
|----------|--------------|
| OS | Ubuntu 22.04 LTS |
| Backend | Python 3 (stdlib), bind `127.0.0.1:3000` |
| Domain | `site1.local`, `site2.local`, `app.local`, `limit.local` |
| app.local | HTTP:80 redirect 301 → HTTPS:443 (reverse proxy) |
| limit.local | HTTP:80 rate limit (`rate=10r/s burst=20 nodelay`) |
| Error page | `error_page 502 503 504 /50x.html;` + `location = /50x.html { alias /usr/share/nginx/error_pages/custom_50x.html; internal; }` |
| Deploy | copy vào `/etc/nginx/conf.d`, `/usr/share/nginx/{html,error_pages}`, `/etc/nginx/ssl`; xoá `sites-enabled/default` |
| Log | `/var/log/nginx/access.log`, `/var/log/nginx/error.log` |

- **Không** tạo vhost trùng `server_name` (ví dụ đừng thêm `server_name app.local` vào `03_rate_limit.conf`).
- Bash script: `#!/usr/bin/env bash`, `set -euo pipefail`, **idempotent**.
- Không thêm comment thừa; ưu tiên code rõ ràng.

## 4. Ranh giới file theo thành viên

| TV | Được sửa |
|----|----------|
| TV1 | `scripts/00_setup_vm.sh`, `scripts/02_deploy_config.sh`, `nginx/nginx.conf` |
| TV2 | `nginx/conf.d/01_vhost_sites.conf`, `www/site1/`, `www/site2/` |
| TV3 | `nginx/conf.d/02_reverse_proxy.conf`, `backend/`, `scripts/01_generate_ssl.sh` |
| TV4 | `nginx/conf.d/03_rate_limit.conf`, `scripts/03_run_benchmark.sh` |
| TV5 | `www/error_pages/`, `scripts/04_collect_logs.sh`, `docs/` |

- `tests/*.sh` thuộc người làm demo tương ứng; `README.md`, `docs/tasks.md`, `.gitignore` là **file dùng chung** — sửa phải báo nhóm.

## 5. Kiểm chứng bắt buộc trước khi báo xong

- Với config Nginx: `sudo nginx -t` phải báo `syntax is ok`.
- Với bash script: `bash -n <script>` không lỗi.
- Chạy thử script/demo liên quan và dán output thật (không bịa kết quả).
- Nếu không thể chạy (thiếu môi trường), nói rõ "chưa kiểm chứng" thay vì khẳng định đã xong.

## 6. Điều AI KHÔNG được làm

- Không giả định kết quả `curl`/`ab`/log — chỉ dùng output thật.
- Không tự đổi stack backend đã chốt (Python 3 stdlib) sang ngôn ngữ khác.
- Không cài `wrk`/công cụ ngoài danh sách mà không hỏi (lab dùng `ab`).
- Không sửa `/etc/hosts`, `/etc/nginx` trực tiếp trong repo — thay đổi đó thuộc script.
- Không force-push `main`, không tự tạo/merge PR.
- Không bật HTTPS cho `site1/site2`/`limit` trái `interfaces.md`.

## 7. Mẫu prompt cho thành viên

Khi nhờ AI làm một phần việc, nên mở đầu bằng:

```
Bạn đang làm lab Nginx. Hãy đọc:
- docs/interfaces.md (bắt buộc tuân theo)
- docs/tasks.md (mục <task>)
- docs/collaboration.md (ranh giới file)
Tôi là TV<n>. Chỉ sửa file trong phạm vi của tôi.
Task: <mô tả>. Kiểm chứng bằng <nginx -t / bash -n / test nào>.
```

## 8. Nơi ghi lại quyết định

- Thay đổi giao diện chung → cập nhật `docs/interfaces.md` **trước**, rồi mới sửa code.
- Quyết định kỹ thuật mới → ghi vào `docs/report.md` (Phần C) hoặc một mục trong `tasks.md`.
