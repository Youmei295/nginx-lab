# Môi trường làm việc (Environment) — Ubuntu 22.04

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu này hướng dẫn **từng thành viên** dựng môi trường **trên máy local của mình**,
> hoàn tất **toàn bộ Giai đoạn 0** và biết chắc khi nào **đủ điều kiện bắt đầu** phần việc riêng.
> Không chỉ TV1 mới làm Giai đoạn 0 — **mọi thành viên đều phải làm** trên máy mình để tự test độc lập.

---

## 1. Nguyên tắc

- **Nền tảng hỗ trợ duy nhất: Ubuntu Server 22.04 LTS (64-bit).**
- Hyper-V / VirtualBox / VMware / UTM (macOS) chỉ là lớp host — tất cả chạy **cùng một image Ubuntu 22.04**.
- **Tạo máy ảo là bước thủ công** (không nằm trong script). Script `00_setup_vm.sh` chạy **bên trong** Ubuntu.
- WSL2 được chấp nhận để **test cá nhân**, cần cấu hình thêm (mục 3.5) và **không thay thế** VM khi trình diễn.
- Khi ghép nhóm / trình diễn cuối: dùng **1 VM Ubuntu 22.04 chung** đúng yêu cầu "1 VM (512MB RAM)".

### Vì sao phải chuẩn hóa?

`00_setup_vm.sh` dùng `apt`, `systemctl`, `swapon` — đặc thù Ubuntu. Nếu mỗi người dùng distro/host khác nhau, lệnh có thể sai hoặc cho kết quả khác (WSL2 không có systemd mặc định và không tự tạo swap).

---

## 2. Checklist Giai đoạn 0 trên máy local (làm TRƯỚC khi bắt đầu việc của mình)

> Đây là **cổng bắt buộc**: chưa xong checklist này thì chưa tự test được demo của mình.
> Chi tiết từng bước ở các mục 3–6.

```
[Bước 1] Tạo VM Ubuntu 22.04 ──> [Bước 2] Cài git + danh tính + SSH
        ──> [Bước 3] Clone repo + tạo nhánh riêng
        ──> [Bước 4] bash scripts/00_setup_vm.sh      (swap, hosts, tools, nginx)
        ──> [Bước 5] bash scripts/02_deploy_config.sh (nạp nginx.conf + baseline)
        ──> [Bước 6] Kiểm tra (mục 6) ──> ✅ SẴN SÀNG làm việc
```

| # | Việc | Lệnh chính | Bắt buộc cho | Mục |
|---|------|-----------|--------------|-----|
| 1 | Tạo VM Ubuntu 22.04 (512MB RAM) | theo host | Tất cả | 3 |
| 2 | Cài `git`, đặt `user.name`/`user.email`, thêm SSH key | `git config --global ...` | Tất cả | 4.1 |
| 3 | Clone repo, tạo nhánh `feat/tvX-...` | `git clone ...` | Tất cả | 4.2 |
| 4 | Chạy script thiết lập (swap, hosts, tools, nginx) | `bash scripts/00_setup_vm.sh` | Tất cả | 5.1 |
| 5 | Deploy cấu hình nền từ repo | `bash scripts/02_deploy_config.sh` | Tất cả | 5.2 |
| 6 | (Khi làm Demo 2) sinh chứng chỉ self-signed | `bash scripts/01_generate_ssl.sh` | **TV3** | 5.3 |
| 7 | Kiểm tra đủ điều kiện (mục 6) | bảng lệnh | Tất cả | 6 |

> Script `00_setup_vm.sh`, `nginx/nginx.conf`, `02_deploy_config.sh` đã có sẵn trong repo
> (**TV1 phụ trách** — Task 0.1–0.5). Các thành viên khác chỉ cần `git pull` và **chạy**.

---

## 3. Tạo máy ảo theo từng host

### 3.1. Hyper-V (Windows Pro/Enterprise)

1. Bật tính năng: Windows Features → tích **Hyper-V** → restart.
2. Tải ISO **Ubuntu Server 22.04** tại <https://ubuntu.com/download/server>.
3. **Hyper-V Manager** → *New* → *Virtual Machine*:
   - Generation: **Gen 2**
   - RAM: **512 MB** (thêm *Dynamic Memory* nếu muốn)
   - Network: **Default Switch**
4. Gắn ISO, cài Ubuntu (chọn OpenSSH server khi được hỏi).
5. Sau khi cài, cấp IP bằng `ip a` và SSH vào để chạy script.

