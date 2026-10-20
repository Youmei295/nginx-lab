#!/usr/bin/env bash
# Demo 4: backend hoạt động -> dừng backend -> trang lỗi 502 -> phục hồi.
set -euo pipefail

usage() {
  cat <<'EOF'
Cách dùng: bash tests/test_troubleshooting.sh [--pause]

  --pause  Giữ backend ở trạng thái dừng để chụp ảnh và thu log; Enter để tiếp tục.
  --help   Hiển thị hướng dẫn.

Chạy trong Ubuntu sau khi deploy Nginx/HTTPS. Cổng 127.0.0.1:3000 phải trống.
Script chỉ quản lý backend do chính nó khởi động; khi thoát sẽ dọn backend đó.
EOF
}

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

PAUSE=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --pause) PAUSE=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die "Tham số không hợp lệ: $1" ;;
  esac
  shift
done

if [[ "${PAUSE}" -eq 1 && ! -t 0 ]]; then
  die "--pause cần terminal tương tác. Bỏ --pause khi chạy tự động."
fi

for command in python3 curl mktemp grep sleep; do
  command -v "${command}" >/dev/null 2>&1 || die "Thiếu lệnh ${command}. Chạy scripts/00_setup_vm.sh trước."
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
[[ -f "${REPO_ROOT}/backend/app.py" ]] || die "Không tìm thấy backend/app.py."

if ! python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        probe.bind(("127.0.0.1", 3000))
    except OSError:
        raise SystemExit(1)
PY
then
  die "Cổng 127.0.0.1:3000 đang được dùng hoặc không thể bind. Dừng backend đang chạy bằng Ctrl+C rồi thử lại; script không dừng tiến trình có sẵn."
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nginx-lab-demo4.XXXXXX")"
BODY_FILE="${WORK_DIR}/response.html"
BACKEND_PID=""
HTTP_CODE=""
CURL_OPTIONS=(--silent --show-error --noproxy '*' --connect-timeout 2 --max-time 10)
HTTPS_OPTIONS=(-k --resolve 'app.local:443:127.0.0.1' --user-agent nginx-lab-demo4)

stop_backend() {
  [[ -n "${BACKEND_PID}" ]] || return 0
  if kill -0 "${BACKEND_PID}" 2>/dev/null; then
    kill "${BACKEND_PID}" 2>/dev/null || true
    for ((attempt = 0; attempt < 50; attempt++)); do
      kill -0 "${BACKEND_PID}" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "${BACKEND_PID}" 2>/dev/null; then
      kill -KILL "${BACKEND_PID}" 2>/dev/null || true
    fi
  fi
  wait "${BACKEND_PID}" 2>/dev/null || true
  BACKEND_PID=""
}

cleanup() {
  local status=$?
  trap - EXIT
  stop_backend
  rm -f -- "${BODY_FILE}" "${WORK_DIR}/backend.log" "${WORK_DIR}/curl.err"
  rmdir -- "${WORK_DIR}"
  exit "${status}"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

start_backend() {
  python3 "${REPO_ROOT}/backend/app.py" >"${WORK_DIR}/backend.log" 2>&1 &
  BACKEND_PID=$!
  local deadline=$((SECONDS + 10))
  while ((SECONDS < deadline)); do
    if ! kill -0 "${BACKEND_PID}" 2>/dev/null; then
      cat "${WORK_DIR}/backend.log" >&2
      die "Backend do script khởi động đã thoát."
    fi
    if HTTP_CODE=$(curl "${CURL_OPTIONS[@]}" --max-time 2 \
      -o "${BODY_FILE}" -w '%{http_code}' http://127.0.0.1:3000/ 2>"${WORK_DIR}/curl.err") \
      && [[ "${HTTP_CODE}" == 200 ]] \
      && grep -Fq 'Hello from backend (Python)' "${BODY_FILE}"; then
      return 0
    fi
    sleep 0.1
  done
  cat "${WORK_DIR}/backend.log" >&2
  die "Backend chưa sẵn sàng tại 127.0.0.1:3000 sau 10 giây."
}

request_https() {
  if ! HTTP_CODE=$(curl "${CURL_OPTIONS[@]}" "${HTTPS_OPTIONS[@]}" \
    -o "${BODY_FILE}" -w '%{http_code}' "$1"); then
    die "Không gọi được $1. Kiểm tra Nginx, chứng chỉ và bước deploy."
  fi
}

check_healthy_proxy() {
  request_https https://app.local/
  [[ "${HTTP_CODE}" == 200 ]] || die "HTTPS trả ${HTTP_CODE}; cần 200 khi backend hoạt động."
  grep -Fq 'Hello from backend (Python)' "${BODY_FILE}" || die "HTTPS không trả nội dung Python backend."
  grep -Fq 'Host: app.local' "${BODY_FILE}" || die "Backend không nhận đúng Host: app.local."
}

info "Khởi động backend riêng để kiểm tra trạng thái bình thường."
start_backend
check_healthy_proxy
pass "HTTPS trả 200 và đúng nội dung backend."

request_https https://app.local/50x.html
[[ "${HTTP_CODE}" == 404 ]] || die "/50x.html trả ${HTTP_CODE}; cần 404 vì location có internal."
pass "Không thể truy cập trực tiếp /50x.html (404)."

info "Dừng backend do script khởi động để gây lỗi upstream."
stop_backend
request_https https://app.local/
[[ "${HTTP_CODE}" == 502 ]] || die "Backend đã dừng nhưng HTTPS trả ${HTTP_CODE}; cần 502."
grep -Fq 'id="nginx-lab-error-page"' "${BODY_FILE}" || die "502 chưa hiển thị trang lỗi tùy chỉnh. Kiểm tra file HTML đã deploy."
pass "Backend dừng: HTTPS trả 502 và đúng trang lỗi tùy chỉnh."

if [[ "${PAUSE}" -eq 1 ]]; then
  printf '\nBackend đang dừng. Trong terminal khác trên cùng VM:\n'
  printf '  1. Mở https://app.local/ trên trình duyệt, chấp nhận cert tự ký và chụp ảnh.\n'
  printf '     Lưu ảnh: docs/screenshots/demo4_error_page.png\n'
  printf '  2. Thu log: sudo bash scripts/04_collect_logs.sh --demo 4\n'
  printf '\nNhấn Enter để khởi động lại backend và kiểm tra phục hồi.\n'
  read -r _ || die "Không đọc được Enter; kết thúc và dọn backend của script."
fi

info "Khởi động lại backend để kiểm tra phục hồi."
start_backend
check_healthy_proxy
pass "Sau phục hồi, HTTPS trả lại 200 và đúng nội dung backend."
stop_backend
pass "Hoàn tất kiểm thử Demo 4; backend của script đã dừng, cổng 3000 được trả về trạng thái ban đầu."
