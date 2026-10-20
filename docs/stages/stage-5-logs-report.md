# Giai đoạn 5 — Log & Báo cáo

> Phần thu log cho Demo 4: **Tuân** theo note nhóm. Báo cáo và slide tổng hợp cần cả nhóm.
> Đã nhận file log thật và xem ảnh Demo 4 từ VM của Tuân ngày 19/10/2026; test chức năng đã đạt trên VM **4096 MB**, đúng cấu hình nhóm đã xác nhận trong [`interfaces.md`, mục 0](../interfaces.md#0-môi-trường-vm-theo-thống-nhất-nhóm).

## 1. Mục tiêu

Giữ các dòng log liên quan đến Demo 4 và Demo 3 để giải thích nguyên nhân, đối chiếu HTTP status và đưa vào báo cáo. Không tạo log mẫu để thay kết quả thực tế.

## 2. File liên quan

| File | Vai trò |
|------|---------|
| `nginx/nginx.conf` | Cấu hình format `main_ext` có `rt` và `urt` |
| `scripts/04_collect_logs.sh` | Trích error/access log thật |
| `docs/logs/backend_down_502.log` | Lỗi kết nối tới backend của Demo 4 |
| `docs/logs/rate_limit_503.log` | Rate limit của Demo 3; chỉ ghi khi chọn Demo 3 hoặc all |
| `docs/report.md` | Lý thuyết A.4 và kết quả B.3/B.4 |

## 3. Bức tranh tổng thể

```text
Request thật -> /var/log/nginx/{error,access}.log
             -> lọc theo lỗi và dấu nhận diện của demo
             -> docs/logs/*.log -> đối chiếu ảnh/output -> report.md
```

## 4. Nguyên lý cốt lõi

`access.log` ghi kết quả của request: địa chỉ client, thời điểm, request, status, số byte, Referer, User-Agent; `rt` là thời gian xử lý request, `urt` là thời gian upstream. Giá trị `-` nghĩa là không có giá trị tương ứng. Không dùng riêng thời gian để kết luận nguyên nhân lỗi.

`error.log` ghi sự kiện và thông báo chẩn đoán. Mã HTTP chỉ nêu loại lỗi; cần đọc message và đối chiếu request, upstream, thời điểm.

| Mã | Ý nghĩa trong bài lab | Dấu hiệu cần đối chiếu |
|----|----------------------|----------------------|
| 502 Bad Gateway | Nginx không kết nối được backend đã dừng | `connect() failed (111: ...)`, upstream `127.0.0.1:3000` |
| 503 Service Unavailable | Request bị giới hạn ở Demo 3 | `limiting requests`, zone `perip`, server `limit.local` |
| 504 Gateway Timeout | Upstream không phản hồi kịp timeout | `upstream timed out`; Demo 4 hiện không cố tình tạo lỗi này |

502 còn có thể do upstream phản hồi không hợp lệ; 503 có thể do ứng dụng trả về. Không gán mọi dòng 502/503 cho một nguyên nhân duy nhất.

## 5. Cách lọc và ghi file

Demo 4 cần error chứa `connect() failed (111: ...)`, đúng server `app.local` và upstream `127.0.0.1:3000`; access cần status 502 và User-Agent `nginx-lab-demo4`. Errno 111 là `ECONNREFUSED` trên Linux của lab. VM thực tế ghi `111: Unknown error`, nên bộ lọc không dựa vào chuỗi mô tả lỗi; errno khác không được nhận chỉ vì cũng có chữ `Unknown error`. Giữ nguyên toàn bộ dòng log nguồn. Format `main_ext` hiện không ghi Host nên User-Agent giúp khoanh vùng request test; vẫn phải đối chiếu thời điểm và error log, không coi User-Agent là bằng chứng xác thực.

Demo 3 cần error `limiting requests` ở `limit.local` với zone `perip`; access cần status 503 từ ApacheBench. Access log không chứa Host nên tránh trộn benchmark khác trong lúc lấy minh chứng.

Script giữ tối đa số dòng đã chọn của mỗi nguồn, kèm nguồn/thời điểm thu thập. Mỗi file được thay thế bằng bản trích mới, không append qua các lần chạy. Nếu thiếu một trong hai nhóm dòng cần thiết, file cũ của demo đó được giữ lại và script báo thất bại. Log trích có thể gồm nhiều lần demo trước đó; cần kiểm tra thời điểm trước khi đưa vào báo cáo.

## 6. Chạy & kiểm chứng

Tạo request theo [Stage 4](./stage-4-troubleshooting.md) trước, rồi chạy từ gốc repo:

```bash
# Mặc định chỉ Demo 4, không ghi đè minh chứng Demo 3 đang có
sudo bash scripts/04_collect_logs.sh --demo 4

# Chỉ dùng sau khi đã chạy benchmark Demo 3
sudo bash scripts/04_collect_logs.sh --demo 3

# Thu cả hai demo, tối đa 10 dòng mỗi nguồn cho từng demo
sudo bash scripts/04_collect_logs.sh --demo all --lines 10
```

Có thể dùng `ACCESS_LOG`, `ERROR_LOG`, `OUTPUT_DIR` để đọc bản sao log tại vị trí khác, không thay cấu hình Nginx. Ví dụ với log thật đã sao chép và có quyền đọc:

```bash
ACCESS_LOG=/tmp/nginx-access.log ERROR_LOG=/tmp/nginx-error.log \
  OUTPUT_DIR=/tmp/nginx-evidence bash scripts/04_collect_logs.sh --demo 4
```

Kiểm tra file đầu ra có cả error lẫn access tương ứng và thời điểm khớp với lần chụp. Điền output thật vào báo cáo; giữ phần chưa chạy ở trạng thái chờ kiểm chứng. Các log đã lưu từ Demo 3 trước đây không phải kết quả vừa chạy của Demo 4.

## 7. Lỗi thường gặp

| Triệu chứng | Cách xử lý |
|------------|------------|
| Không có quyền đọc log | Chạy collector bằng sudo hoặc dùng bản sao log thật có quyền đọc |
| Thiếu access 502 | Dùng curl với `--user-agent nginx-lab-demo4` khi backend dừng |
| Thiếu error phù hợp | Kiểm tra backend thực sự đã dừng, request đúng HTTPS `app.local` và error log đúng file |
| Log bị rotate | Sao chép đúng log liên quan, dùng biến đường dẫn và ghi rõ thời điểm; script không tự đọc `.gz` |
| Dòng trích thuộc lần chạy cũ | Đối chiếu timestamp; lấy lại log sau request mới |
| Không thấy status trong error.log | Đọc access log để xác minh status, error log để xác minh nguyên nhân |

## 8. Liên hệ

Demo 3 tạo log rate limit; Demo 4 tạo log backend down. Collector chỉ thu bằng chứng đã tồn tại, không tự dừng backend hoặc benchmark. Checklist kết quả nộp bài ở [`deliverables.md`](../deliverables.md); không đánh dấu hoàn tất khi chưa kiểm chứng trên VM.
