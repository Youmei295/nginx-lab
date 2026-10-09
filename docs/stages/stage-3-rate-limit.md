# Giai đoạn 3 — Rate Limiting & Benchmark

> Trạng thái: ⬜ **chưa viết**. Nhiệm vụ: **Task 3.1–3.3** trong [`../tasks.md`](../tasks.md). Phụ trách: **TV4**.
> Xem quy ước viết tại [`README.md`](./README.md). Tham khảo mẫu: [`stage-0-infra.md`](./stage-0-infra.md).

## 1. Mục tiêu
<!-- TODO: giới hạn tải trên limit.local, benchmark 100 request đồng thời, thống kê 200 vs 503 -->

## 2. File liên quan
<!-- TODO: nginx/conf.d/03_rate_limit.conf, scripts/03_run_benchmark.sh, tests/test_rate_limit.sh, docs/logs/rate_limit_503.log -->

## 3. Bức tranh tổng thể
<!-- TODO: request đồng thời -> limit_req -> 200/503 -->

## 4. Nguyên lý cốt lõi
<!-- TODO: limit_req_zone, leaky bucket, burst, nodelay; vì sao chạy trên HTTP không qua proxy -->

## 5. Chi tiết code/directive
<!-- TODO: rate=10r/s burst=20 nodelay + giải thích con số -->

## 6. Chạy & kiểm chứng
<!-- TODO: ab -n 100 -c 100 http://limit.local/ ; Complete requests / Non-2xx -->

## 7. Lỗi thường gặp
<!-- TODO: toàn 200 hoặc toàn 503, zone sai context -->

## 8. Liên hệ
<!-- TODO: stage-0 trước; stage-5 (thu log) sau -->
