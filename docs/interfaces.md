# Giao diện chung (Interfaces) — Chốt trước khi code

> Lab CSC-11117 — Linux OS And Applications
> **Mọi thành viên phải tuân theo tài liệu này.** Muốn đổi bất kỳ giá trị nào dưới đây
> phải báo nhóm và cập nhật file này trước.
> Xem phân công [`tasks.md`](./tasks.md), vai trò file [`files.md`](./files.md).

---

## 1. Tên miền & cổng (dùng chung 1 IP `127.0.0.1`)

| Domain | Cổng | Giao thức | Phục vụ | Demo |
|--------|------|-----------|---------|------|
| `site1.local` | 80 | HTTP | Static `www/site1/` | Demo 1 |
| `site2.local` | 80 | HTTP | Static `www/site2/` | Demo 1 |
| `app.local` | 443 | HTTPS | Reverse proxy → `127.0.0.1:3000` | Demo 2, Demo 4 |
| `app.local` | 80 | HTTP | **Redirect 301 → HTTPS** | Demo 2 |
| `limit.local` | 80 | HTTP | Static + rate limit (chạy được với `ab`) | Demo 3 |

Khai báo trong `/etc/hosts` (script `00_setup_vm.sh` tự thêm):

```
127.0.0.1 site1.local site2.local app.local limit.local
```

**Vì sao tách `limit.local`?**
- Tránh xung đột `server_name` với `app.local` (nếu 2 file cùng khai báo `server_name app.local`, `nginx -t` sẽ lỗi).
- Chạy trên **HTTP** vì `ab` không hỗ trợ HTTPS, và `app.local` HTTP bị redirect 301 nên không benchmark được.

> **Demo chạy trên VM:** trình duyệt/`curl` chạy ngay trong VM nên chỉ cần `/etc/hosts` nội bộ như trên —
> **không** cần sửa hosts hay port-forward ở máy host. Xem [`environment.md`](./environment.md) mục 7.

## 2. Backend mock

- Viết bằng **Python 3 (thư viện chuẩn, không dependency)**, chạy bằng `python3 backend/app.py`.
- Bind **`127.0.0.1:3000`** (chỉ loopback — backend không lộ ra ngoài).
- `backend/app.py` trả nội dung phân biệt được (in `Host`, `X-Forwarded-For`, `X-Real-IP` để chứng minh proxy hoạt động).

## 3. Đường dẫn sau khi deploy

| Repo | Đích trên hệ thống |
|------|--------------------|
| `nginx/conf.d/*.conf` | `/etc/nginx/conf.d/` |
| `nginx/nginx.conf` | `/etc/nginx/nginx.conf` |
| `www/site1/`, `www/site2/` | `/usr/share/nginx/html/site1`, `.../site2` |
| `www/error_pages/` | `/usr/share/nginx/error_pages/` |
| `ssl/server.crt`, `ssl/server.key` | `/etc/nginx/ssl/` |

- Script `02_deploy_config.sh` **phải vô hiệu hoá site mặc định** để port 80 nhường cho các vhost:
  ```bash
  sudo rm -f /etc/nginx/sites-enabled/default
  ```
- Sau khi copy: `nginx -t` → `systemctl reload nginx`.

## 4. Trang lỗi tùy chỉnh (Demo 4)

- File nguồn: `www/error_pages/custom_50x.html` (giữ nguyên tên).
- Khai báo trong `02_reverse_proxy.conf`:
  ```nginx
  error_page 502 503 504 /50x.html;
  location = /50x.html {
      alias /usr/share/nginx/error_pages/custom_50x.html;
      internal;
  }
  ```
- `location = /50x.html` (exact match) + `internal` → người dùng không truy cập trực tiếp được.

## 5. Chứng chỉ self-signed (Demo 2)

- Vị trí: `ssl/server.crt`, `ssl/server.key` (bị `.gitignore`, không commit).
- **Có SAN** để trình duyệt/`curl` chấp nhận đúng tên miền:
  ```
  subjectAltName = DNS:app.local, DNS:localhost, IP:127.0.0.1
  ```
- Config Nginx:
  ```nginx
  ssl_certificate     /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.key;
  ```

## 6. Rate limit (Demo 3)

- Đặt trong `http` context (file `conf.d` được include trong `http` nên hợp lệ):
  ```nginx
  limit_req_zone $binary_remote_addr zone=perip:10m rate=10r/s;
  ```
- Áp dụng trong `server limit.local`:
  ```nginx
  limit_req zone=perip burst=20 nodelay;
  ```
- **Thông số chốt:** `rate=10r/s`, `burst=20`, `nodelay`.
- Hệ quả với `ab -n 100 -c 100` (tất cả từ 1 IP): khoảng **~21 request 200** (1 + 20 burst) và **~79 request 503**.
  > Số liệu có thể xê dịch đôi chút; mục tiêu là **có cả 200 lẫn 503**.

## 7. Lệnh kiểm thử chuẩn

```bash
# Demo 1
curl -H "Host: site1.local" http://127.0.0.1/
curl -H "Host: site2.local" http://127.0.0.1/

# Demo 2 (HTTP phải redirect 301, HTTPS trả 200)
curl -I  http://app.local/
curl -k https://app.local/

# Demo 3 (benchmark trên HTTP)
ab -n 100 -c 100 http://limit.local/

# Demo 4 (dừng backend → 502)
curl -k https://app.local/     # sau khi tắt backend
```

## 8. Log

- `access.log`: `/var/log/nginx/access.log` — cần chứa `$request_time`, `$upstream_response_time` (cấu hình ở `nginx.conf`, Task 0.4).
- `error.log`: `/var/log/nginx/error.log` — chứa `limiting requests` (503) và `connect() failed ... Connection refused` (502).
- `scripts/04_collect_logs.sh` trích về `docs/logs/`.
- ⚠️ Không đặt `access_log` riêng trong `conf.d` nếu muốn giữ `main_ext`; nếu buộc phải đặt, ghi rõ format: `access_log /var/log/nginx/<file>.log main_ext;`.

## 9. Biến môi trường / sự phụ thuộc

- Các script phải dùng **cùng** giá trị: port `3000`, domain như mục 1, đường dẫn như mục 3.
- Không hard-code IP khác `127.0.0.1` cho domain `.local`.
