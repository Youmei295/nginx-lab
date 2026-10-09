# Sơ đồ làm việc & Timeline

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu mô tả **ai làm song song với ai**, **ai phải chờ ai**, và **tiến độ theo ngày**.
> Số task (0.x, 1.x, ...) tham chiếu [`tasks.md`](./tasks.md); giao diện chung ở [`interfaces.md`](./interfaces.md).

---

## 1. Nguyên tắc điều phối

1. **Giai đoạn 0 (hạ tầng) là tiên quyết chung.** Chưa xong môi trường (swap, nginx, hosts, deploy) thì mọi demo chưa chạy được.
2. Sau Giai đoạn 0, có **3 track độc lập chạy song song**:
   - **Track A — Demo 1 (TV2):** thuần Nginx + file tĩnh, không phụ thuộc backend/HTTPS.
   - **Track B — Demo 2 (TV3):** backend + cert + reverse proxy.
   - **Track C — Demo 3 (TV4):** rate limit trên vhost HTTP riêng `limit.local`, chỉ cần Nginx.
3. **TV5** chuẩn bị trang lỗi + khung báo cáo **song song**, nhưng log/ảnh 502 phải **chờ TV3** xong Demo 2.
4. **Demo 4 phụ thuộc Demo 2** (phải có proxy mới tắt backend để sinh 502).
5. **TV1** xong hạ tầng thì chuyển sang hỗ trợ deploy + review.

## 2. Ai chờ ai (phụ thuộc)

| Công việc | Phụ thuộc vào | Người chờ | Ghi chú |
|-----------|---------------|-----------|---------|
| Demo 1 (TV2) | Giai đoạn 0 | TV2 | Độc lập với backend |
| Demo 2 (TV3) | Giai đoạn 0 | TV3 | cần port 3000 + cert |
| Demo 3 (TV4) | Giai đoạn 0 | TV4 | Không chờ Demo 2 |
| Trang lỗi (TV5) | — | TV5 | Làm được sớm |
| Demo 4 (TV3+TV5) | **Demo 2** | TV3, TV5 | Chờ proxy xong |
| Thu log (TV5) | Demo 3 + Demo 4 | TV5 | Cần log đã sinh |
| Báo cáo/slide | Tất cả demo | TV5 + nhóm | Chốt cuối |

## 3. Ai làm song song với ai

| Nhóm | Thành viên | Tính chất |
|------|------------|-----------|
| **Song song tự do** | TV2, TV3, TV4 | 3 track độc lập, không chờ nhau |
| **Song song có điều kiện** | TV5 | Làm docs sớm, nhưng minh chứng 502 chờ TV3 |
| **Điều phối chung** | TV1 | Cung cấp hạ tầng, deploy, review |
| **Review chéo** | TV1 ↔ TV2, TV3 ↔ TV4, TV5 review tổng | Không tự duyệt PR mình |

**Quy tắc dùng VM chung:** nếu cả nhóm dùng 1 VM để ghép, chỉ **một người deploy/reload Nginx tại một thời điểm**; TV2/TV3/TV4 lần lượt theo lượt.

## 4. Timeline theo ngày

| Ngày | TV1 | TV2 | TV3 | TV4 | TV5 |
|------|-----|-----|-----|-----|-----|
| **1** | Setup, hosts, `nginx.conf`, deploy (0.1–0.5) | Đọc `interfaces.md`, chuẩn bị HTML | Chuẩn bị `app.py`* , cert | Đọc spec rate limit | Chuẩn bị `custom_50x.html`, khung report |
| **2** | Hoàn tất deploy, hỗ trợ chung | Demo 1: config + test + ảnh | Demo 2: cert + proxy + HTTPS + test | Demo 3: config rate limit | Viết lý thuyết A (phần mình) |
| **3** | Review TV2 | **CHỐT Demo 1** + review TV3 | **CHỐT Demo 2**, bắt đầu Demo 4 | Benchmark `ab`, trích log 503 | Viết lý thuyết A (tiếp) |
| **4** | Hỗ trợ tích hợp | Hỗ trợ tích hợp | **CHỐT Demo 4** (502) | **CHỐT Demo 3**, review TV4 | Trích log 502, chụp ảnh trang lỗi |
| **5** | Review tổng, dry-run | Dry-run | Dry-run | Dry-run | **CHỐT báo cáo + slide** |

