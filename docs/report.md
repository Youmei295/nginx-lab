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

#### 1. Định nghĩa và Phân biệt
- **Web Server**: Là phần mềm (như Nginx, Apache) chuyên xử lý và phản hồi các yêu cầu qua giao thức HTTP/HTTPS. Vai trò chính là phục vụ tài nguyên tĩnh (HTML, CSS, JavaScript, hình ảnh) với hiệu năng cao, quản lý kết nối TCP/TLS và định tuyến các yêu cầu phức tạp.
- **Reverse Proxy (Proxy nghịch)**: Là máy chủ trung gian đứng trước một hoặc nhiều máy chủ ứng dụng (backend). Thay vì client giao tiếp trực tiếp với backend, mọi request từ client bên ngoài được gửi tới reverse proxy; reverse proxy sẽ kiểm tra, xử lý, rồi chuyển tiếp (forward) request đến backend phù hợp, sau đó nhận kết quả và chuyển ngược về cho client.
- **Phân biệt Forward Proxy (Proxy thuận) vs Reverse Proxy (Proxy nghịch)**:
  - *Forward Proxy*: Đại diện cho **Client** (Client-facing). Nằm giữa client nội bộ và Internet. Client chủ động cấu hình proxy để truy cập ra ngoài (vượt tường lửa, ẩn danh IP client, lọc nội dung web chiều ra). Web server đích chỉ thấy IP của forward proxy mà không thấy client.
  - *Reverse Proxy*: Đại diện cho **Server** (Server-facing). Nằm giữa Internet và hệ thống backend nội bộ. Client hoàn toàn không biết có proxy đứng chặn phía trước và gửi request như tới một server thông thường. Reverse proxy bảo vệ và che giấu toàn bộ hạ tầng backend bên trong.

#### 2. Vì sao không để Backend nhận request trực tiếp từ Internet?
Trong kiến trúc sản xuất hiện đại, ứng dụng backend (Python, Node.js, Java, Go,...) hầu như không bao giờ mở trực tiếp ra Internet vì 5 lý do cốt lõi:
1. **Thu hẹp bề mặt tấn công & Ẩn cấu trúc nội bộ (Attack Surface Reduction)**: 
   Nếu mở trực tiếp, backend application server phải lắng nghe trên card mạng công khai. Kẻ tấn công có thể quét cổng (port scan), tấn công tràn bộ đệm (buffer overflow) vào các framework backend hoặc khai thác lỗ hổng bảo mật trực tiếp. Khi dùng Reverse Proxy, toàn bộ backend chỉ lắng nghe trên mạng nội bộ hoặc card loopback (`127.0.0.1`), không thể bị dò quét hay truy cập trái phép từ bên ngoài.
2. **SSL/TLS Termination tập trung**: 
   Quá trình bắt tay mã hóa TLS (RSA, ECDHE) và giải mã các gói tin HTTPS tiêu tốn năng lực xử lý CPU đáng kể. Nginx được viết bằng C với thuật toán tối ưu cao, đảm nhiệm việc giải mã SSL tại gateway (TLS Termination) và chỉ forward request dạng HTTP plaintext nhẹ nhàng về backend qua loopback, giúp ứng dụng backend giải phóng CPU để tập trung xử lý nghiệp vụ chính.
3. **Cân bằng tải & Mở rộng quy mô (Load Balancing & Scalability)**: 
   Reverse Proxy hoạt động như bộ điều phối lưu lượng, phân phối tải tới nhiều instance backend (Round Robin, Least Connections, IP Hash) để tránh nghẽn cổ chai và hỗ trợ mở rộng quy mô linh hoạt (horizontal scaling) mà phía client không hề hay biết.
4. **Bộ nhớ đệm & Phục vụ file tĩnh (Caching & Static Acceleration)**: 
   Ứng dụng backend thường rất chậm khi phải xử lý I/O đọc/ghi file tĩnh hoặc các truy vấn lặp lại. Nginx có khả năng phục vụ file tĩnh cực nhanh nhờ cơ chế non-blocking event-driven và `sendfile`, đồng thời cache lại các response từ backend để phản hồi ngay lập tức cho client.
