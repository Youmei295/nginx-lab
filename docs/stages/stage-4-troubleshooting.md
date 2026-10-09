# Giai đoạn 4 — Troubleshooting (backend down)

> Trạng thái: ⬜ **chưa viết**. Nhiệm vụ: **Task 4.1–4.3** trong [`../tasks.md`](../tasks.md). Phụ trách: **TV3 & TV5**.
> Xem quy ước viết tại [`README.md`](./README.md). Tham khảo mẫu: [`stage-0-infra.md`](./stage-0-infra.md).

## 1. Mục tiêu
<!-- TODO: tắt backend -> 502 -> trang lỗi tùy chỉnh + log error.log -->

## 2. File liên quan
<!-- TODO: nginx/conf.d/02_reverse_proxy.conf, www/error_pages/custom_50x.html, tests/test_troubleshooting.sh, docs/logs/backend_down_502.log -->

## 3. Bức tranh tổng thể
<!-- TODO: backend chết -> Nginx không kết nối upstream -> 502 -> error_page -->

## 4. Nguyên lý cốt lõi
<!-- TODO: error_page + location = /50x.html (alias, internal); phân biệt 502/503/504 -->

## 5. Chi tiết code/directive
<!-- TODO: error_page 502 503 504 /50x.html -->

## 6. Chạy & kiểm chứng
<!-- TODO: dừng backend, curl -k https://app.local/, xem error.log -->

## 7. Lỗi thường gặp
<!-- TODO: alias sai, internal chặn truy cập trực tiếp, log chưa có timing -->

## 8. Liên hệ
<!-- TODO: phụ thuộc stage-2; stage-5 tổng hợp log -->