### 3.2. VirtualBox

1. Tải ISO Ubuntu Server 22.04.
2. New VM: Type Linux / Version **Ubuntu (64-bit)**, RAM **512 MB**, disk ~10GB.
3. Cài đặt bình thường, bật **OpenSSH server**.
4. (Tùy chọn) Network → **Bridged Adapter** để truy cập từ máy khác.

### 3.3. VMware Workstation / Fusion

1. New VM → chọn ISO → **Ubuntu 64-bit**, RAM 512 MB.
2. Bật OpenSSH trong lúc cài.
3. Network: **NAT** hoặc **Bridged**.

### 3.4. UTM (macOS, Apple Silicon)

1. UTM → *Create a New Virtual Machine* → **Virtualize** → Linux.
2. Chọn ISO Ubuntu Server **arm64** 22.04, RAM 512 MB.
3. Cài đặt, bật OpenSSH server.
4. Network: **Shared Network** (mặc định) hoặc Bridged.

### 3.5. WSL2 (chỉ để test cá nhân)

Trên Windows, PowerShell (quyền admin):

```powershell
wsl --install -d Ubuntu-22.04
```

Bật systemd bên trong WSL (cần thiết để `systemctl` quản lý Nginx):

```bash
# Trong WSL Ubuntu
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Thoát và restart WSL từ PowerShell:

```powershell
wsl --shutdown
```

Cấu hình RAM/swap cho WSL2 — tạo `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=1GB
swap=1GB
```

Kiểm tra systemd đã bật: `systemctl --version` và `systemctl status nginx` phải hoạt động.

> Lưu ý: WSL dùng chung kernel với Windows, **không phải VM biệt lập**, nên không dùng để tính "1 VM" của bài lab.

---

## 4. Lấy mã nguồn & cấu hình Git

### 4.1. Cài git, đặt danh tính, thêm SSH key

```bash
sudo apt-get update && sudo apt-get install -y git

git config --global user.name "Tên của bạn"
git config --global user.email "email@example.com"

# Khuyến nghị SSH
ssh-keygen -t ed25519 -C "email@example.com"
cat ~/.ssh/id_ed25519.pub   # dán vào GitHub → Settings → SSH keys
```

Nếu dùng HTTPS, cần **Personal Access Token** thay mật khẩu (xem mục 9).

### 4.2. Clone repo và tạo nhánh riêng

```bash
git clone git@github.com:Youmei295/nginx-lab.git nginx-lab-project
# hoặc: git clone https://github.com/Youmei295/nginx-lab.git nginx-lab-project

cd nginx-lab-project
git checkout -b feat/tv2-vhost      # nhánh riêng theo việc của bạn
```

Nếu đã clone trước đó, cập nhật code mới nhất (nhớ chạy khi TV1 vừa nâng cấp `nginx.conf`/script):

```bash
git checkout main && git pull
git checkout feat/tv2-vhost && git rebase main
```

---

## 5. Cài đặt & deploy trên máy local

### 5.1. Chạy script thiết lập (`00_setup_vm.sh`)

```bash
bash scripts/00_setup_vm.sh
```

Script làm 6 việc (idempotent — chạy lại an toàn):

1. Kiểm tra distro là Ubuntu (cảnh báo nếu không phải 22.04).
2. Tạo swap **1GB** (bỏ qua nếu đã có swap; bỏ qua trên WSL — cấu hình bằng `.wslconfig`).
3. Thêm domain test (`site1.local`, `site2.local`, `app.local`, `limit.local`) vào `/etc/hosts` (dùng marker `# nginx-lab domains`).
4. `apt-get update` và cài: `nginx`, `curl`, `apache2-utils` (chứa `ab`), `openssl`, `ca-certificates`, `python3`.
5. Bật và khởi động Nginx qua `systemd` (fallback `service` nếu WSL chưa bật systemd).
6. In phiên bản `nginx`, `ab`, `python3`, `openssl` và kiểm tra domain test.

### 5.2. Deploy cấu hình nền (`02_deploy_config.sh`)

```bash
bash scripts/02_deploy_config.sh
```

Script sẽ: xoá site mặc định (nhường port 80) → copy `nginx/nginx.conf`, `nginx/conf.d/*.conf`,
`www/*`, `ssl/*` (nếu có) vào hệ thống → `nginx -t` → reload.

