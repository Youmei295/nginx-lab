# Giai đoạn 4 — Troubleshooting (backend down)

> Phụ trách theo note nhóm: **Tuân — Demo 4**, dùng backend và reverse proxy của **Tài — Demo 2**.
> Tài liệu cũ chia 5 TV; số demo trong note không phải số TV trong bảng cũ.
> **Đã kiểm chứng chức năng trên VM Ubuntu của Tuân ngày 19/10/2026:** `nginx -t` thành công; test 200 → 404 trực tiếp → 502 đúng trang lỗi → phục hồi 200 đạt. Đã nhận log thật và xem PNG qua Nginx.
> **Môi trường đã thống nhất:** VirtualBox cấp **4096 MB (4 GB) RAM**, đúng cấu hình nhóm do Tuân xác nhận ngày 19/10/2026, theo [`interfaces.md`, mục 0](../interfaces.md#0-môi-trường-vm-theo-thống-nhất-nhóm). Không cần chạy lại ở 512 MB. Nhánh bàn giao: `feat/tuan-troubleshooting`; review và merge theo quy trình nhóm.
> Đã kiểm tra cú pháp bằng Git Bash, chạy các ca mô phỏng cho script và xem thử HTML ở desktop/mobile trên Windows. Các kiểm tra này không thay thế `nginx -t`, log và ảnh qua Nginx trên VM.

## 1. Mục tiêu

Đáp ứng mục B.4 của đề tài Nginx: dừng backend, hiển thị trang lỗi tùy chỉnh trên trình duyệt và trích dòng lỗi tương ứng trong `error.log`. Kiểm tra thêm việc khôi phục backend để chứng minh sự cố đã được xử lý.

## 2. File liên quan

| File | Vai trò |
|------|---------|
| `www/error_pages/custom_50x.html` | Trang HTML/CSS tự chứa cho lỗi 502/503/504; không cần CDN hoặc JavaScript |
| `tests/test_troubleshooting.sh` | Tự chạy backend, kiểm tra trạng thái bình thường, dừng, kiểm tra lỗi và chạy lại |
| `scripts/04_collect_logs.sh` | Trích log thật; mặc định chỉ thu Demo 4 |
| `nginx/conf.d/02_reverse_proxy.conf` | Cấu hình có sẵn của Demo 2: HTTPS, proxy và ánh xạ trang lỗi |
| `scripts/02_deploy_config.sh` | Copy HTML vào `/usr/share/nginx/error_pages/` rồi kiểm tra/reload Nginx |
| `docs/logs/backend_down_502.log` | Minh chứng do người chạy tạo từ log thật |
| `docs/screenshots/demo4_error_page.png` | Ảnh trình duyệt do người chạy chụp lúc backend đang dừng |

Không đổi domain, cổng, tên file hoặc cấu hình của người làm Demo 2. Giá trị chung theo [`interfaces.md`](../interfaces.md).

## 3. Bức tranh tổng thể

```text
Backend chạy  -> GET https://app.local/ -> 200, nội dung Python
Backend dừng -> GET https://app.local/ -> 502, HTML tùy chỉnh
                                        + error.log: connect() failed (111: ...)
Backend chạy lại -> GET https://app.local/ -> 200, nội dung Python
```

## 4. Nguyên lý cốt lõi

Nginx vẫn chạy khi backend dừng. Kết nối tới upstream bị từ chối nên Nginx trả `502 Bad Gateway`; đây không phải lỗi chứng chỉ hay rate limit. Directive `error_page` thay nội dung phản hồi bằng trang HTML, vẫn giữ mã lỗi HTTP.

VM của Tuân ghi `connect() failed (111: Unknown error)` thay vì chuỗi `Connection refused`. Trên Linux của lab, errno 111 là `ECONNREFUSED`; collector lọc số lỗi trong thao tác `connect()` cùng server/upstream, không phụ thuộc cách Nginx diễn giải lỗi thành chữ. Không sửa hoặc thay chữ trong log minh chứng.

Trang HTML dùng chung cho 502/503/504 nên thông báo dịch vụ tạm gián đoạn, không cố định mã 502 trong nội dung. Mã lỗi được xác minh bằng `curl` và log. HTML không công bố địa chỉ upstream hoặc chi tiết hệ thống cho người truy cập.

## 5. Chi tiết code/directive

Phần sau **đã có** trong `02_reverse_proxy.conf`:

```nginx
error_page 502 503 504 /50x.html;
location = /50x.html {
    alias /usr/share/nginx/error_pages/custom_50x.html;
    internal;
}
```

`alias` trỏ đến file sau deploy. `location =` chỉ khớp đúng `/50x.html`; `internal` cho phép chuyển hướng nội bộ khi lỗi, còn truy cập trực tiếp URL này phải trả 404.

Script test kiểm tra marker `id="nginx-lab-error-page"` trong body để phân biệt trang tùy chỉnh với trang mặc định. Mỗi request test tới Nginx dùng User-Agent `nginx-lab-demo4` để đối chiếu dòng 502 trong access log.

Test chỉ quản lý PID backend do chính nó tạo. Nếu cổng 3000 đang có tiến trình khác, test dừng với hướng dẫn; không tự giết backend có sẵn. Sau khi kiểm tra khôi phục 200, test dọn tiến trình con, trả cổng về trạng thái trống ban đầu. Khi lỗi hoặc nhấn Ctrl+C, trap cũng dọn tiến trình con.

## 6. Chạy & kiểm chứng trên Ubuntu 22.04

### Chuẩn bị

Đưa các file đã cập nhật vào repo trên VM Ubuntu 22.04, hoàn thành môi trường ở [`environment.md`](../environment.md). Chạy lệnh từ thư mục gốc repo. Nếu dùng VM chung, hẹn lượt với Tài trước khi dừng backend.

```bash
bash scripts/01_generate_ssl.sh
bash scripts/02_deploy_config.sh
sudo nginx -t
bash -n tests/test_troubleshooting.sh
bash -n scripts/04_collect_logs.sh
```

Hai file cert/key được sinh tại máy chạy và không commit. Dừng backend đang chạy ở terminal cũ bằng Ctrl+C; **không chạy `python3 backend/app.py` riêng trước test**, vì test cần cổng 3000 trống để tự quản lý backend.

### Test và giữ trạng thái lỗi để lấy minh chứng

Terminal A:

```bash
bash tests/test_troubleshooting.sh --pause
```

Test xác nhận 200 và `/50x.html` trực tiếp trả 404, sau đó dừng backend, xác nhận 502 và đúng marker HTML. Script tạm dừng chờ Enter ở trạng thái lỗi để thực hiện bước tiếp theo. Tuân đã cung cấp output thật đầy đủ, gồm kiểm tra phục hồi 200 và dọn backend ở cuối.

Terminal B, khi Terminal A đang chờ:

```bash
curl --noproxy '*' --resolve app.local:443:127.0.0.1 \
  --user-agent nginx-lab-demo4 -k -i https://app.local/
sudo bash scripts/04_collect_logs.sh --demo 4
```

Cần đối chiếu HTTP 502, nội dung trang lỗi và file `docs/logs/backend_down_502.log`. Collector yêu cầu cả dòng error phù hợp lẫn access 502 có User-Agent của demo; nếu thiếu, nó báo lỗi và giữ file minh chứng cũ.

### Chụp gì

Chụp **trang lỗi được phục vụ qua `https://app.local/` trong khi backend dừng**, lưu thành `docs/screenshots/demo4_error_page.png`. Không dùng ảnh mở file HTML trực tiếp làm minh chứng tích hợp và không truy cập `/50x.html` để chụp.

Nếu VM đã có `wkhtmltoimage` theo hướng dẫn môi trường:

```bash
mkdir -p docs/screenshots
QT_QPA_PLATFORM=offscreen wkhtmltoimage --load-error-handling ignore --width 1100 \
  https://app.local/ docs/screenshots/demo4_error_page.png
```

Vì chứng chỉ tự ký và HTTP 502, browser headless có thể báo cảnh báo/exit khác 0; cần mở ảnh kiểm tra đúng nội dung. Nếu đã có Chromium, có thể dùng thay thế:

```bash
chromium-browser --headless --no-sandbox --ignore-certificate-errors \
  --screenshot="$(pwd)/docs/screenshots/demo4_error_page.png" https://app.local/
```

Nếu dùng trình duyệt tương tác, chấp nhận chứng chỉ tự ký của lab và nên chụp cả thanh địa chỉ. Không cần cài thêm browser nếu VM đã có một công cụ phù hợp.

Nên chụp thêm terminal có HTTP 502, dòng `connect() failed (111: ...)` trong file log và kết quả PASS của test để đối chiếu với ảnh trang lỗi. Giữ nguyên chữ `Unknown error` nếu đó là output thật từ VM.

### Khôi phục và điền kết quả

Quay lại Terminal A, nhấn Enter. Test chạy lại backend, kiểm tra 200 rồi dọn backend do nó tạo. Muốn tiếp tục dùng Demo 2 sau test, chạy lại ở terminal riêng:

```bash
python3 backend/app.py
```

Nếu chỉ kiểm thử mà không chụp ảnh, dùng `bash tests/test_troubleshooting.sh` không có `--pause`. Khi hoàn tất chạy thật, điền output vào mục B.4 trong [`report.md`](../report.md), kèm ảnh và log; không thay TODO bằng số liệu dự đoán.

### Minh chứng đã nhận ngày 19/10/2026

- [`backend_down_502.log`](../logs/backend_down_502.log): 2 dòng access 502 có User-Agent của demo và 3 dòng error `connect() failed (111: Unknown error)` tới đúng upstream; collector ghi thời điểm thu thập `2026-10-19T12:34:51Z`.
- [`demo4_error_page.png`](../screenshots/demo4_error_page.png): đã mở xem, đúng trang lỗi tiếng Việt với nút Thử lại. Đây là ảnh `wkhtmltoimage` qua `https://app.local/` trên VM, không phải preview file local trên Windows.
- Output test của Tuân xác nhận cả phục hồi 200 và cleanup. Output deploy xác nhận `nginx -t` thành công.
- Bản kiểm thử dùng VM **4096 MB**, đúng cấu hình nhóm đã chốt. Bộ minh chứng hiện có được dùng cho Demo 4; không có bước chờ kiểm chứng lại ở 512 MB.

## 7. Lỗi thường gặp

| Triệu chứng | Kiểm tra / xử lý |
|------------|------------------|
| Test báo cổng 3000 đang dùng | Dừng backend ở terminal đã chạy nó; test không dừng tiến trình có sẵn |
| Không kết nối được HTTPS | Kiểm tra Nginx, cert, deploy; lỗi kết nối `curl` không được tính là HTTP 502 |
| Có 502 nhưng thiếu marker | Deploy lại HTML, kiểm tra file `/usr/share/nginx/error_pages/custom_50x.html` và cấu hình alias |
| `/50x.html` trực tiếp trả 404 | Đúng với `internal`; phải xem lỗi tại `/` sau khi dừng backend |
| Collector cũ báo thiếu dòng lỗi nhưng có `(111: Unknown error)` | Chép bản collector đã sửa sang VM; bản mới nhận errno 111, không đòi chữ `Connection refused` |
| Collector báo thiếu dòng lỗi | Tạo request bằng lệnh curl có User-Agent phía trên; kiểm tra log đang dùng/chưa rotate |
| Không đọc được log | Dùng `sudo bash scripts/04_collect_logs.sh --demo 4` |
| Test đã kết thúc rồi chụp lại thấy 502 | Test dọn backend ở cuối; để lấy ảnh đúng thời điểm dùng `--pause`, để dùng app bình thường thì chạy lại backend riêng |

## 8. Liên hệ

Demo 4 dùng nền từ [Stage 2](./stage-2-reverse-proxy.md), nhưng HTML và script có thể viết độc lập khi giao diện đã chốt. Cách trích log và giải thích 502/503/504 ở [Stage 5](./stage-5-logs-report.md). Chỉ xác nhận hoàn tất Demo 4 sau khi có `nginx -t`, test, ảnh trình duyệt và log thật trên VM.
