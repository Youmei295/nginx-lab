# Tài liệu theo giai đoạn (Stage docs)

> Lab CSC-11117 — Linux OS And Applications
> Thư mục này chứa **tài liệu kỹ thuật giải thích code & nguyên lý** của từng giai đoạn.
> Đây **không phải** báo cáo nộp bài (báo cáo ở [`../report.md`](../report.md)).
> Mục tiêu: người mới đọc vào hiểu ngay giai đoạn đó dùng file nào, chạy thế nào, vì sao làm vậy.

## Quy ước

- Mỗi giai đoạn một file: `stage-<số>-<tên-ngắn>.md`.
- Một giai đoạn **chỉ được xem là tài liệu xong** khi có đủ:
  1. Mục tiêu giai đoạn.
  2. Bảng **file liên quan** (kèm task).
  3. Giải thích **nguyên lý** (vì sao làm vậy, không chỉ làm gì).
  4. Các đoạn code/directive chính kèm giải thích.
  5. Lệnh chạy + **kết quả mong đợi**.
  6. Lỗi thường gặp & cách xử lý.
  7. Liên hệ giai đoạn trước/sau.
- Không bịa kết quả: output phải là thật, hoặc ghi rõ "chưa chạy".

## Danh sách giai đoạn

| Giai đoạn | File | Trạng thái |
|-----------|------|------------|
| 0 — Hạ tầng & chuẩn bị | [`stage-0-infra.md`](./stage-0-infra.md) | ✅ đã viết |
| 1 — Virtual Host | [`stage-1-vhost.md`](./stage-1-vhost.md) | ⬜ chưa viết |
| 2 — Reverse Proxy & HTTPS | [`stage-2-reverse-proxy.md`](./stage-2-reverse-proxy.md) | ⬜ chưa viết |
| 3 — Rate Limiting & Benchmark | [`stage-3-rate-limit.md`](./stage-3-rate-limit.md) | ⬜ chưa viết |
| 4 — Troubleshooting | [`stage-4-troubleshooting.md`](./stage-4-troubleshooting.md) | ⬜ chưa viết |
| 5 — Log & Báo cáo | [`stage-5-logs-report.md`](./stage-5-logs-report.md) | ⬜ chưa viết |

## Liên hệ

- Phân công & thứ tự: [`../tasks.md`](../tasks.md)
- Sơ đồ làm việc song song: [`../timeline.md`](../timeline.md)
- Giao diện chung: [`../interfaces.md`](../interfaces.md)
- Vai trò file: [`../files.md`](../files.md)
