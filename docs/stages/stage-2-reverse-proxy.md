# Giai đoạn 2 — Reverse Proxy & HTTPS (Demo 2)

> Tài liệu kỹ thuật chi tiết cho **Demo 2 — Reverse Proxy & HTTPS**.
> Nhiệm vụ tương ứng: **Task 2.1 – 2.4** trong [`../tasks.md`](../tasks.md).
> Phụ trách: **TV3**.
> Nhánh làm việc: `nginx/demo2`.
> Tuân thủ tuyệt đối: [`../interfaces.md`](../interfaces.md) và [`../ai-agents.md`](../ai-agents.md).

---

## 1. Mục tiêu giai đoạn

Triển khai hoàn chỉnh tính năng **Reverse Proxy & HTTPS Termination** trên Nginx:

1. **Bảo mật kết nối**: Khách hàng truy cập domain `app.local` bắt buộc qua giao thức HTTPS (cổng 443) bằng chứng chỉ SSL tự ký (self-signed) có hỗ trợ SAN.
2. **Chuyển hướng an toàn**: Mọi request qua HTTP (cổng 80) đến `app.local` được chuyển hướng tự động bằng HTTP Redirect 301 sang HTTPS.
3. **Định tuyến Reverse Proxy**: Nginx nhận request HTTPS tại cổng 443, giải mã SSL (SSL Termination) rồi chuyển tiếp (proxy) an toàn tới backend mock Python chạy nội bộ tại `127.0.0.1:3000`.
4. **Bảo toàn thông tin Client**: Nginx bổ sung đầy đủ các HTTP header cần thiết (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) để ứng dụng backend nhận diện được danh tính thực của client.
5. **Dự phòng lỗi backend (Demo 4)**: Cấu hình sẵn cơ chế bắt lỗi 502/503/504 để điều hướng sang trang lỗi tùy chỉnh `custom_50x.html`.

---

## 2. Danh mục file phụ trách (Ranh giới TV3)

| File | Vai trò | Trạng thái | Task |
|------|---------|------------|------|
| `backend/app.py` | Web server Python stdlib, bind `127.0.0.1:3000`, in headers client | ✅ Hoàn tất & đã kiểm tra | Task 2.1 |
| `scripts/01_generate_ssl.sh` | Bash script sinh cert self-signed có SAN (`app.local`, `localhost`, `127.0.0.1`) | ✅ Hoàn tất & đã chạy sinh cert | Task 2.2 |
| `nginx/conf.d/02_reverse_proxy.conf` | Cấu hình Virtual Host `app.local`: Redirect 80 -> 443, SSL, proxy_pass, custom error page | ✅ Hoàn tất cấu hình | Task 2.3 |
| `tests/test_https_proxy.sh` | Script kiểm thử tự động kiểm tra 301 redirect, 200 HTTPS, header proxy | ✅ Hoàn tất script test | Task 2.4 |
| `docs/stages/stage-2-reverse-proxy.md` | Tài liệu kỹ thuật, kiến trúc & nhật ký thay đổi Demo 2 | ✅ Cập nhật liên tục | TV3 Docs |

> [!IMPORTANT]
> **Ranh giới nghiêm ngặt**: TV3 tuyệt đối không chỉnh sửa các file thuộc TV khác (`nginx.conf`, `01_vhost_sites.conf`, `03_rate_limit.conf`, `www/site1/`, `www/site2/`, `www/error_pages/custom_50x.html`).

---

## 3. Kiến trúc & Luồng xử lý (Architecture & Data Flow)

```
                            [ Client (Browser / curl) ]
                                   │           ▲
                HTTP (port 80)     │           │  301 Moved Permanently
        1. Request http://app.local│           │  Location: https://app.local...
                                   ▼           │
    ┌──────────────────────────────────────────┴─────────────────────────────┐
    │ Nginx (Reverse Proxy & Web Server)                                      │
    │                                                                         │
    │  [ Server Block 1: app.local:80 ]                                       │
    │    └── return 301 https://$host$request_uri;                           │
    │                                                                         │
    │  [ Server Block 2: app.local:443 (SSL/TLS Termination) ]                │
    │    ├── Chứng chỉ: /etc/nginx/ssl/server.crt & server.key                │
    │    ├── 2. Nhận HTTPS request -> Giải mã TLS                             │
    │    ├── 3. Thêm headers (Host, X-Real-IP, X-Forwarded-For)               │
    │    ├── 4. proxy_pass http://127.0.0.1:3000 ─────────────┐               │
    │    │                                                    │               │
    │    └── 5. Bắt lỗi backend (nếu sập): error_page 502/504 │               │
    └─────────────────────────────────────────────────────────┼───────────────┘
                                                              │ Loopback (127.0.0.1)
                                                              ▼ (HTTP plaintext)
                                               ┌─────────────────────────────┐
                                               │ Backend Mock (Python stdlib)│
                                               │ Bind: 127.0.0.1:3000        │
                                               │ Trả về HTTP 200 + Headers   │
                                               └─────────────────────────────┘
```

