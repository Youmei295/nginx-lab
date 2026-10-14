#!/usr/bin/env bash
#
# test_https_proxy.sh — Kiểm thử tự động Reverse Proxy & HTTPS cho app.local
#
# Kiểm tra:
#   1. HTTP:80 chuyển hướng 301 sang HTTPS
#   2. Header Location trỏ đúng URL HTTPS
#   3. HTTPS:443 phản hồi HTTP 200
#   4. Backend nhận đúng các proxy header (Host, X-Forwarded-For, X-Real-IP)
#
# Cách dùng:
#   bash tests/test_https_proxy.sh
#
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32m[PASS]\033[0m %s\n' "$*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Tùy chọn cờ resolve giúp script chạy tin cậy ngay cả khi /etc/hosts chưa được cập nhật
CURL_RESOLVE_80=(--resolve "app.local:80:127.0.0.1")
CURL_RESOLVE_443=(--resolve "app.local:443:127.0.0.1")

info "Bắt đầu kiểm thử Demo 2: Reverse Proxy & HTTPS (app.local)..."

# --- Test 1: HTTP Redirect 301 -----------------------------------------------
info "Test 1: Kiểm tra HTTP (port 80) chuyển hướng 301..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${CURL_RESOLVE_80[@]}" "http://app.local/" || echo "000")
if [[ "${HTTP_CODE}" == "301" ]]; then
  pass "HTTP port 80 trả về status code 301 Moved Permanently."
else
  fail "HTTP port 80 trả về ${HTTP_CODE} (kỳ vọng: 301)."
fi

# --- Test 2: Header Location trong Redirect ----------------------------------
info "Test 2: Kiểm tra header Location trong phản hồi HTTP 301..."
LOCATION_HEADER=$(curl -s -I "${CURL_RESOLVE_80[@]}" "http://app.local/test-path?param=1" | grep -i "^location:" | tr -d '\r\n' || true)
if echo "${LOCATION_HEADER}" | grep -q "https://app.local/test-path?param=1"; then
  pass "Header Location chuyển hướng chính xác: ${LOCATION_HEADER}"
else
  fail "Header Location không đúng: '${LOCATION_HEADER}' (kỳ vọng trỏ tới https://app.local/...)"
fi

# --- Test 3: HTTPS Status 200 ------------------------------------------------
info "Test 3: Kiểm tra HTTPS (port 443) phản hồi 200 qua Reverse Proxy..."
RESP_BODY_FILE=$(mktemp)
trap 'rm -f "${RESP_BODY_FILE}"' EXIT

HTTPS_CODE=$(curl -k -s -w "%{http_code}" -o "${RESP_BODY_FILE}" "${CURL_RESOLVE_443[@]}" "https://app.local/" || echo "000")
if [[ "${HTTPS_CODE}" == "200" ]]; then
  pass "HTTPS port 443 trả về status code 200 OK."
else
  fail "HTTPS port 443 trả về ${HTTPS_CODE} (kỳ vọng: 200). Đảm bảo backend đã khởi động và Nginx đã deploy."
fi

# --- Test 4: Xác nhận nội dung backend phản hồi ------------------------------
info "Test 4: Kiểm tra nội dung phản hồi từ backend mock..."
if grep -q "Hello from backend (Python)" "${RESP_BODY_FILE}"; then
  pass "Nhận đúng chuỗi nhận diện từ Python backend."
else
  fail "Nội dung phản hồi không khớp backend mock."
fi

# --- Test 5: Xác nhận các Proxy Headers được truyền tới backend --------------
info "Test 5: Kiểm tra các header X-Forwarded-For, Host, X-Real-IP..."
HEADERS_OK=1

if grep -q "Host: app.local" "${RESP_BODY_FILE}"; then
  pass "Backend nhận đúng header: Host: app.local"
else
  fail "Thiếu hoặc sai header Host."
  HEADERS_OK=0
fi

if grep -q "X-Forwarded-For:" "${RESP_BODY_FILE}"; then
  pass "Backend nhận đúng header: X-Forwarded-For"
else
  fail "Thiếu header X-Forwarded-For."
  HEADERS_OK=0
fi

if grep -q "X-Real-IP:" "${RESP_BODY_FILE}"; then
  pass "Backend nhận đúng header: X-Real-IP"
else
  fail "Thiếu header X-Real-IP."
  HEADERS_OK=0
fi

echo "------------------------------------------------------------"
echo "Kết quả kiểm thử: ${PASS_COUNT} PASS, ${FAIL_COUNT} FAIL"
echo "------------------------------------------------------------"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0
