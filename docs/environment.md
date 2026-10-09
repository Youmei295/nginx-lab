# Môi trường làm việc (Environment) — Ubuntu 22.04

> Lab CSC-11117 — Linux OS And Applications
> Tài liệu này quy định **nền tảng chuẩn** và cách dựng môi trường cho từng thành viên,
> để `scripts/00_setup_vm.sh` cho kết quả giống nhau dù host khác nhau.

---

## 1. Nguyên tắc

- **Nền tảng hỗ trợ duy nhất: Ubuntu Server 22.04 LTS (64-bit).**
- Hyper-V / VirtualBox / VMware / UTM (macOS) chỉ là lớp host — tất cả đều chạy **cùng một image Ubuntu 22.04**.
- **Tạo máy ảo là bước thủ công** (không nằm trong script). Script `00_setup_vm.sh` chạy **bên trong** Ubuntu.
- WSL2 được chấp nhận cho việc **test cá nhân**, nhưng cần cấu hình thêm (mục 3) và **không thay thế** VM khi trình diễn.
- Khi ghép nhóm / trình diễn cuối: dùng **1 VM Ubuntu 22.04 chung** đúng yêu cầu "1 VM (512MB RAM)".

### Vì sao phải chuẩn hóa?

`00_setup_vm.sh` dùng `apt`, `systemctl`, `swapon` — đặc thù Ubuntu. Nếu mỗi người dùng distro/host khác nhau, lệnh có thể sai hoặc cho kết quả khác nhau (đặc biệt WSL2 không có systemd mặc định và không tự tạo swap).

---

## 2. Tạo máy ảo theo từng host

### Hyper-V (Windows Pro/Enterprise)

1. Bật tính năng: Windows Features → tích **Hyper-V** → restart.
2. Tải ISO **Ubuntu Server 22.04** tại <https://ubuntu.com/download/server>.
3. **Hyper-V Manager** → *New* → *Virtual Machine*:
   - Generation: **Gen 2**
   - RAM: **512 MB** (thêm *Dynamic Memory* nếu muốn)
   - Network: **Default Switch**
4. Gắn ISO, cài Ubuntu (chọn OpenSSH server khi được hỏi).
5. Sau khi cài, cấp IP bằng `ip a` và SSH vào để chạy script.

### VirtualBox

1. Tải ISO Ubuntu Server 22.04.
2. New VM: Type Linux / Version **Ubuntu (64-bit)**, RAM **512 MB**, tạo disk ~10GB.
3. Cài đặt bình thường, bật **OpenSSH server**.
4. (Tùy chọn) Network → **Bridged Adapter** để truy cập từ máy khác.

### VMware Workstation / Fusion

1. New VM → chọn ISO → **Ubuntu 64-bit**, RAM 512 MB.
2. Bật OpenSSH trong lúc cài.
3. Network: **NAT** hoặc **Bridged**.

### UTM (macOS, Apple Silicon)

1. UTM → *Create a New Virtual Machine* → **Virtualize** → Linux.
2. Chọn ISO Ubuntu Server **arm64** 22.04, RAM 512 MB.
3. Cài đặt, bật OpenSSH server.
4. Network: **Shared Network** (mặc định) hoặc Bridged.

### WSL2 (chỉ để test cá nhân)

Trên Windows, PowerShell (quyền admin):

```powershell
wsl --install -d Ubuntu-22.04
```

Sau đó bật systemd bên trong WSL (cần thiết để `systemctl` quản lý Nginx):

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

## 3. Lấy mã nguồn và chạy script thiết lập

### 3.1. Clone repo về máy

Sau khi đã có Ubuntu 22.04 (VM hoặc WSL2), cài `git` (nếu chưa có) và clone repo:

```bash
sudo apt-get update && sudo apt-get install -y git

# Khuyến nghị dùng SSH (cần thêm public key vào GitHub)
git clone git@github.com:Youmei295/nginx-lab.git nginx-lab-project

# Hoặc dùng HTTPS nếu chưa cấu hình SSH
git clone https://github.com/Youmei295/nginx-lab.git nginx-lab-project

cd nginx-lab-project
```

Nếu đã clone trước đó, cập nhật code mới nhất:

```bash
cd nginx-lab-project
git pull
```

> Tạo nhánh riêng cho phần việc của mình: `git checkout -b feat/tv2-vhost`.

### 3.2. Chạy script

Từ thư mục repo:

```bash
bash scripts/00_setup_vm.sh
```

Script sẽ:

1. Kiểm tra distro là Ubuntu (cảnh báo nếu không phải 22.04).
2. Tạo swap **1GB** (bỏ qua nếu đã có swap; bỏ qua trên WSL — cấu hình bằng `.wslconfig`).
3. Thêm domain test (`site1.local`, `site2.local`, `app.local`, `limit.local`) vào `/etc/hosts` (idempotent, dùng marker `# nginx-lab domains`).
4. `apt-get update` và cài: `nginx`, `curl`, `apache2-utils` (chứa `ab`), `openssl`, `ca-certificates`, `python3`.
5. Bật và khởi động Nginx qua `systemd` (fallback `service` nếu WSL chưa bật systemd).
6. In phiên bản `nginx`, `ab`, `python3`, `openssl` và kiểm tra domain test resolve.