---

## 4. Các nguyên lý kỹ thuật cốt lõi

### 4.1. Vì sao backend chỉ bind loopback (`127.0.0.1:3000`)?
- **Nguyên lý bảo mật phân lớp (Defense in Depth)**: Ứng dụng backend không được mở trực tiếp ra card mạng ngoài (`0.0.0.0`), tránh bị tấn công trực tiếp vượt qua firewall/reverse proxy.
- **Tập trung hóa an ninh tại Gateway**: Mọi kết nối từ Internet/LAN buộc phải đi qua Nginx để được lọc request, xác thực TLS, ghi log tập trung và rate limit.

### 4.2. SSL/TLS Termination là gì?
- Nginx đảm nhiệm việc bắt tay TLS (handshake), giải mã gói tin mã hóa từ Client và mã hóa gói tin trả về cho Client.
- Giao tiếp giữa Nginx và backend diễn ra qua HTTP nội bộ trên loopback (`127.0.0.1`), giúp giảm tải xử lý mã hóa cho ứng dụng backend và tối ưu hiệu năng.

### 4.3. Tầm quan trọng của các Proxy Header
Khi Nginx đứng giữa làm proxy, kết nối TCP tới backend xuất phát từ chính IP của Nginx (`127.0.0.1`). Nếu không truyền header, backend sẽ mất thông tin client gốc:
- `Host $host`: Giữ nguyên tên miền gốc mà client yêu cầu (cần thiết cho virtual host hoặc multi-tenant backend).
- `X-Real-IP $remote_addr`: Địa chỉ IP thực tế của client gửi kết nối tới Nginx.
- `X-Forwarded-For $proxy_add_x_forwarded_for`: Chuỗi danh sách IP tích lũy qua các proxy (phục vụ audit log và tracking).
- `X-Forwarded-Proto $scheme`: Cho backend biết client truy cập bằng `http` hay `https`.

### 4.4. Tại sao cần SAN (Subject Alternative Name) cho OpenSSL?
- Các trình duyệt hiện đại (Chrome, Firefox, Safari) và thư viện HTTP hiện nay đều từ chối hoặc cảnh báo chứng chỉ SSL chỉ khai báo tên miền trong `Common Name` (CN) mà thiếu trường `subjectAltName` (SAN).
- Khai báo bắt buộc trong script:
  `subjectAltName = DNS:app.local, DNS:localhost, IP:127.0.0.1`

### 4.5. HTTP 301 Permanent Redirect
- Sử dụng mã HTTP 301 (`Moved Permanently`) để thông báo cho client và trình duyệt lưu cache việc chuyển dịch vĩnh viễn từ HTTP sang HTTPS, giúp bảo vệ an toàn ngay từ các lần truy cập sau.

---

## 5. Chi tiết Code & Directive triển khai

### 5.1. Script sinh chứng chỉ SSL tự ký (`scripts/01_generate_ssl.sh`)
- Sử dụng lệnh `openssl req` với tham số `-addext` để bổ sung Subject Alternative Name (SAN).
- Cơ chế **Idempotent**: Kiểm tra `openssl x509 -checkend 86400`, nếu chứng chỉ còn hạn ít nhất 1 ngày thì không ghi đè trừ khi có cờ `--force`.
- Phân quyền nghiêm ngặt: Private key `600` (`chmod 600`), Certificate `644` (`chmod 644`).
- Lưu trữ vào thư mục `ssl/` (đã được cấu hình chặn commit trong `.gitignore`).

### 5.2. Cấu hình Nginx Virtual Host (`nginx/conf.d/02_reverse_proxy.conf`)

```nginx
# 1. HTTP Server Block (Port 80): Chuyển hướng 301 sang HTTPS
server {
    listen 80;
    server_name app.local;
    return 301 https://$host$request_uri;
}

# 2. HTTPS Server Block (Port 443): Reverse Proxy & SSL Termination
server {
    listen 443 ssl;
    server_name app.local;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Trang lỗi 50x (chuẩn bị cho Demo 4)
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        alias /usr/share/nginx/error_pages/custom_50x.html;
        internal;
    }

    # Reverse proxy forward traffic sang backend Python
    location / {
        proxy_pass http://127.0.0.1:3000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
```

### 5.3. Script kiểm thử tự động (`tests/test_https_proxy.sh`)
- Tự động kiểm tra 5 ca kiểm thử:
  1. `curl -I http://app.local` trả về HTTP status `301`.
  2. Header `Location` trỏ đúng URL `https://app.local/...`.
  3. `curl -k https://app.local` trả về HTTP status `200`.
  4. Nội dung phản hồi chứa chuỗi định danh `"Hello from backend (Python)"`.
  5. Các header `Host`, `X-Forwarded-For`, `X-Real-IP` hiển thị chính xác trong body phản hồi.

