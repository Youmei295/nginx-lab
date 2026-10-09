# Giai đoạn 0 — Hạ tầng & Chuẩn bị

> Tài liệu kỹ thuật (không phải báo cáo). Mục tiêu: giải thích **code dùng gì, chạy thế nào, vì sao làm vậy**.
> Nhiệm vụ tương ứng: **Task 0.1–0.5** trong [`../tasks.md`](../tasks.md). Phụ trách: **TV1**.

---

## 1. Mục tiêu giai đoạn

Dựng nền móng để mọi demo sau chạy được trên **1 VM Ubuntu 22.04 (512MB RAM)**:

1. Đủ tài nguyên (swap) để không bị OOM khi benchmark.
2. Đủ công cụ: `nginx`, `curl`, `ab`, `openssl`, `python3`.
3. Phân giải các tên miền test về `127.0.0.1` (chưa có DNS thật).
4. Cấu hình nền Nginx (worker, log có timing).
5. Cơ chế deploy: đưa config/content từ repo vào hệ thống đúng chuẩn và idempotent.

## 2. File liên quan

| File | Vai trò | Task |
|------|---------|------|
| `scripts/00_setup_vm.sh` | Tạo swap, thêm `/etc/hosts`, cài gói, khởi động Nginx | 0.1, 0.2, 0.3 |
| `nginx/nginx.conf` | Cấu hình nền: `worker_processes`, `events`, `log_format` | 0.4 |
| `scripts/02_deploy_config.sh` | Copy config/www/cert vào hệ thống + `nginx -t` + reload | 0.5 |
| `docs/environment.md` | Hướng dẫn dựng VM (Hyper-V/VirtualBox/VMware/UTM/WSL2) | 0.1 |
| `docs/interfaces.md` | Chốt domain/đường dẫn đích dùng bởi script 02 | Quản lý chung |

## 3. Bức tranh tổng thể

```
[Repo]                                   [Hệ thống Ubuntu 22.04]
scripts/00_setup_vm.sh  ── cài ──>  nginx, ab, curl, openssl, python3
                         ── tạo ──>  /swapfile (1GB) + /etc/fstab
                         ── thêm ──> /etc/hosts: site1.local ... → 127.0.0.1

nginx/nginx.conf        ── deploy ─> /etc/nginx/nginx.conf
nginx/conf.d/*.conf     ── deploy ─> /etc/nginx/conf.d/
www/*                   ── deploy ─> /usr/share/nginx/{html,error_pages}/
ssl/*                   ── deploy ─> /etc/nginx/ssl/

scripts/02_deploy_config.sh ──> xoá sites-enabled/default ──> nginx -t ──> reload
```

## 4. Nguyên lý cốt lõi (vì sao, không chỉ làm gì)

| Nguyên lý | Giải thích |
|-----------|-----------|
| **Swap cho VM nhỏ** | 512MB RAM không đủ khi Nginx + backend + `ab` chạy 100 kết nối đồng thời. Swap 1GB là "van an toàn" chống OOM, giúp số liệu benchmark ổn định. |
| **Idempotent** | Mỗi thành viên tự chạy script trên máy mình; chạy lại phải an toàn (không tạo swap trùng, không ghi trùng `/etc/fstab`). |
| **`set -euo pipefail`** | Dừng ngay khi có lệnh lỗi, biến chưa khai báo, hoặc lỗi trong pipeline → tránh "thành công giả". |
| **Domain qua `/etc/hosts`** | Không có DNS thật cho `.local`. Dùng hosts để Nginx nhận đúng header `Host`, mô phỏng nhiều site trên 1 IP. |
| **Tách `nginx.conf` và `conf.d/`** | `nginx.conf` là khung chung (không đổi theo demo); `conf.d/*.conf` là từng demo độc lập, dễ review/PR. |
| **`log_format` có timing** | `$request_time` / `$upstream_response_time` là dữ liệu để phân tích 502/503/504 và độ trễ backend ở giai đoạn sau. |
| **Deploy tập trung** | Con người không sửa tay `/etc/nginx`; mọi thay đổi đi qua repo → script copy → `nginx -t` → reload. Đảm bảo "repo là nguồn chân lý". |
| **Xoá site default** | Ubuntu cài sẵn `sites-enabled/default` chiếm port 80; phải xoá để vhost của nhóm được phục vụ. |

## 5. Chi tiết `scripts/00_setup_vm.sh`

### 5.1. Phát hiện nền tảng & quyền

