# Giai đoạn 3 — Rate Limiting & Benchmark

> Trạng thái: ⬜ **chưa viết**. Nhiệm vụ: **Task 3.1–3.3** trong [`../tasks.md`](../tasks.md). Phụ trách: **TV4**.
> Xem quy ước viết tại [`README.md`](./README.md). Tham khảo mẫu: [`stage-0-infra.md`](./stage-0-infra.md).

## 1. Mục tiêu

Chứng minh Nginx có thể **giới hạn tải** từ một client và **đo lường** việc đó:

1. Giới hạn request theo IP trên vhost `limit.local` (`rate=10r/s`, `burst=20`, `nodelay`).
2. Benchmark **100 request đồng thời** bằng `ab`, thống kê số request thành công (200) và bị chặn (503).
3. Có test tự động và log minh chứng (`limiting requests`, mã 503).

Demo 3 chỉ phụ thuộc [Giai đoạn 0](./stage-0-infra.md) (Nginx, `ab`, `/etc/hosts`), **không** phụ thuộc Demo 2 (backend/SSL).

## 2. File liên quan

| File | Vai trò | Task |
|------|---------|------|
| `nginx/conf.d/03_rate_limit.conf` | Vhost `limit.local` + `limit_req_zone` + `limit_req` | 3.1 |
| `scripts/03_run_benchmark.sh` | Chạy `ab -n 100 -c 100`, in thống kê 200 vs 503 | 3.2 |
| `tests/test_rate_limit.sh` | Test tự động: tải thấp → 200, tải vượt ngưỡng → có 503 | 3.3 |
| `docs/logs/rate_limit_503.log` | Minh chứng: dòng `limiting requests` + dòng 503 | 3.3 |
| `docs/screenshots/demo3_benchmark.png` | Ảnh kết quả benchmark | 3.3 |
| `docs/interfaces.md` | Chốt thông số (mục 6), URL benchmark (mục 7) | Quản lý chung |

## 3. Bức tranh tổng thể

```
ab -n 100 -c 100 http://limit.local/      (100 request cùng lúc, cùng IP 127.0.0.1)
              │
              ▼
Nginx — server limit.local:80 ── limit_req zone=perip burst=20 nodelay
              │
              ├─ 21 request đầu  ──────────► 200 (index.html)
              └─ 79 request còn lại ───────► 503 + error.log: "limiting requests, excess: ... by zone "perip""
```

## 4. Nguyên lý cốt lõi (vì sao, không chỉ làm gì)

| Nguyên lý | Giải thích |
|-----------|-----------|
| **Rate limiting** | Giới hạn số request một client được gửi trong một khoảng thời gian, để chống spam/quá tải. Request bị chặn nhận **HTTP 503**. |
| **Leaky bucket** | Nginx dùng thuật toán "xô thủng": request đổ vào xô, xô rò ra với tốc độ cố định. Xô đầy thì request mới bị từ chối. |
| **`rate=10r/s`** | Tốc độ bền vững: 10 request/giây, tức **100 ms** mới nhận thêm 1 request. |
| **`burst=20`** | Cho phép vượt tạm thời tối đa 20 request dư thay vì từ chối ngay. |
| **`nodelay`** | Request trong burst được xử lý **ngay**, không bị giữ lại chờ từng 100 ms. |
| **Zone dùng chung** | `limit_req_zone` tạo vùng nhớ chia sẻ giữa các worker, nên đếm đúng dù `worker_processes auto`. |
| **Khóa là IP** | `$binary_remote_addr` đếm riêng cho từng IP client, dạng nhị phân nên gọn hơn dạng chuỗi. |
| **Vì sao chạy trên HTTP, không qua proxy** | `ab` không hỗ trợ HTTPS, và `app.local` cổng 80 đã bị redirect 301 sang HTTPS ([Stage 2](./stage-2-reverse-proxy.md)). Nên dùng vhost riêng `limit.local` (HTTP:80), phục vụ file tĩnh, không cần backend. |

**Vì sao ra 21 × 200 và 79 × 503?** `ab -c 100` bắn cả 100 request trong vài mili-giây, ngắn hơn nhiều so với chu kỳ 100 ms của `rate=10r/s`, nên xô gần như không kịp "rò" thêm. Request đầu tiên đi qua (1), `burst=20` nhận thêm 20 request dư và xử lý ngay nhờ `nodelay`, vậy 1 + 20 = **21**. 79 request còn lại vượt burst nên bị 503. Số này có thể xê dịch nhẹ nếu máy chậm (cứ 100 ms xô nhận thêm 1 request); điều cần đạt là **có cả 200 lẫn 503**.

## 5. Chi tiết code/directive

### 5.1. `nginx/conf.d/03_rate_limit.conf`

```nginx
limit_req_zone $binary_remote_addr zone=perip:10m rate=10r/s;

server {
    listen 80;
    server_name limit.local;

    root /usr/share/nginx/html;
    index index.html;

    limit_req zone=perip burst=20 nodelay;
}
```