> Ở Giai đoạn 0, `conf.d/*` và `ssl/` còn rỗng nên sẽ thấy cảnh báo "chưa có cert" —
> **bình thường**. Lúc đó chỉ có `nginx.conf` nền được nạp.

### 5.3. Sinh chứng chỉ (chỉ khi làm Demo 2 — TV3)

```bash
bash scripts/01_generate_ssl.sh
bash scripts/02_deploy_config.sh   # deploy lại để copy cert vào /etc/nginx/ssl
```

### Tính idempotent & biến tùy chỉnh

| Biến | Mặc định | Ý nghĩa |
|------|----------|---------|
| `SWAPFILE` | `/swapfile` | Đường dẫn file swap |
| `SWAP_SIZE` | `1G` | Kích thước swap |

```bash
SWAP_SIZE=2G bash scripts/00_setup_vm.sh
```

---

## 6. Kiểm tra & cổng sẵn sàng (Definition of Done của Stage 0)

Chạy và đối chiếu — **đủ hết các dòng dưới là sẵn sàng làm việc**:

| Lệnh | Kết quả mong đợi | Ý nghĩa |
|------|------------------|---------|
| `free -h` | có dòng `Swap: 1.0Gi` | Task 0.1 |
| `nginx -v` | `nginx/1.18.0 (Ubuntu)` | Task 0.2 |
| `ab -V \| head -n1` | ApacheBench | Task 0.2 |
| `python3 --version` | `Python 3.10.x` | Task 0.2 |
| `openssl version` | OpenSSL 3.x | Task 0.2 |
| `getent hosts site1.local limit.local` | `127.0.0.1 ...` | Task 0.3 |
| `sudo nginx -t` | `test is successful` | Task 0.4/0.5 |
| `systemctl status nginx` | `active (running)` | Task 0.5 |
| `git status` | đang ở nhánh `feat/tvX-...` | Sẵn sàng sửa code |

> `curl -I http://127.0.0.1/` chưa cần trả 200 ở bước này — vhost chưa được viết (thuộc Stage 1–3).

---

## 7. Demo trên VM & chụp ảnh minh chứng

Lab yêu cầu **chụp hình trang lỗi trên trình duyệt** (Demo 4). Cách chọn: **demo và chụp ngay trên VM** —
khi đó **không cần** sửa hosts trên máy host, **không cần** port-forward.

- **Mạng VM:** dùng **NAT (mặc định)** là đủ. Trình duyệt trong VM truy cập `*.local` qua `/etc/hosts` nội bộ (mục 5.1).
- **Trình duyệt:** cài headless browser để **giữ đúng 512MB RAM** (không cài desktop).

### 7.1. Cài browser headless

```bash
# Cách A (khuyến nghị, nhẹ, apt-native): wkhtmltoimage
sudo apt-get install -y wkhtmltopdf

# Cách B: Chromium headless (Ubuntu 22.04 cài qua snap, nặng hơn)
sudo apt-get install -y chromium-browser
```

Hoặc cài kèm khi dựng môi trường: `INSTALL_BROWSER=1 bash scripts/00_setup_vm.sh`.

### 7.2. Lệnh chụp ảnh

```bash
# Demo 4 — trang lỗi tùy chỉnh (tắt backend trước)
wkhtmltoimage --load-error-handling ignore https://app.local/ /tmp/demo4_error.png
# hoặc Chromium:
chromium-browser --headless --no-sandbox --ignore-certificate-errors \
  --screenshot=/tmp/demo4_error.png https://app.local/

# Demo 1 — 2 site tĩnh
wkhtmltoimage http://site1.local/ /tmp/demo1_site1.png
wkhtmltoimage http://site2.local/ /tmp/demo1_site2.png

# Demo 2 — HTTPS (self-signed; chấp nhận cảnh báo cert)
wkhtmltoimage --load-error-handling ignore https://app.local/ /tmp/demo2_https.png
```

### 7.3. Đưa ảnh về repo

```bash
mkdir -p docs/screenshots
cp /tmp/demo*.png docs/screenshots/
git add docs/screenshots/ && git commit -m "docs(demo): add screenshots"
```

> **Ràng buộc:** headless giữ đúng **1 VM (512MB)**. Nếu chọn desktop GUI + browser tương tác để ảnh
> trực quan hơn thì phải nâng RAM VM (~2GB) — ghi chú rõ trong báo cáo vì lệch spec.
> Ảnh headless là minh chứng hợp lệ cho "chụp hình trên trình duyệt".