\* `backend/app.py` (`app.js` cũ) đã được dựng sẵn như scaffolding — TV3 chỉ cần chạy/kiểm chứng và **tập trung vào 2.2–2.4**.

### Biểu đồ (ASCII)

```
Ngày:      1        2        3        4        5
TV1   [M0 setup─────][deploy/review────][review──────]
TV2   [chuẩn bị──────][── Demo 1 ──────][review TV3───]
TV3   [app*+cert─────][── Demo 2 ──────][Demo 4───────]
TV4   [đọc spec──────][── Demo 3 ──────][log 503──────]
TV5   [error+report──][lý thuyết A──────][── Demo 4 ───][report+slide]
                         ▲                ▲
                    M1: hạ tầng xong   M3: Demo2 xong → mở Demo4
```

## 5. Đường găng (critical path)

```
M0 (hạ tầng) ──> Demo 2 (TV3) ──> Demo 4 (TV3+TV5) ──> Báo cáo/slide ──> Nộp
```

- **Nằm trên đường găng:** TV1 (M0) → TV3 (Demo 2, Demo 4) → TV5 (minh chứng, báo cáo).
- **Không nằm trên đường găng:** Demo 1 (TV2) và Demo 3 (TV4) — nếu chậm vẫn có thể bù, nhưng phải xong trước ngày 5.
- **Ưu tiên gỡ tắc:** nếu đường găng chậm, TV1/TV2/TV4 hỗ trợ TV3/TV5 trước, hoãn việc nhỏ.

## 6. Mốc đồng bộ (milestones)

| Mốc | Khi nào | Điều kiện đạt | Người xác nhận |
|-----|---------|---------------|----------------|
| **M0** | Cuối ngày 1 | `nginx -t` pass, hosts resolve, deploy chạy | TV1 |
| **M1** | Đầu ngày 2 | Cả 3 track khởi động được | Cả nhóm |
| **M2** | Cuối ngày 2 | Demo 1 & Demo 2 & Demo 3 có bản chạy thử | TV2/TV3/TV4 |
| **M3** | Cuối ngày 3 | Demo 2 hoàn tất → mở Demo 4 | TV3 |
| **M4** | Cuối ngày 4 | Demo 4 (502) + log/ảnh đầy đủ | TV3 + TV5 |
| **M5** | Cuối ngày 5 | Report + slide + dry-run live | TV5 + cả nhóm |

## 7. Trạng thái hiện tại (scaffolding đã có)

Các phần sau đã được dựng sẵn, **giảm việc tương ứng** cho người phụ trách (ghi nhận vào phần đóng góp):

- **TV1:** toàn bộ Giai đoạn 0 đã dựng xong ở mức code — `scripts/00_setup_vm.sh` (0.1–0.3), `nginx/nginx.conf` (0.4), `scripts/02_deploy_config.sh` (0.5). Việc còn lại: **chạy trên VM thật** và tick bàn giao (`free -h`, `nginx -t`, `systemctl status nginx`).
- **TV3:** `backend/app.py` (task 2.1) → còn 2.2 (cert), 2.3 (proxy), 2.4 (test).
- **TV5:** bộ `docs/*` nền → còn `report.md`, log, ảnh.

> Chứng thực: `nginx.conf` và `02_deploy_config.sh` đã được kiểm tra bằng `nginx -t` trên **Ubuntu 22.04 / nginx 1.18** (container); deploy chạy idempotent (chạy 2 lần đều thành công).

> Cách ghi nhận đề xuất: thêm dòng "(scaffold bởi <ai>)" vào `report.md` Phần C để phản ánh đóng góp.

## 8. Liên hệ

- Phân công chi tiết: [`tasks.md`](./tasks.md)
- Giao diện chung: [`interfaces.md`](./interfaces.md)
- Quy tắc nhánh/PR: [`collaboration.md`](./collaboration.md)
