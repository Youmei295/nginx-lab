# Giai đoạn 2 — Reverse Proxy & HTTPS

> Trạng thái: ⬜ **chưa viết**. Nhiệm vụ: **Task 2.1–2.4** trong [`../tasks.md`](../tasks.md). Phụ trách: **TV3**.
> Xem quy ước viết tại [`README.md`](./README.md). Tham khảo mẫu: [`stage-0-infra.md`](./stage-0-infra.md).

## 1. Mục tiêu
<!-- TODO: proxy app.local -> 127.0.0.1:3000 + TLS self-signed -->

## 2. File liên quan
<!-- TODO: nginx/conf.d/02_reverse_proxy.conf, backend/app.py, scripts/01_generate_ssl.sh, tests/test_https_proxy.sh -->

## 3. Bức tranh tổng thể
<!-- TODO: Client -> HTTPS -> Nginx -> backend loopback -->

## 4. Nguyên lý cốt lõi
<!-- TODO: vì sao backend chỉ bind loopback; proxy_set_header; TLS termination; redirect 301 -->

## 5. Chi tiết code/directive
<!-- TODO: proxy_pass, X-Real-IP/X-Forwarded-For, ssl_certificate, SAN của cert -->

## 6. Chạy & kiểm chứng
<!-- TODO: curl -I http://app.local (301), curl -k https://app.local (200) -->

## 7. Lỗi thường gặp
<!-- TODO: cert thiếu SAN, backend chưa chạy, proxy_pass sai port -->

## 8. Liên hệ
<!-- TODO: stage-0 trước; stage-4 (502) sau -->