## 8. Chuẩn bị sửa & đẩy code

| Yêu cầu | Lệnh / cách làm |
|---------|-----------------|
| Danh tính Git | đã đặt ở mục 4.1 |
| Quyền đẩy code | SSH key (mục 4.1) hoặc HTTPS + Personal Access Token |
| Trình soạn thảo | `nano` (mặc định), `vim`, hoặc VS Code |
| Quyền sudo để deploy | cần cho `scripts/02_deploy_config.sh` |

Quy trình sửa → đẩy:

```bash
git checkout -b feat/tv2-vhost
nano nginx/conf.d/01_vhost_sites.conf
git add nginx/conf.d/01_vhost_sites.conf
git commit -m "feat(vhost): add site1 and site2 server blocks"
git push -u origin feat/tv2-vhost
```

Sau đó mở **Pull Request** để nhóm review (xem [`collaboration.md`](./collaboration.md)).

**Soạn thảo từ máy host (không cần editor trong VM):**

- **VS Code + Remote - SSH:** cài extension *Remote - SSH*, connect `ssh user@<ip>`, mở repo và sửa.
- **WSL2:** cài extension *WSL*, gõ `code .` trong WSL.
- **Chia sẻ thư mục:** VirtualBox/VMware Shared Folder hoặc `scp` qua lại.

> An toàn: không commit `ssl/server.key`, `__pycache__`, log runtime — `.gitignore` đã chặn.

---

## 9. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `systemctl: command not found` | WSL chưa bật systemd | Bật `systemd=true` trong `/etc/wsl.conf`, `wsl --shutdown`, mở lại |
| `fallocate: Operation not supported` | Filesystem không hỗ trợ | Script tự fallback `dd` |
| Nginx không start | Port 80 bị chiếm | `sudo ss -ltnp \| grep :80` |
| `nginx -t` fail | Vhost tham chiếu cert chưa sinh | Chạy `01_generate_ssl.sh` rồi deploy lại |
| Hết RAM khi benchmark | VM 512MB | Thêm swap / tạm tăng RAM VM |
| `apt` báo lock | Tiến trình apt khác đang chạy | Đợi hoặc `sudo pkill apt` rồi chạy lại |
| `git clone ... Permission denied (publickey)` | Chưa thêm SSH key | Dùng HTTPS, hoặc thêm key vào GitHub |
| `Repository not found` | Sai URL hoặc chưa có quyền | Kiểm tra URL & quyền truy cập |
| `Could not resolve host: site1.local` | Chưa thêm `/etc/hosts` | Chạy lại `00_setup_vm.sh` |

---

## 10. Khác biệt theo thành viên (trước khi bắt đầu việc riêng)

| TV | Sau checklist 1–5 cần thêm | Bắt đầu việc gì |
|----|----------------------------|-----------------|
| **TV1** | không | Hoàn thiện/sửa `nginx.conf`, `02_deploy_config.sh` (đã có sẵn) |
| **TV2** | không | `01_vhost_sites.conf`, `www/site1`, `www/site2` |
| **TV3** | chạy `01_generate_ssl.sh` (mục 5.3) | `02_reverse_proxy.conf`, `backend/app.py` |
| **TV4** | không | `03_rate_limit.conf`, `03_run_benchmark.sh` |
| **TV5** | không | `custom_50x.html`, `04_collect_logs.sh`, `docs/` |

> Mọi TV đều đã có: VM Ubuntu, repo, swap, hosts, Nginx + `nginx.conf` nền đã deploy.

---

## 11. Liên hệ với các task

- Checklist mục 2 thực hiện **Task 0.1–0.5** trong [`tasks.md`](./tasks.md):
  `00_setup_vm.sh` (0.1–0.3), `nginx/nginx.conf` (0.4), `02_deploy_config.sh` (0.5).
- Sau khi xong, mở 3 track song song: [Stage 1](./stages/stage-1-vhost.md),
  [Stage 2](./stages/stage-2-reverse-proxy.md), [Stage 3](./stages/stage-3-rate-limit.md) — xem [`tasks.md`](./tasks.md) mục *"Sơ đồ làm việc & Timeline"*.
- Giao diện chung: [`interfaces.md`](./interfaces.md). Vai trò file: [`files.md`](./files.md).
- Chi tiết code & nguyên lý Stage 0: [`stages/stage-0-infra.md`](./stages/stage-0-infra.md).
