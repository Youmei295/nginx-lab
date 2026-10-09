#!/usr/bin/env bash
#
# 00_setup_vm.sh — Chuẩn bị môi trường Ubuntu 22.04 cho lab Nginx.
#
# Chạy BÊN TRONG máy Linux (VM Hyper-V/VirtualBox/VMware/UTM hoặc WSL2),
# KHÔNG tạo máy ảo. Việc tạo VM là bước thủ công, xem docs/environment.md.
#
# Idempotent: chạy lại nhiều lần vẫn an toàn (bỏ qua bước đã hoàn thành).
#
# Cách dùng:
#   bash scripts/00_setup_vm.sh
#
set -euo pipefail

SWAPFILE="${SWAPFILE:-/swapfile}"
SWAP_SIZE="${SWAP_SIZE:-1G}"
INSTALL_BROWSER="${INSTALL_BROWSER:-0}"
APT_PACKAGES=(nginx curl apache2-utils openssl ca-certificates python3)

log()  { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# --- 0. Kiểm tra nền tảng ------------------------------------------------
[[ -r /etc/os-release ]] || die "Không đọc được /etc/os-release; script chỉ hỗ trợ Ubuntu."
# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  die "Script chỉ hỗ trợ Ubuntu (phát hiện: ${ID:-unknown})."
fi
if [[ "${VERSION_ID:-}" != "22.04" ]]; then
  warn "Khuyến nghị Ubuntu 22.04, hiện tại là ${VERSION_ID:-unknown}."
fi

IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  IS_WSL=1
fi

# --- 1. Quyền root / sudo ------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
  log "Chạy với sudo (cần nhập mật khẩu nếu được hỏi)."
else
  die "Cần chạy bằng root hoặc có sẵn sudo."
fi

# --- 2. Swap -------------------------------------------------------------
if [[ -n "$(swapon --show --noheadings 2>/dev/null || true)" ]]; then
  log "Swap đã tồn tại, bỏ qua bước tạo swap."
elif [[ "${IS_WSL}" -eq 1 ]]; then
  warn "Phát hiện WSL: bỏ qua tạo swapfile."
  warn "Muốn thêm swap, cấu hình trong %USERPROFILE%\\.wslconfig trên Windows, ví dụ:"
  warn "  [wsl2]"
  warn "  swap=1GB"
else
  log "Tạo swap ${SWAP_SIZE} tại ${SWAPFILE}..."
  if [[ ! -f "${SWAPFILE}" ]]; then
    if ! "${SUDO[@]}" fallocate -l "${SWAP_SIZE}" "${SWAPFILE}" 2>/dev/null; then
      warn "fallocate thất bại, dùng dd (chậm hơn)..."
      "${SUDO[@]}" dd if=/dev/zero of="${SWAPFILE}" bs=1M count=1024 status=progress
    fi
  fi
  "${SUDO[@]}" chmod 600 "${SWAPFILE}"
  if ! "${SUDO[@]}" mkswap "${SWAPFILE}" >/dev/null; then
    warn "mkswap báo lỗi (có thể swap đã được kích hoạt)."
  fi
  if ! "${SUDO[@]}" swapon "${SWAPFILE}" 2>/dev/null; then
    warn "Không bật được ${SWAPFILE} (có thể đã bật)."
  fi
  if ! grep -qE "^[[:space:]]*${SWAPFILE}[[:space:]]" /etc/fstab; then
    log "Thêm ${SWAPFILE} vào /etc/fstab để bền vững sau reboot..."
    printf '%s none swap sw 0 0\n' "${SWAPFILE}" | "${SUDO[@]}" tee -a /etc/fstab >/dev/null
  fi
fi

# --- 3. Domain test trong /etc/hosts ------------------------------------
HOSTS_MARKER="# nginx-lab domains"
HOSTS_LINE="127.0.0.1 site1.local site2.local app.local limit.local"
if grep -qF "${HOSTS_MARKER}" /etc/hosts 2>/dev/null; then
  log "Domain test đã có trong /etc/hosts, bỏ qua."
else
  log "Thêm domain test vào /etc/hosts..."
  printf '\n%s\n%s\n' "${HOSTS_MARKER}" "${HOSTS_LINE}" | "${SUDO[@]}" tee -a /etc/hosts >/dev/null
fi

# --- 4. Cài đặt gói ------------------------------------------------------
log "Cập nhật chỉ mục apt..."
"${SUDO[@]}" apt-get update -y

log "Cài đặt: ${APT_PACKAGES[*]}"
"${SUDO[@]}" DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  "${APT_PACKAGES[@]}"

# --- 4b. Browser headless cho demo trên VM (tùy chọn) --------------------
if [[ "${INSTALL_BROWSER}" == "1" ]]; then
  log "Cài wkhtmltopdf để chụp ảnh minh chứng (headless, nhẹ)..."
  if ! "${SUDO[@]}" DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wkhtmltopdf; then
    warn "Không cài được wkhtmltopdf; thử chromium-browser (qua snap)..."
    "${SUDO[@]}" DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser \
      || warn "Không cài được browser headless; xem docs/environment.md mục 7."
  fi
fi

# --- 5. Bật / khởi động Nginx -------------------------------------------
if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl enable nginx >/dev/null 2>&1 || true
  if ! "${SUDO[@]}" systemctl restart nginx 2>/dev/null; then
    "${SUDO[@]}" systemctl start nginx || warn "Không khởi động được nginx qua systemctl."
  fi
else
  warn "systemd không khả dụng (thường gặp ở WSL không bật systemd)."
  warn "Thử: service nginx start  (hoặc bật systemd: xem docs/environment.md)."
  "${SUDO[@]}" service nginx start 2>/dev/null || true
fi

# --- 6. Kiểm tra kết quả -------------------------------------------------
log "Phiên bản công cụ:"
nginx -v 2>&1 || warn "nginx chưa sẵn sàng"
ab -V 2>&1 | head -n 1 || warn "ab chưa sẵn sàng"
python3 --version 2>&1 || warn "python3 chưa sẵn sàng"
openssl version 2>&1 || warn "openssl chưa sẵn sàng"
log "Domain test: $(getent hosts site1.local || echo 'CHƯA resolve')"

log "Hoàn tất thiết lập môi trường."
log "Bước tiếp theo (mọi người): bash scripts/02_deploy_config.sh"
log "Chỉ khi làm Demo 2 (TV3): bash scripts/01_generate_ssl.sh rồi deploy lại."
