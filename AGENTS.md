# AGENTS.md

Hướng dẫn cho AI coding agent làm việc trên repo lab Nginx này.
**Đọc đầy đủ: [`docs/ai-agents.md`](docs/ai-agents.md).**

Tóm tắt quy tắc bắt buộc:

1. Đọc `docs/interfaces.md` trước và **tuân thủ tuyệt đối** (domain, cổng, đường dẫn, thông số). Không tự bịa giá trị.
2. Chỉ sửa file trong **phạm vi thành viên** đang làm (bảng trong `docs/ai-agents.md` mục 4 và `docs/collaboration.md`).
3. Làm trên **nhánh riêng**, không commit thẳng `main`, không tự merge/PR.
4. Không commit `ssl/server.key`, `.env`, `__pycache__/`, log runtime.
5. OS chuẩn: **Ubuntu 22.04**. Backend Python 3 tại `127.0.0.1:3000`.
6. Bash script: `set -euo pipefail`, idempotent. Config Nginx: phải qua `nginx -t`.
7. **Không bịa kết quả** `curl`/`ab`/log — chỉ dùng output thật; nếu chưa chạy được thì nói rõ.
8. Thay đổi giao diện chung phải cập nhật `docs/interfaces.md` trước và hỏi con người.