5. **Che giấu lỗi hệ thống & Cách ly lỗi (Error Masking & Centralized Logging)**: 
   Khi backend gặp sự cố sập hoặc ném ngoại lệ (unhandled exception), việc trả trực tiếp stack trace ra ngoài có thể để lộ thông tin nhạy cảm (cấu trúc thư mục, phiên bản thư viện, chuỗi kết nối cơ sở dữ liệu). Nginx đứng giữa bắt các lỗi 502/503/504 và trả về trang lỗi tùy chỉnh thân thiện, đồng thời ghi log tập trung phục vụ giám sát và kiểm toán an ninh.

#### 3. Liên hệ thực tế trong Demo 2
- Trong Demo 2 của lab, tên miền `app.local` được Nginx tiếp nhận tại cổng 443 (HTTPS). Nginx thực hiện SSL Termination bằng chứng chỉ tự ký có SAN, sau đó chuyển tiếp request sang backend mock Python qua lệnh `proxy_pass http://127.0.0.1:3000;`.
- Backend Python (`backend/app.py`) chỉ bind duy nhất trên địa chỉ loopback `127.0.0.1:3000`, đảm bảo cách ly tuyệt đối khỏi truy cập trực tiếp.
- Nginx thiết lập các HTTP header bắt buộc (`Host $host;`, `X-Real-IP $remote_addr;`, `X-Forwarded-For $proxy_add_x_forwarded_for;`) để backend nhận diện chính xác danh tính và IP của client ban đầu dù kết nối TCP thực tế tới backend xuất phát từ chính Nginx.


### A.2. Kiến trúc event-driven của Nginx vs process/thread của Apache
*(Phụ trách: TV1)*

- **TODO:** Mô tả mô hình worker + event loop (async, non-blocking) của Nginx.
- **TODO:** Mô tả mô hình process/thread (prefork/worker) của Apache và chi phí context switch, RAM mỗi kết nối.
- **TODO:** Bảng so sánh và hệ quả khi C10K (10.000 kết nối đồng thời) trên VM 512MB.
- **Liên hệ demo:** `worker_connections` trong `nginx/nginx.conf`.

### A.3. Cơ chế Server Block (Virtual Host)

- **Cơ chế chọn Server Block:** Nginx quyết định phân phối request đến Server Block nào bằng cách kiểm tra trước cổng `listen` (IP và Port). Nếu có nhiều block cùng chung IP:Port, Nginx sẽ tiếp tục kiểm tra chỉ thị `server_name` trong file cấu hình xem có khớp với giá trị của trường `Host` nằm trong HTTP Header của request gửi tới hay không.
- **Thứ tự ưu tiên so khớp:** Nginx ưu tiên so khớp theo thứ tự: Tên miền chính xác (exact match) → Tên miền có dấu sao (wildcard) ở đầu → Tên miền có dấu sao (wildcard) ở cuối → Biểu thức chính quy (regular expressions). Nếu không có tên miền nào khớp, Nginx sẽ đẩy request về `default_server` (máy chủ mặc định).
- **Liên hệ demo:** Trong bài thực hành, cả hai tên miền `site1.local` và `site2.local` đều phân giải về cùng một địa chỉ IP nội bộ (`127.0.0.1`) và cùng lắng nghe trên cổng 80. Nhờ cơ chế Virtual Host, Nginx đã đọc được Header `Host` để điều hướng chính xác request lấy nội dung từ các thư mục `root` khác nhau là `/usr/share/nginx/html/site1` và `/usr/share/nginx/html/site2`.

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
- **Kết quả:** 
  - Lệnh 1 trả về: `<h1>Day la Site 1 - Thanh vien 2</h1>`
  - Lệnh 2 trả về: `<h1>Day la Site 2 - Thanh vien 2</h1>`
