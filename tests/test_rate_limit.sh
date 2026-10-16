#!/usr/bin/env bash
#
# test_rate_limit.sh — Kiểm thử Demo 3: tải thấp -> 200, tải vượt ngưỡng -> có 503.
#
# Exit 0 khi PASS, exit 1 khi FAIL.
#
# Cách dùng:
#   bash tests/test_rate_limit.sh
#
set -euo pipefail

URL="${URL:-http://limit.local/}"
BURST_REQUESTS="${BURST_REQUESTS:-60}"

pass() { printf '\033[1;32m[PASS]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; FAILED=1; }

FAILED=0

command -v curl >/dev/null 2>&1 || { echo "Thiếu curl."; exit 1; }
getent hosts limit.local >/dev/null 2>&1 || { echo "limit.local chưa resolve (chạy 00_setup_vm.sh)."; exit 1; }

echo "== Test 1: tải thấp (1 request) phải trả 200 =="
sleep 3
code="$(curl -s -o /dev/null -w '%{http_code}' "${URL}")"
if [[ "${code}" == "200" ]]; then
  pass "Tải thấp trả ${code}"
else
  fail "Tải thấp trả ${code} (mong đợi 200)"
fi

echo "== Test 2: ${BURST_REQUESTS} request liên tiếp phải có 503 =="
sleep 3
ok=0
blocked=0
for _ in $(seq 1 "${BURST_REQUESTS}"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${URL}")"
  case "${code}" in
    200) ok=$((ok + 1)) ;;
    503) blocked=$((blocked + 1)) ;;
  esac
done
echo "   200: ${ok}   503: ${blocked}"
if [[ "${blocked}" -gt 0 ]]; then
  pass "Có ${blocked} request bị chặn 503"
else
  fail "Không có 503 nào (rate limit chưa hoạt động?)"
fi
if [[ "${ok}" -gt 0 ]]; then
  pass "Có ${ok} request thành công (burst cho phép)"
else
  fail "Không có 200 nào"
fi

exit "${FAILED}"
