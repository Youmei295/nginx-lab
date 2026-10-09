# Checklist minh chứng (Evidence Checklist)

> Lab CSC-11117 — Linux OS And Applications
> Dùng để tự kiểm tra trước khi nộp. `[ ]` chưa có — `[x]` đã lấy.
> Minh chứng lưu tại `docs/logs/` và `docs/screenshots/`, kết quả điền vào `docs/report.md`.

---

## Chung

- [ ] `README.md` có phân công và quick-start.
- [ ] `docs/report.md` điền đủ Phần A (4 mục lý thuyết) + Phần B (4 demo).
- [ ] Tất cả file cấu hình đã merge vào `main` và `nginx -t` pass.
- [ ] Không có secret (`ssl/server.key`) bị commit: `git ls-files | grep -i key` (kết quả rỗng).

## Demo 1 — Virtual Host

- [ ] `curl -H "Host: site1.local" http://127.0.0.1/` → nội dung Site 1.
- [ ] `curl -H "Host: site2.local" http://127.0.0.1/` → nội dung Site 2.
- [ ] Ảnh trình duyệt `http://site1.local` và `http://site2.local` → `docs/screenshots/demo1_site1.png`, `demo1_site2.png`.

## Demo 2 — Reverse Proxy & HTTPS

- [ ] `curl -I http://app.local/` → `301` (redirect sang HTTPS).
- [ ] `curl -k https://app.local/` → `200` + nội dung backend.
- [ ] Chứng minh header tới backend có `X-Forwarded-For` / `X-Real-IP`.
- [ ] `openssl s_client -connect app.local:443 -servername app.local` hiển thị cert có SAN `app.local`.
- [ ] Ảnh trình duyệt HTTPS (kèm cảnh báo cert self-signed) → `docs/screenshots/demo2_https.png`.

## Demo 3 — Rate Limiting & Benchmark

- [ ] `scripts/03_run_benchmark.sh` chạy `ab -n 100 -c 100 http://limit.local/`.
- [ ] Output `ab` có `Complete requests: 100`, `Non-2xx responses` (~79), `Requests per second`.
- [ ] Có cả mã 200 lẫn 503 (chứng minh rate limit hoạt động, không chặn sạch).
- [ ] Log 503 + dòng `limiting requests` → `docs/logs/rate_limit_503.log`.
- [ ] Ảnh kết quả `ab` → `docs/screenshots/demo3_benchmark.png`.

## Demo 4 — Troubleshooting

- [ ] `tests/test_troubleshooting.sh` dừng backend → `curl -k https://app.local/` trả `502`.
- [ ] Trang lỗi tùy chỉnh hiển thị (không phải trang mặc định của Nginx).
- [ ] Log `connect() failed (111: Connection refused)` → `docs/logs/backend_down_502.log`.
- [ ] Ảnh trang lỗi tùy chỉnh trên trình duyệt → `docs/screenshots/demo4_error_page.png`.

## Phần lý thuyết

- [ ] A.1 Vai trò Web Server / Reverse Proxy + lý do không expose backend.
- [ ] A.2 Event-driven Nginx vs Process/Thread Apache.
- [ ] A.3 Cơ chế Server Block.
- [ ] A.4 access.log/error.log + phân biệt 502/503/504.

## Trình bày

- [ ] Slide thuyết trình.
- [ ] Demo chạy live được trên VM Ubuntu 22.04.
- [ ] Có phương án dự phòng nếu backend/VM lỗi khi demo (ảnh + log đã lưu).
