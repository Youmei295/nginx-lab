#!/usr/bin/env bash
#
# 01_generate_ssl.sh — Sinh chứng chỉ SSL tự ký (self-signed) cho app.local
#
# Idempotent: nếu cert và key đã tồn tại và còn hạn, script sẽ bỏ qua (dùng cờ --force để ép tạo lại).
# Yêu cầu SAN theo docs/interfaces.md mục 5:
#   subjectAltName = DNS:app.local, DNS:localhost, IP:127.0.0.1
#
# Cách dùng:
#   bash scripts/01_generate_ssl.sh [--force]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSL_DIR="${REPO_ROOT}/ssl"

CRT_FILE="${SSL_DIR}/server.crt"
KEY_FILE="${SSL_DIR}/server.key"
DAYS_VALID=365
FORCE=0

if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE=1
fi

log()  { printf '\033[1;34m[ssl]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v openssl >/dev/null 2>&1 || die "openssl chưa được cài đặt. Chạy scripts/00_setup_vm.sh trước."

mkdir -p "${SSL_DIR}"

if [[ "${FORCE}" -eq 0 && -f "${CRT_FILE}" && -f "${KEY_FILE}" ]]; then
  # Kiểm tra tính hợp lệ và thời hạn chứng chỉ (còn ít nhất 1 ngày)
  if openssl x509 -checkend 86400 -noout -in "${CRT_FILE}" >/dev/null 2>&1; then
    log "Chứng chỉ SSL đã tồn tại tại ${CRT_FILE} và còn hạn sử dụng. Bỏ qua (dùng --force để tạo lại)."
    exit 0
  else
    warn "Chứng chỉ SSL đã hết hạn hoặc không hợp lệ. Đang tạo mới..."
  fi
fi

log "Đang sinh chứng chỉ SSL tự ký cho app.local..."
openssl req -x509 -nodes -days "${DAYS_VALID}" \
  -newkey rsa:2048 \
  -keyout "${KEY_FILE}" \
  -out "${CRT_FILE}" \
  -subj "/CN=app.local/O=Nginx Lab/C=VN" \
  -addext "subjectAltName = DNS:app.local, DNS:localhost, IP:127.0.0.1" >/dev/null 2>&1

chmod 600 "${KEY_FILE}"
chmod 644 "${CRT_FILE}"

log "Chứng chỉ SSL tự ký đã được tạo thành công:"
log "  - Key: ${KEY_FILE} (chmod 600)"
log "  - Cert: ${CRT_FILE} (chmod 644)"

# Kiểm tra xác nhận SAN
log "Xác nhận Subject Alternative Name (SAN):"
openssl x509 -in "${CRT_FILE}" -noout -text | grep -A 1 "Subject Alternative Name" || true