---

## 6. Hướng dẫn chạy & Kiểm chứng trên hệ thống

Khi chạy trong môi trường máy ảo Ubuntu 22.04:

### Bước 1: Sinh chứng chỉ SSL (đã hoàn thành)
```bash
bash scripts/01_generate_ssl.sh
```

### Bước 2: Deploy cấu hình vào hệ thống
*(Lưu ý: Cần quyền `sudo` để copy file vào `/etc/nginx/` và reload Nginx)*
```bash
sudo bash scripts/02_deploy_config.sh
```
Lệnh này sẽ tự động:
- Xóa site mặc định `/etc/nginx/sites-enabled/default`.
- Copy `02_reverse_proxy.conf` vào `/etc/nginx/conf.d/`.
- Copy cert `server.crt` và key `server.key` vào `/etc/nginx/ssl/`.
- Chạy `nginx -t` kiểm tra cú pháp và `systemctl reload nginx`.

### Bước 3: Khởi động Mock Backend
Mở một terminal riêng (hoặc chạy nền):
```bash
python3 backend/app.py
```

### Bước 4: Chạy test suite nghiệm thu Demo 2
```bash
bash tests/test_https_proxy.sh
```

---

## 7. Lỗi thường gặp & Cách xử lý

1. **`curl: (60) SSL certificate problem: self-signed certificate`**:
   - *Nguyên nhân*: Chứng chỉ tự ký chưa được hệ thống CA công nhận.
   - *Cách khắc phục*: Dùng cờ `-k` hoặc `--insecure` khi kiểm thử bằng curl: `curl -k https://app.local/`.
2. **`curl: (6) Could not resolve host: app.local`**:
   - *Nguyên nhân*: Chưa khai báo `app.local` trong `/etc/hosts`.
   - *Cách khắc phục*: Thêm dòng `127.0.0.1 app.local` vào `/etc/hosts` (hoặc chạy `scripts/00_setup_vm.sh`).
3. **HTTP 502 Bad Gateway**:
   - *Nguyên nhân*: Nginx đang chạy nhưng Backend Python tại `127.0.0.1:3000` chưa được bật.
   - *Cách khắc phục*: Khởi động `python3 backend/app.py`.

---

## 8. Nhật ký thay đổi & Lưu vết (Change Log)

| Thời gian | Bước | File thao tác | Tóm tắt thay đổi | Kết quả kiểm chứng |
|-----------|------|---------------|------------------|-------------------|
| 2026-10-13 18:18 | Khởi tạo | `docs/stages/stage-2-reverse-proxy.md` | Viết tài liệu Overview toàn diện cho Demo 2 | Đạt chuẩn cấu trúc repo |
| 2026-10-13 18:20 | Bước 1 | `backend/app.py` | Kiểm tra cú pháp Python và cấp quyền thực thi (`chmod +x`) | `py_compile` hợp lệ, bind `127.0.0.1:3000` |
| 2026-10-13 18:24 | Bước 2 | `scripts/01_generate_ssl.sh` | Viết script sinh chứng chỉ SSL tự ký có SAN theo `interfaces.md` | Chạy thực tế thành công: sinh `ssl/server.crt` & `ssl/server.key`, có SAN đúng; test idempotent thành công |
| 2026-10-13 18:26 | Bước 3 | `nginx/conf.d/02_reverse_proxy.conf` | Cấu hình Virtual Host `app.local` (Port 80 redirect 301, Port 443 SSL termination, proxy_pass, custom 50x) | Hoàn tất file cấu hình |
| 2026-10-13 18:28 | Bước 4 | `tests/test_https_proxy.sh` | Viết script kiểm thử tự động 5 test cases (301, 200, backend body, proxy headers) | `bash -n` syntax OK, chmod +x |
| 2026-10-13 18:33 | Tổng hợp | `docs/stages/stage-2-reverse-proxy.md` | Hoàn thiện tài liệu kỹ thuật chi tiết, giải thích directive và hướng dẫn kiểm thử | Hoàn thành toàn bộ mã nguồn của Demo 2 (TV3) |
| 2026-10-13 19:33 | Nghiệm thu VM | `docs/screenshots/demo2_https.png` | Triển khai live trên VM Ubuntu 22.04 (`192.168.122.42`), chạy test suite và chụp ảnh minh chứng bằng `wkhtmltoimage` | `nginx -t` test is successful; `test_https_proxy.sh` đạt 7 PASS, 0 FAIL; sinh ảnh `demo2_https.png` chuẩn xác |