| Directive | Ý nghĩa |
|-----------|---------|
| `limit_req_zone ... zone=perip:10m rate=10r/s` | **Khai báo** vùng đếm tên `perip`, 10 MB, theo IP, tốc độ 10 request/giây. Chỉ hợp lệ ở cấp `http` (file trong `conf.d/` được include vào `http`), **không** đặt trong `server {}`. |
| `listen 80; server_name limit.local;` | Chỉ nhận request có `Host: limit.local`. Phải khác `site1.local`, `site2.local`, `app.local`. |
| `root ...; index index.html;` | Phục vụ trang tĩnh có sẵn; nội dung không quan trọng, chỉ cần trả 200. |
| `limit_req zone=perip burst=20 nodelay;` | **Áp dụng** giới hạn lên server: dùng zone `perip`, cho dư 20 request, xử lý ngay. |

Thông số `perip`, `10r/s`, `burst=20`, `nodelay` đã **chốt** trong [`../interfaces.md`](../interfaces.md) mục 6; không tự đổi. Không thêm `access_log` riêng để log vẫn theo định dạng `main_ext` ([Stage 0](./stage-0-infra.md)).

### 5.2. `scripts/03_run_benchmark.sh`

```bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://limit.local/}"
REQUESTS="${REQUESTS:-100}"
CONCURRENCY="${CONCURRENCY:-100}"

sleep 3
ab -n "${REQUESTS}" -c "${CONCURRENCY}" "${TARGET_URL}" >"${OUT}" 2>&1

COMPLETE="$(awk '/^Complete requests:/ {print $3}' "${OUT}")"
NON2XX="$(awk '/^Non-2xx responses:/ {print $3}' "${OUT}")"
SUCCESS=$((COMPLETE - NON2XX))
```

| Đoạn | Giải thích |
|------|-----------|
| `set -euo pipefail` | Chế độ an toàn của lab: lỗi thì dừng, tránh "thành công giả". |
| Giá trị mặc định qua `${VAR:-...}` | Mặc định đúng `interfaces.md`, nhưng ghi đè được bằng biến môi trường. |
| `sleep 3` | Chờ bộ đếm rate limit hồi phục sau lần chạy trước; không có thì lần chạy liền kề gần như toàn 503. |
| `mktemp` + `trap ... EXIT` | Lưu output `ab` vào file tạm và tự xoá khi kết thúc. |
| `awk` tách `Complete requests`, `Non-2xx responses` | Lấy số liệu từ output của `ab`. |
| `SUCCESS = COMPLETE - NON2XX` | Số 200 = tổng trừ số response không phải 2xx. |
| Khối đọc `access.log` | Lọc User-Agent `ApacheBench` để đếm **chính xác theo mã trạng thái** (cần `sudo` để đọc log). |

Script kiểm tra điều kiện trước khi chạy (`ab` đã cài, `limit.local` resolve được) và báo lỗi dễ hiểu nếu thiếu. Chạy lại nhiều lần vẫn an toàn (idempotent).

### 5.3. `tests/test_rate_limit.sh`

- **Test 1:** chờ 3 giây rồi gửi **1 request**, phải trả `200` (tải thấp không bị chặn).
- **Test 2:** chờ 3 giây rồi gửi **60 request liên tiếp** bằng `curl`, phải có **cả 200 lẫn 503**.
- Thoát với **exit 0** khi tất cả pass, **exit 1** khi có test fail.

Vòng lặp `curl` chạy tuần tự nên kéo dài hơn `ab`; trong thời gian đó xô rò thêm vài request, vì vậy số 200 có thể nhiều hơn 21. Test chỉ yêu cầu có cả hai loại mã.

## 6. Chạy & kiểm chứng

```bash
# 1) Deploy cấu hình (Stage 0) rồi kiểm tra
bash scripts/02_deploy_config.sh
sudo nginx -t

# 2) Tải thấp phải trả 200
curl -i http://limit.local/

# 3) Benchmark (sudo để script đọc được access.log)
sudo bash scripts/03_run_benchmark.sh

# 4) Test tự động
bash tests/test_rate_limit.sh; echo "exit code: $?"
```

**Kết quả mong đợi:**

| Lệnh | Mong đợi |
|------|----------|
| `sudo nginx -t` | `syntax is ok` / `test is successful` |
| `curl -i http://limit.local/` | `HTTP/1.1 200 OK` |
| `03_run_benchmark.sh` | `Complete requests: 100`, `Non-2xx responses` ≈ 79, có cả 200 lẫn 503 |
| `test_rate_limit.sh` | `exit code: 0` |

**Kết quả thực tế** (Nginx 1.18.0, ảnh [`demo3_benchmark.png`](../screenshots/demo3_benchmark.png)):

| Chỉ số | Giá trị |
|--------|---------|
| Complete requests | 100 |
| Non-2xx responses | 79 |
| Requests per second | 7633.01 |
| Thống kê 200 / 503 (từ `access.log`) | **21 / 79** |

Log minh chứng ([`rate_limit_503.log`](../logs/rate_limit_503.log)):