- **Ảnh:** 
  ![Site 1](./screenshots/demo1_site1.png)
  ![Site 2](./screenshots/demo1_site2.png)

### B.2. Demo 2 — Reverse Proxy & HTTPS
*(Phụ trách: TV3)*

#### 1. Lệnh kiểm thử & Output thực tế

**Lệnh 1: Kiểm tra HTTP (cổng 80) chuyển hướng 301 sang HTTPS**
```bash
curl -I http://app.local/
```
Output thực tế:
```http
HTTP/1.1 301 Moved Permanently
Server: nginx/1.18.0 (Ubuntu)
Date: Tue, 13 Oct 2026 12:32:27 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://app.local/
```
*Nhận xét:* Nginx phản hồi đúng mã trạng thái `301 Moved Permanently` và chuyển hướng thông qua header `Location: https://app.local/`.

**Lệnh 2: Kiểm tra HTTPS (cổng 443) proxy tới backend Python và bảo toàn header**
```bash
curl -k https://app.local/
```
Output thực tế:
```
Hello from backend (Python)
path: /
Host: app.local
X-Real-IP: 127.0.0.1
X-Forwarded-For: 127.0.0.1
```
*Nhận xét:* Nginx thực hiện SSL Termination thành công và chuyển tiếp request tới backend Python tại `127.0.0.1:3000`. Backend nhận đầy đủ các thông tin: `Host: app.local`, `X-Real-IP: 127.0.0.1`, `X-Forwarded-For: 127.0.0.1`.

**Lệnh 3: Kiểm tra cấu hình SAN (Subject Alternative Name) của chứng chỉ SSL**
```bash
openssl s_client -connect app.local:443 -servername app.local < /dev/null 2>/dev/null | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name"
```
Output thực tế:
```
            X509v3 Subject Alternative Name: 
                DNS:app.local, DNS:localhost, IP Address:127.0.0.1
```
*Nhận xét:* Chứng chỉ self-signed chứa đầy đủ SAN bao gồm `DNS:app.local`, `DNS:localhost` và `IP Address:127.0.0.1` đúng theo tiêu chuẩn của các trình duyệt hiện đại.

#### 2. Kết quả script kiểm thử tự động (`tests/test_https_proxy.sh`)
```
[INFO] Bắt đầu kiểm thử Demo 2: Reverse Proxy & HTTPS (app.local)...
[INFO] Test 1: Kiểm tra HTTP (port 80) chuyển hướng 301...
[PASS] HTTP port 80 trả về status code 301 Moved Permanently.
[INFO] Test 2: Kiểm tra header Location trong phản hồi HTTP 301...
[PASS] Header Location chuyển hướng chính xác: Location: https://app.local/test-path?param=1
[INFO] Test 3: Kiểm tra HTTPS (port 443) phản hồi 200 qua Reverse Proxy...
[PASS] HTTPS port 443 trả về status code 200 OK.
[INFO] Test 4: Kiểm tra nội dung phản hồi từ backend mock...
[PASS] Nhận đúng chuỗi nhận diện từ Python backend.
[INFO] Test 5: Kiểm tra các header X-Forwarded-For, Host, X-Real-IP...
[PASS] Backend nhận đúng header: Host: app.local
[PASS] Backend nhận đúng header: X-Forwarded-For
[PASS] Backend nhận đúng header: X-Real-IP
------------------------------------------------------------
Kết quả kiểm thử: 7 PASS, 0 FAIL
------------------------------------------------------------
```

#### 3. Ảnh minh chứng trên trình duyệt
Ảnh chụp màn hình truy cập HTTPS qua headless browser (`wkhtmltoimage`) lưu tại: [`docs/screenshots/demo2_https.png`](screenshots/demo2_https.png).

![Minh chứng Demo 2 HTTPS](screenshots/demo2_https.png)


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