### 3.3. Chuẩn bị để sửa & đẩy code

Để **sửa repo local và đưa thay đổi lên GitHub**, mỗi thành viên cần:

| Yêu cầu | Lệnh / cách làm |
|---------|-----------------|
| **Git đã cài** | `git --version` (nếu thiếu: `sudo apt-get install -y git`) |
| **Danh tính Git** (bắt buộc để commit) | `git config --global user.name "Tên"` và `git config --global user.email "email@example.com"` |
| **Quyền đẩy code** (một trong hai) | **SSH:** tạo key `ssh-keygen -t ed25519`, dán `~/.ssh/id_ed25519.pub` vào GitHub → Settings → SSH keys. Hoặc **HTTPS:** dùng Personal Access Token thay mật khẩu |
| **Trình soạn thảo** trên Ubuntu | `nano` (mặc định), `vim`, hoặc VS Code |
| **Quyền sudo** để deploy | Cần cho `scripts/02_deploy_config.sh` (ghi vào `/etc/nginx/`) |

Quy trình sửa → đẩy:

```bash
git checkout -b feat/tv2-vhost      # tạo nhánh cho phần việc
nano nginx/conf.d/01_vhost_sites.conf
git add nginx/conf.d/01_vhost_sites.conf
git commit -m "feat(vhost): add site1 and site2 server blocks"
git push -u origin feat/tv2-vhost
```

Sau đó mở **Pull Request** trên GitHub để cả nhóm review trước khi merge vào `main`.

**Soạn thảo từ máy host (không cần editor trong VM):**

- **VS Code + Remote - SSH:** cài extension *Remote - SSH*, connect tới VM (`ssh user@<ip>`), mở thư mục repo và sửa trực tiếp.
- **WSL2:** cài extension *WSL* trong VS Code, gõ `code .` từ trong WSL.
- **Chia sẻ thư mục:** VirtualBox/VMware Shared Folder hoặc `scp` file qua lại.

> An toàn: không commit `ssl/server.key`, `__pycache__`, log runtime — `.gitignore` đã chặn sẵn.

### Tính idempotent

Chạy lại script **không gây lỗi**: swap đã tồn tại sẽ bị bỏ qua, gói đã cài sẽ không cài lại, `/etc/fstab` không bị ghi trùng.

### Biến tùy chỉnh

| Biến | Mặc định | Ý nghĩa |
|------|----------|---------|
| `SWAPFILE` | `/swapfile` | Đường dẫn file swap |
| `SWAP_SIZE` | `1G` | Kích thước swap |

Ví dụ:

```bash
SWAP_SIZE=2G bash scripts/00_setup_vm.sh
```

---

## 4. Kiểm tra sau khi chạy

```bash
free -h                 # thấy dòng Swap: 1.0Gi
nginx -v                # nginx/1.18.0 (Ubuntu)
ab -V | head -n1        # ApacheBench
python3 --version       # Python 3.10.x (có sẵn trên Ubuntu 22.04)
openssl version
systemctl status nginx  # active (running)  — hoặc 'service nginx status' trên WSL cũ
curl -I http://127.0.0.1 # HTTP/1.1 200 OK
getent hosts site1.local limit.local  # phải trả về 127.0.0.1
```

---

## 5. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `systemctl: command not found` / không quản lý được service | WSL chưa bật systemd | Bật `systemd=true` trong `/etc/wsl.conf`, chạy `wsl --shutdown`, mở lại |
| `fallocate: Operation not supported` | Filesystem không hỗ trợ | Script tự fallback sang `dd` |
| Nginx không start | Port 80 bị chiếm | `sudo ss -ltnp | grep :80` để tìm tiến trình |
| Hết RAM khi benchmark | VM chỉ 512MB | Thêm swap (script đã làm) hoặc tạm tăng RAM VM |
| `apt` báo lock | Tiến trình apt khác đang chạy | Đợi hoặc `sudo pkill apt` rồi chạy lại |
| `git clone ... Permission denied (publickey)` | Chưa thêm SSH key vào GitHub | Dùng HTTPS, hoặc thêm key: `ssh-keygen -t ed25519` rồi dán `~/.ssh/id_ed25519.pub` vào GitHub → Settings → SSH keys |
| `Repository not found` | Sai URL hoặc chưa có quyền | Kiểm tra lại URL repo và quyền truy cập |

---

## 6. Liên hệ với các task

- Script này thực hiện **Task 0.1** (swap), **Task 0.2** (cài công cụ) và **Task 0.3** (domain test) trong [`tasks.md`](./tasks.md).
- Sau bước này, mỗi thành viên có thể chạy song song Demo 1, Demo 2, Demo 3 (xem [`tasks.md`](./tasks.md)).
- Giao diện chung (domain, cổng) xem [`interfaces.md`](./interfaces.md). Vai trò file chi tiết xem [`files.md`](./files.md).
