#!/usr/bin/env bash
#
# 02_deploy_config.sh — Copy cấu hình Nginx và web content từ repo vào hệ thống.
#
# Idempotent: chạy lại nhiều lần vẫn an toàn.
# Đường dẫn đích xem docs/interfaces.md mục 3.
#
# Cách dùng:
#   bash scripts/02_deploy_config.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NGINX_DIR="/etc/nginx"
CONF_DEST="${NGINX_DIR}/conf.d"
WEB_ROOT="/usr/share/nginx/html"
ERR_ROOT="/usr/share/nginx/error_pages"
SSL_DEST="${NGINX_DIR}/ssl"

log()  { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  die "Cần chạy bằng root hoặc có sẵn sudo."
fi

command -v nginx >/dev/null 2>&1 || die "Chưa có nginx. Chạy scripts/00_setup_vm.sh trước."

# --- 1. Vô hiệu hoá site mặc định ---------------------------------------
if [[ -e "${NGINX_DIR}/sites-enabled/default" ]]; then
  log "Vô hiệu hoá site mặc định (nhường port 80 cho vhost)."
  "${SUDO[@]}" rm -f "${NGINX_DIR}/sites-enabled/default"
fi

# --- 2. nginx.conf (sao lưu bản gốc lần đầu) ----------------------------
if [[ -f "${REPO_ROOT}/nginx/nginx.conf" ]]; then
  if [[ -f "${NGINX_DIR}/nginx.conf" && ! -f "${NGINX_DIR}/nginx.conf.orig" ]]; then
    log "Sao lưu nginx.conf gốc -> nginx.conf.orig"
    "${SUDO[@]}" cp -a "${NGINX_DIR}/nginx.conf" "${NGINX_DIR}/nginx.conf.orig"
  fi
  log "Cài nginx.conf..."
  "${SUDO[@]}" cp -f "${REPO_ROOT}/nginx/nginx.conf" "${NGINX_DIR}/nginx.conf"
else
  warn "Không tìm thấy nginx/nginx.conf, bỏ qua."
fi

# --- 3. conf.d/*.conf ----------------------------------------------------
log "Copy conf.d/*.conf vào ${CONF_DEST}..."
"${SUDO[@]}" mkdir -p "${CONF_DEST}"
if compgen -G "${REPO_ROOT}/nginx/conf.d/*.conf" >/dev/null; then
  "${SUDO[@]}" cp -f "${REPO_ROOT}"/nginx/conf.d/*.conf "${CONF_DEST}/"
else
  warn "Chưa có file nginx/conf.d/*.conf nào."
fi

# --- 4. Web content ------------------------------------------------------
log "Copy web tĩnh vào ${WEB_ROOT}..."
"${SUDO[@]}" mkdir -p "${WEB_ROOT}"
for site in site1 site2; do
  if [[ -d "${REPO_ROOT}/www/${site}" ]]; then
    "${SUDO[@]}" rm -rf "${WEB_ROOT:?}/${site}"
    "${SUDO[@]}" cp -a "${REPO_ROOT}/www/${site}" "${WEB_ROOT}/"
  fi
done

if [[ -d "${REPO_ROOT}/www/error_pages" ]]; then
  log "Copy trang lỗi vào ${ERR_ROOT}..."
  "${SUDO[@]}" rm -rf "${ERR_ROOT:?}"
  "${SUDO[@]}" mkdir -p "$(dirname "${ERR_ROOT}")"
  "${SUDO[@]}" cp -a "${REPO_ROOT}/www/error_pages" "${ERR_ROOT}"
fi

# --- 5. Cert TLS (nếu đã sinh) ------------------------------------------
if compgen -G "${REPO_ROOT}/ssl/*.crt" >/dev/null; then
  log "Copy cert/key vào ${SSL_DEST}..."
  "${SUDO[@]}" mkdir -p "${SSL_DEST}"
  "${SUDO[@]}" cp -f "${REPO_ROOT}"/ssl/*.crt "${SSL_DEST}/"
  if [[ -f "${REPO_ROOT}/ssl/server.key" ]]; then
    "${SUDO[@]}" cp -f "${REPO_ROOT}/ssl/server.key" "${SSL_DEST}/"
  fi
  "${SUDO[@]}" chmod 644 "${SSL_DEST}"/*.crt
  if [[ -f "${SSL_DEST}/server.key" ]]; then
    "${SUDO[@]}" chmod 600 "${SSL_DEST}/server.key"
  fi
else
  warn "Chưa có cert trong ssl/ (chạy scripts/01_generate_ssl.sh nếu cần HTTPS)."
fi

# --- 6. Kiểm tra & reload -----------------------------------------------
log "Kiểm tra cấu hình (nginx -t)..."
"${SUDO[@]}" nginx -t

log "Reload nginx..."
if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl reload nginx 2>/dev/null || "${SUDO[@]}" systemctl restart nginx
else
  "${SUDO[@]}" nginx -s reload 2>/dev/null || warn "Không reload được; chạy 'sudo nginx' thủ công."
fi

log "Deploy xong."
log "Kiểm tra nhanh: curl -H 'Host: site1.local' http://127.0.0.1/"
