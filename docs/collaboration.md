# Quy tắc cộng tác (Collaboration Rules)

> Lab CSC-11117 — Linux OS And Applications
> Áp dụng cho cả 5 thành viên. Mục tiêu: tránh giẫm chân, giữ `main` luôn chạy được,
> và đảm bảo ai cũng đóng góp phần bằng nhau.
> Xem thêm phân công tại [`tasks.md`](./tasks.md), môi trường tại [`environment.md`](./environment.md).

---

## 1. Nguyên tắc vàng

1. **Không đụng vào phần không thuộc việc của mình.** Chỉ sửa file trong phạm vi task được giao (xem bảng ở `tasks.md`).
2. **Không bao giờ commit thẳng lên `main`.** Mọi thay đổi đi qua nhánh riêng → Pull Request (PR) → review → merge.
3. **`main` phải luôn chạy được.** Nếu PR làm hỏng `main`, người gây ra phải sửa ngay.
4. **Kéo code mới nhất trước khi bắt đầu làm.** `git pull origin main` rồi mới tạo/sửa nhánh.
5. **Mỗi PR chỉ giải quyết một việc.** PR nhỏ, dễ review; không gộp nhiều demo vào một PR.
6. **Trao đổi khi chạm interface chung.** Port `3000`, domain `.local`, đường dẫn `/50x.html` — phải thống nhất nhóm trước khi đổi.

---

## 2. Nhánh (Branch)

- Đặt tên theo cú pháp: `feat/<tv><nội-dung>`, `fix/<nội-dung>`, `docs/<nội-dung>`.
  - Ví dụ: `feat/tv2-vhost`, `feat/tv3-reverse-proxy`, `docs/tv5-report`.
- **Mỗi thành viên làm trên nhánh của mình.** Không push đè lên nhánh người khác.
- Nhánh phải xuất phát từ `main` mới nhất:

```bash
git checkout main
git pull origin main
git checkout -b feat/tv2-vhost
```

---

## 3. Commit

- Commit message theo dạng: `<loại>(<phạm vi>): <mô tả ngắn>`.
- Các **loại** được dùng:
  | Loại | Khi nào dùng | Ví dụ |
  |------|--------------|-------|
  | `feat` | Thêm tính năng mới (script/backend/config chạy được) | `feat(backend): add python mock server` |
  | `fix` | Sửa lỗi | `fix(proxy): correct upstream port to 3000` |
  | `docs` | Chỉ sửa tài liệu | `docs(report): add 502/503/504 comparison` |
  | `chore` | Thiết lập khung/config, không thêm chức năng | `chore(repo): initial scaffold` |
  | `build` | Thay đổi build/dependency/công cụ | `build(env): switch backend from node to python` |
  | `refactor` | Đổi cấu trúc code, không đổi hành vi | `refactor(vhost): split server blocks` |
- Commit thường xuyên, mỗi commit là một thay đổi logic hoàn chỉnh.
- **Không commit file sinh tự động / bí mật:** `ssl/server.key`, log runtime, `__pycache__/`, `.env`. `.gitignore` đã chặn — kiểm tra bằng `git status` trước khi `git add`.
- Không dùng `git commit -m "update"`, "fix", "abc" — vô nghĩa khi review.

---

## 4. Pull Request (PR)

1. Push nhánh: `git push -u origin feat/tv2-vhost`.
2. Mở PR trên GitHub, **base = `main`**, **compare = nhánh của mình**.
3. Điền mô tả: làm gì, thuộc task/demo nào, cách kiểm chứng (script test nào đã chạy).
4. **Cần ít nhất 1 thành viên khác review + approve** trước khi merge.
5. Người review kiểm tra: file có đúng phạm vi không, chạy `nginx -t`, không lộ secret.
6. Merge xong **xóa nhánh** để repo gọn.

### Ai review ai?
- Review chéo theo cặp, không tự duyệt PR của chính mình:
  - TV1 ↔ TV2, TV3 ↔ TV4, TV5 review toàn bộ trước khi nộp.
- Chủ repo là người **merge vào `main`** (hoặc người được ủy quyền).

---

## 5. Xử lý xung đột (Conflict)

- Trước khi push, đồng bộ với `main`:
  ```bash
  git fetch origin
  git rebase origin/main
  ```
- Nếu có conflict: sửa file, `git add`, `git rebase --continue`.
- **Không force-push lên `main`.** Force-push chỉ được phép trên nhánh cá nhân (`git push --force-with-lease`).
- Khi không chắc cách giải quyết → **hỏi nhóm**, không tự ý xóa code người khác.

---

## 6. Ranh giới sở hữu file

| Thành viên | Được sửa chính | Không tự sửa khi chưa báo |
|------------|----------------|---------------------------|
| TV1 | `scripts/00_setup_vm.sh`, `scripts/02_deploy_config.sh`, `nginx/nginx.conf` | — |
| TV2 | `nginx/conf.d/01_vhost_sites.conf`, `www/site1/`, `www/site2/` | — |
| TV3 | `nginx/conf.d/02_reverse_proxy.conf`, `backend/`, `scripts/01_generate_ssl.sh` | — |
| TV4 | `nginx/conf.d/03_rate_limit.conf`, `scripts/03_run_benchmark.sh` | — |
| TV5 | `www/error_pages/`, `scripts/04_collect_logs.sh`, `docs/` | — |

- **File dùng chung** (`README.md`, `docs/tasks.md`, `.gitignore`) → muốn sửa thì **báo nhóm/tạo PR riêng**, tránh sửa lén.
- Cần sửa file ngoài phạm vi vì lý do kỹ thuật → **comment trong PR hoặc nhắn nhóm** trước.

---

## 7. Quy tắc chung khi làm việc

- **Không xóa/đổi tên file của người khác** nếu chưa thống nhất.
- **Không format lại toàn bộ file** người khác chỉ để đẹp — gây nhiễu diff.
- **Không dùng chung 1 VM để cùng lúc reload Nginx.** Khi dùng VM chung, phối hợp lượt deploy (xem `environment.md`).
- Test trước khi mở PR: chạy `nginx -t` và script trong `tests/` liên quan.
- Cập nhật `docs/report.md` bằng chứng (log, ảnh) do mình phụ trách.

---