```bash
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  die "Script chỉ hỗ trợ Ubuntu (phát hiện: ${ID:-unknown})."
fi

IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  IS_WSL=1
fi
```

- Đọc `/etc/os-release` để chắc chắn là Ubuntu (script dùng `apt`).
- Phát hiện WSL để **bỏ qua tạo swap** (swap do Windows quản qua `.wslconfig`).
- Chọn `SUDO=()` nếu đang là root, ngược lại dùng `sudo`.

### 5.2. Tạo swap (chỉ khi chưa có)

```bash
if [[ -n "$(swapon --show --noheadings 2>/dev/null || true)" ]]; then
  log "Swap đã tồn tại, bỏ qua bước tạo swap."
else
  "${SUDO[@]}" fallocate -l "${SWAP_SIZE}" "${SWAPFILE}" \
    || "${SUDO[@]}" dd if=/dev/zero of="${SWAPFILE}" bs=1M count=1024
  "${SUDO[@]}" chmod 600 "${SWAPFILE}"
  "${SUDO[@]}" mkswap "${SWAPFILE}"
  "${SUDO[@]}" swapon  "${SWAPFILE}"
fi
```

- `swapon --show` đảm bảo idempotent: đã có swap thì thôi.
- `fallocate` nhanh; nếu filesystem không hỗ trợ thì fallback `dd`.
- Dòng `/swapfile none swap sw 0 0` chỉ ghi vào `/etc/fstab` **một lần** (kiểm tra `grep -qE`), để swap tồn tại sau reboot.

### 5.3. Thêm domain test vào `/etc/hosts` (idempotent bằng marker)

```bash
HOSTS_MARKER="# nginx-lab domains"
HOSTS_LINE="127.0.0.1 site1.local site2.local app.local limit.local"
if grep -qF "${HOSTS_MARKER}" /etc/hosts 2>/dev/null; then
  log "Domain test đã có trong /etc/hosts, bỏ qua."
else
  printf '\n%s\n%s\n' "${HOSTS_MARKER}" "${HOSTS_LINE}" \
    | "${SUDO[@]}" tee -a /etc/hosts >/dev/null
fi
```

- Dùng **marker comment** thay vì dò từng domain → chạy lại không chèn trùng.
- Danh sách domain lấy từ [`../interfaces.md`](../interfaces.md) mục 1.

### 5.4. Cài gói & khởi động Nginx

```bash
APT_PACKAGES=(nginx curl apache2-utils openssl ca-certificates python3)
"${SUDO[@]}" DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"
```

- `apache2-utils` cung cấp `ab` (ApacheBench) cho Demo 3.
- `python3` là backend mock (không dependency).
- Khởi động: ưu tiên `systemctl`, fallback `service` cho WSL không bật systemd.

## 6. Chi tiết `nginx/nginx.conf`

```nginx
worker_processes  auto;
events {
    worker_connections  2048;
    multi_accept        on;
}

log_format main_ext '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" "$http_user_agent" '
                    'rt=$request_time urt=$upstream_response_time';

access_log /var/log/nginx/access.log main_ext;
error_log  /var/log/nginx/error.log warn;

include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*;
```

| Directive | Ý nghĩa |
|-----------|---------|
| `worker_processes auto` | Số tiến trình worker = số CPU. Mô hình event-driven: 1 worker phục vụ nhiều kết nối. |
| `worker_connections 2048` | Mỗi worker giữ tối đa 2048 kết nối → đủ cho `ab -c 100`. |
| `multi_accept on` | Worker nhận nhiều kết nối mới mỗi lần thức dậy. |
| `main_ext` | Log format mở rộng, thêm `rt` (request time) và `urt` (upstream response time). |
| `include conf.d/*.conf` | Nơi chứa các demo (vhost, proxy, rate limit). |
| `ssl_protocols TLSv1.2 TLSv1.3` | Tắt TLS cũ không an toàn. |

> **Liên hệ lý thuyết:** `worker_processes` + `worker_connections` là minh chứng cho mô hình
> event-driven so với process/thread của Apache (Phần A.2 của báo cáo).

## 7. Chi tiết `scripts/02_deploy_config.sh`

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

Tự xác định gốc repo để chạy được từ bất kỳ thư mục nào.

### 7.1. Xoá site default

```bash
if [[ -e "${NGINX_DIR}/sites-enabled/default" ]]; then
  "${SUDO[@]}" rm -f "${NGINX_DIR}/sites-enabled/default"
fi
```

Vì sao: nếu còn default, request tới port 80 có thể rơi vào trang mặc định thay vì vhost nhóm.

