# A.4 — Hướng dẫn đọc log và trình bày cho Tuân

## 1. Xem ngay trên Windows trong VS Code

Mở Terminal PowerShell của repo. Khi thấy `PS D:\nginx-lab>`, chạy lần lượt ba lệnh sau; không gõ lại phần dấu nhắc `PS D:\nginx-lab>`:

```powershell
Get-Content -LiteralPath .\docs\logs\backend_down_502.log -Encoding UTF8
Get-Content -LiteralPath .\docs\logs\rate_limit_503.log -Encoding UTF8
Get-Content -LiteralPath .\nginx\nginx.conf -Encoding UTF8
```

Đây là đọc minh chứng đã lưu trong repo, không cần mở VM hoặc cài thêm công cụ. Giải thích đầy đủ để đưa vào bài nộp nằm ở [báo cáo A.4](report.md#a4-accesslog--errorlog-và-phân-biệt-502-503-504).

## 2. Cách đọc và đối chiếu

**Access log cho biết kết quả request; error log giúp tìm nguyên nhân.** Trên VM, hai file gốc là `/var/log/nginx/access.log` và `/var/log/nginx/error.log`. Hai file minh chứng trong repo đều có phần access và phần error, không phải hai loại log riêng biệt.

Trong [nginx.conf](../nginx/nginx.conf), format `main_ext` lần lượt ghi IP client, user, thời điểm, request, status, số byte body, Referer, User-Agent, `rt` và `urt`. Format không ghi Host, nên khi ghép dòng cần đối chiếu thời điểm, request, dấu nhận diện User-Agent và server/upstream bên error log. Chỉ giống thời điểm chưa đủ khẳng định cùng một request.

| Minh chứng có sẵn | Đọc phần access | Đối chiếu phần error |
|---|---|---|
| [Demo 4 của Tuân, 19/10/2026](logs/backend_down_502.log) | Status `502`, User-Agent `nginx-lab-demo4` | `connect() failed (111: Unknown error) while connecting to upstream`, server `app.local`, upstream `127.0.0.1:3000` |
| [Demo 3, 15/10/2026](logs/rate_limit_503.log) | Status `503`, User-Agent `ApacheBench/2.3`; tổng hợp có 21 request 200 và 79 request 503 | `limiting requests`, zone `perip`, server `limit.local` |

Bộ log 503 là minh chứng ngày 15/10 đã có trong repo; không trình bày như một lần benchmark vừa chạy. Cả hai bộ giữ nguyên timestamp từ nguồn.

Với timing:

- `rt=$request_time`: từ lúc Nginx đọc những byte đầu của client đến lúc ghi log sau khi gửi những byte cuối. Đơn vị giây, độ phân giải mili giây; `0.001` là 1 ms, còn `0.000` không có nghĩa request không tốn thời gian. Xem [định nghĩa của Nginx](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format).
- `urt=$upstream_response_time`: thời gian nhận phản hồi từ upstream, cũng tính bằng giây với độ phân giải mili giây. Xem [biến upstream của Nginx](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#var_upstream_response_time).
- Giữ nguyên các số trong log, kể cả dòng có `rt=0.001 urt=0.004`. Không dùng `rt - urt` để kết luận thời gian riêng của Nginx hoặc ép hai số luôn theo một quan hệ lớn/nhỏ; phải xét ngữ cảnh request và error log.

**504 chỉ thuộc phần lý thuyết ở đây:** gateway chờ upstream quá thời gian cho phép; một dấu hiệu cần tìm là `upstream timed out`. Riêng [`proxy_read_timeout`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_read_timeout) giới hạn khoảng chờ giữa hai lần đọc liên tiếp, không phải tổng thời gian toàn bộ phản hồi. Repo chưa có minh chứng 504 trong hai file trên; phần A.4 không cần tạo thêm lỗi hoặc sửa backend của Tài.

## 3. Dàn ý nói khoảng 2 phút

Đọc theo năm đoạn dưới, dừng ngắn để chỉ dòng log tương ứng:

> Em phụ trách cách đọc access log, error log và phân biệt ba mã lỗi. Access log cho biết request nhận mã HTTP nào; error log cung cấp thông tin để tìm nguyên nhân. Cần đối chiếu cả hai.
>
> Ở Demo 4 ngày 19 tháng 10, em dừng backend và nhận 502. Cùng thời điểm, error log có connect() failed tới upstream. Đây là lỗi kết nối; trang lỗi tùy chỉnh chỉ thay nội dung hiển thị.
>
> Minh chứng Demo 3 ngày 15 tháng 10 có 21 request 200 và 79 request 503. Error log ghi limiting requests ở zone perip, cho thấy 503 do rate limit.
>
> 504 là khi gateway chờ upstream vượt thời gian cho phép. Nhóm chưa có minh chứng 504 nên em chỉ trình bày lý thuyết.
>
> Cuối cùng, rt và urt có đơn vị giây. Nếu urt là dấu gạch ngang thì biến này không có giá trị; không dùng riêng timing để kết luận nguyên nhân.

## 4. Bốn câu hỏi thường gặp

1. **503 có luôn nghĩa là backend dừng không?** Không. Trong minh chứng Demo 3, Nginx chặn request vượt rate limit; error log có `limiting requests`. Cần xác định nguyên nhân từ log, không đoán từ status.
2. **502 khác 504 thế nào?** 502 liên quan lỗi giao tiếp hoặc phản hồi upstream không hợp lệ; Demo 4 cụ thể là không kết nối được backend. 504 liên quan chờ upstream quá hạn. Dừng backend trong Demo 4 cho 502, không dùng kết quả đó làm minh chứng 504.
3. **`urt=-` có nghĩa upstream phản hồi trong 0 giây không?** Không. Dấu `-` biểu thị không có giá trị để ghi. Demo 3 dùng server phục vụ tĩnh, request vượt giới hạn bị chặn ngay tại Nginx và không có lần xử lý upstream để đo. Xem [quy tắc ghi giá trị thiếu](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format).
4. **Tại sao ghi `111: Unknown error` thay vì `Connection refused`?** Đó là chuỗi VM của Tuân thực sự ghi. Giữ nguyên khi trích dẫn, rồi giải thích dựa vào `connect() failed`, ngữ cảnh backend đã dừng và status 502; không sửa log nguồn cho giống ví dụ trong tài liệu.
