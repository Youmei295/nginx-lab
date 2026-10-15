#!/usr/bin/env bash
#
# 03_run_benchmark.sh — Benchmark rate limit: 100 request đồng thời tới limit.local.
#
# Idempotent: chạy lại nhiều lần vẫn an toàn (nên cách nhau >= 3 giây).
# Đích: http://limit.local/ (HTTP, xem docs/interfaces.md mục 6-7).
#
# Cách dùng:
#   bash scripts/03_run_benchmark.sh
#
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://limit.local/}"
REQUESTS="${REQUESTS:-100}"
CONCURRENCY="${CONCURRENCY:-100}"
ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/access.log}"

log()  { printf '\033[1;34m[bench]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v ab >/dev/null 2>&1 || die "Chưa có ab. Chạy scripts/00_setup_vm.sh trước."
getent hosts limit.local >/dev/null 2>&1 || die "limit.local chưa resolve. Chạy scripts/00_setup_vm.sh trước."

OUT="$(mktemp)"
trap 'rm -f "${OUT}"' EXIT

log "Chờ 3 giây cho zone rate limit hồi phục..."
sleep 3

log "Chạy: ab -n ${REQUESTS} -c ${CONCURRENCY} ${TARGET_URL}"
if ! ab -n "${REQUESTS}" -c "${CONCURRENCY}" "${TARGET_URL}" >"${OUT}" 2>&1; then
  cat "${OUT}" >&2
  die "ab chạy thất bại. Nginx có đang chạy không? (systemctl status nginx)"
fi

cat "${OUT}"

COMPLETE="$(awk '/^Complete requests:/ {print $3}' "${OUT}")"
NON2XX="$(awk '/^Non-2xx responses:/ {print $3}' "${OUT}")"
RPS="$(awk '/^Requests per second:/ {print $4}' "${OUT}")"
COMPLETE="${COMPLETE:-0}"
NON2XX="${NON2XX:-0}"
RPS="${RPS:-n/a}"
SUCCESS=$((COMPLETE - NON2XX))

echo
echo "========== THỐNG KÊ RATE LIMIT =========="
printf 'Complete requests    : %s\n' "${COMPLETE}"
printf 'Thành công (2xx/200) : %s\n' "${SUCCESS}"
printf 'Bị chặn (non-2xx/503): %s\n' "${NON2XX}"
printf 'Requests per second  : %s\n' "${RPS}"
echo "=========================================="

if [[ -r "${ACCESS_LOG}" ]]; then
  echo
  log "Phân rã theo mã trạng thái (${REQUESTS} dòng ApacheBench gần nhất trong access.log):"
  grep 'ApacheBench' "${ACCESS_LOG}" | tail -n "${REQUESTS}" \
    | awk -F'"' '{split($3, a, " "); c[a[1]]++} END {for (k in c) printf "  HTTP %s : %d\n", k, c[k]}' \
    | sort
else
  warn "Không đọc được ${ACCESS_LOG} (cần sudo). Chạy 'sudo bash $0' để xem phân rã 200/503 từ log."
fi

if [[ "${NON2XX}" -gt 0 && "${SUCCESS}" -gt 0 ]]; then
  log "OK: có cả request thành công lẫn bị chặn (rate limit hoạt động)."
else
  warn "Chưa thấy cả 200 lẫn 503. Xem mục 'Lỗi thường gặp' trong tài liệu hướng dẫn."
fi