### 7.2. Copy & reload

```bash
"${SUDO[@]}" nginx -t
"${SUDO[@]}" systemctl reload nginx 2>/dev/null || "${SUDO[@]}" systemctl restart nginx
```

- **Luôn `nginx -t` trước reload**: cấu hình sai sẽ không được nạp, tránh sập Nginx đang chạy.
- `reload` gián đoạn tối thiểu; `restart` chỉ dùng khi `reload` thất bại.

### 7.3. Đường dẫn đích

Theo [`../interfaces.md`](../interfaces.md) mục 3:

| Nguồn repo | Đích |
|------------|------|
| `nginx/nginx.conf` | `/etc/nginx/nginx.conf` |
| `nginx/conf.d/*.conf` | `/etc/nginx/conf.d/` |
| `www/site1`, `www/site2` | `/usr/share/nginx/html/` |
| `www/error_pages/` | `/usr/share/nginx/error_pages/` |
| `ssl/*.crt`, `ssl/*.key` | `/etc/nginx/ssl/` |

## 8. Chạy & kiểm chứng

```bash
# 1) Dựng môi trường (mỗi thành viên chạy 1 lần)
bash scripts/00_setup_vm.sh

# 2) Deploy config nền (conf.d hiện đang rỗng nên chỉ nạp nginx.conf)
bash scripts/02_deploy_config.sh
```

**Kết quả mong đợi:**

| Lệnh | Mong đợi |
|------|----------|
| `free -h` | có dòng `Swap: 1.0Gi` |
| `python3 --version` | `Python 3.10.x` |
| `getent hosts site1.local` | `127.0.0.1 site1.local ...` |
| `sudo nginx -t` | `syntax is ok` / `test is successful` |
| `systemctl status nginx` | `active (running)` |
| `curl -I http://127.0.0.1/` | có phản hồi HTTP (khi đã có vhost) |

> Xác thực nội bộ: `nginx/nginx.conf` + `02_deploy_config.sh` đã được kiểm tra bằng
> `nginx -t` trên **Ubuntu 22.04 / nginx 1.18** và deploy chạy **idempotent** (chạy 2 lần đều `EXIT=0`).

## 9. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|-------------|-------------|-------|
| `systemctl: command not found` | WSL chưa bật systemd | `systemd=true` trong `/etc/wsl.conf` rồi `wsl --shutdown` |
| `fallocate: Operation not supported` | Filesystem không hỗ trợ | Script tự fallback `dd` |
| Nginx không start | Port 80 bị chiếm | `sudo ss -ltnp \| grep :80` |
| `nginx -t` fail sau deploy | Vhost tham chiếu cert chưa sinh | Chạy `scripts/01_generate_ssl.sh` trước |
| Chạy lại script báo swap lỗi | Swap đã bật | Vô hại — script bỏ qua khi `swapon --show` có dữ liệu |

## 10. Truy cập & demo trên VM

Nhóm chọn **demo và chụp ảnh ngay trên VM** để giữ đúng spec **1 VM (512MB)**:

- Mạng VM: **NAT (mặc định)** là đủ — không cần host changes/port-forward.
- `/etc/hosts` nội bộ VM (task 0.3) khiến `site1.local`, `site2.local`, `app.local`, `limit.local` trỏ về `127.0.0.1`.
- Chụp ảnh minh chứng bằng **headless browser** (giữ 512MB), cài qua `INSTALL_BROWSER=1 bash scripts/00_setup_vm.sh`.
- Chi tiết lệnh chụp ảnh: [`../environment.md`](../environment.md) mục 7.

> Vì sao không cần sửa hosts máy host: trình duyệt chạy trong VM, dùng chính `/etc/hosts` của VM.

## 11. Liên hệ giai đoạn sau

- Giai đoạn 0 xong → mở **3 track song song**: [Stage 1 — Virtual Host](./stage-1-vhost.md),
  [Stage 2 — Reverse Proxy & HTTPS](./stage-2-reverse-proxy.md), [Stage 3 — Rate Limiting](./stage-3-rate-limit.md).
- `log_format main_ext` ở đây là dữ liệu đầu vào cho [Stage 4 — Troubleshooting](./stage-4-troubleshooting.md)
  và [Stage 5 — Log & Báo cáo](./stage-5-logs-report.md).
- Sơ đồ phụ thuộc đầy đủ: [`../tasks.md`](../tasks.md) (mục *"Sơ đồ làm việc & Timeline"*).