```
# error.log — Nginx chủ động chặn do rate limit
2026/10/15 08:05:46 [error] 711#711: *59 limiting requests, excess: 20.880 by zone "perip", client: 127.0.0.1, server: limit.local, request: "GET / HTTP/1.0", host: "limit.local"

# access.log — client nhận 503
127.0.0.1 - - [15/Oct/2026:08:05:46 +0000] "GET / HTTP/1.0" 503 206 "-" "ApacheBench/2.3" rt=0.000 urt=-
```

- `excess: 20.880` gần bằng `burst=20`: hàng đợi burst đã đầy.
- `503 206`: body trang 503 dài 206 byte; `urt=-` vì request bị chặn ngay tại Nginx, không có upstream.
- Kiểm tra chéo: 21 × 612 + 79 × 206 = 29126 byte, đúng bằng `HTML transferred` của `ab`.

> **Kết quả chạy `tests/test_rate_limit.sh`**:
== Test 1: tải thấp (1 request) phải trả 200 ==
[PASS] Tải thấp trả 200
== Test 2: 60 request liên tiếp phải có 503 ==
   200: 24   503: 36
[PASS] Có 36 request bị chặn 503
[PASS] Có 24 request thành công (burst cho phép)
exit code: 0

## 7. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|-------------|-------------|-------|
| `ab` ra **toàn 200** (không có dòng `Non-2xx responses`) | (1) Gọi `http://127.0.0.1/` thay vì `limit.local`, request rơi vào vhost mặc định không có rate limit. (2) Cấu hình chưa deploy/reload (có thể `nginx -t` đang lỗi ở file của người khác). (3) Thiếu dòng `limit_req` | Dùng đúng `http://limit.local/`. Chạy `bash scripts/02_deploy_config.sh`, rồi `sudo nginx -T \| grep limit_req` để xác nhận Nginx đã nạp |
| `ab` ra **gần như toàn 503** | Chạy benchmark liên tiếp quá nhanh, bộ đếm chưa kịp hồi | Chờ ≥ 3–4 giây giữa hai lần chạy (script đã `sleep 3`) |
| `nginx -t`: `"limit_req_zone" directive is not allowed here` | Đặt `limit_req_zone` bên trong `server {}` | Đưa ra ngoài `server`, ở cấp `http` |
| `nginx -t`: `zero size shared memory zone "perip"` | Dùng `limit_req zone=perip` nhưng thiếu `limit_req_zone`, hoặc tên zone hai nơi không khớp | Khai báo đủ và giữ tên giống hệt |
| `nginx -t`: `directive ... is not terminated by ";"` | Thiếu dấu `;` | Thêm `;` cuối dòng |
| `ab: invalid URL` | Viết `http://limit.local` thiếu dấu `/` cuối | Luôn viết `http://limit.local/` |
| `Failed requests: 79` khiến lo lắng | `ab` coi response có độ dài body khác response đầu là "failed (Length)"; trang 503 (206 byte) ngắn hơn trang 200 (612 byte) | Không phải lỗi kết nối. Dòng `(Connect: 0, Receive: 0, Length: 79, Exceptions: 0)` xác nhận điều đó; đếm request bị chặn bằng `Non-2xx responses` |
| `curl http://limit.local/` trả 403/404 | Thiếu `/usr/share/nginx/html/index.html` | `ls -l /usr/share/nginx/html/`; báo TV1/TV2, không tự sửa phần người khác |
| `curl: (6) Could not resolve host: limit.local` | `/etc/hosts` chưa có `limit.local` | Chạy lại `bash scripts/00_setup_vm.sh` (idempotent) |
| Script không in phần phân rã 200/503 | Không đọc được `access.log` | Chạy bằng `sudo bash scripts/03_run_benchmark.sh` |

> Các thông báo lỗi `nginx -t` và hai hiện tượng "toàn 503", "invalid URL" ở bảng trên đã được tái hiện khi soạn tài liệu, trên Ubuntu 24.04 / nginx 1.24 (khác môi trường chuẩn 22.04 / 1.18 nhưng cùng directive). Kết quả benchmark thật ở mục 6 chạy trên nginx 1.18.0.

## 8. Liên hệ

- **Trước:** [Stage 0 — Hạ tầng](./stage-0-infra.md) cung cấp Nginx, `ab`, `/etc/hosts` (`limit.local`), `log_format main_ext` và script deploy dùng ở đây.
- **Liên quan:** [Stage 2 — Reverse Proxy & HTTPS](./stage-2-reverse-proxy.md) là lý do Demo 3 phải dùng vhost riêng thay vì `app.local`.
- **Sau:** [Stage 5 — Log & Báo cáo](./stage-5-logs-report.md) thu log (gồm dòng `limiting requests`) và tổng hợp vào báo cáo; [Stage 4 — Troubleshooting](./stage-4-troubleshooting.md) dùng cùng cách đọc `error.log` để phân biệt 502 với 503.
- **Báo cáo:** kết quả Demo 3 ở mục B.3 và lý thuyết log ở mục A.4 của [`../report.md`](../report.md).
- Phân công & thứ tự: [`../tasks.md`](../tasks.md); giao diện chung: [`../interfaces.md`](../interfaces.md).
