#!/usr/bin/env bash
# Trich log Nginx that cho Demo 4 (mac dinh), Demo 3, hoac ca hai.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/04_collect_logs.sh [--demo 4|3|all] [--lines N] [--help]

  --demo 4|3|all  Demo can thu thap (mac dinh: 4).
  --lines N      So dong khop gan nhat cho moi nguon (mac dinh: 20).

Environment:
  ACCESS_LOG     Mac dinh: /var/log/nginx/access.log
  ERROR_LOG      Mac dinh: /var/log/nginx/error.log
  OUTPUT_DIR     Mac dinh: <repo>/docs/logs

Demo 4 can request dung User-Agent nginx-lab-demo4, vi main_ext khong ghi Host:
  curl -k --user-agent nginx-lab-demo4 https://app.local/
Error Demo 4: connect() failed (111: ...) cua app.local -> 127.0.0.1:3000.
Loc theo errno Linux 111, khong phu thuoc chuoi mo ta loi.

Chi ghi file khi ca access.log va error.log co dong phu hop.
EOF
}

die() { printf '[error] %s\n' "$*" >&2; exit 1; }

DEMO=4
LINES=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --demo)
      [[ $# -ge 2 ]] || die '--demo can gia tri 4, 3 hoac all.'
      DEMO="$2"
      shift 2
      ;;
    --lines)
      [[ $# -ge 2 ]] || die '--lines can so nguyen duong.'
      LINES="$2"
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) die "Tham so khong hop le: $1 (xem --help)." ;;
  esac
done

case "${DEMO}" in 4|3|all) ;; *) die '--demo chi nhan 4, 3 hoac all.' ;; esac
[[ "${LINES}" =~ ^[1-9][0-9]*$ ]] || die '--lines phai la so nguyen duong.'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/access.log}"
ERROR_LOG="${ERROR_LOG:-/var/log/nginx/error.log}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/docs/logs}"

[[ -f "${ACCESS_LOG}" && -r "${ACCESS_LOG}" ]] || die "Khong doc duoc access log: ${ACCESS_LOG}"
[[ -f "${ERROR_LOG}" && -r "${ERROR_LOG}" ]] || die "Khong doc duoc error log: ${ERROR_LOG}"

# Vong dem giu toi da N dong khop, khong cat pipeline gay SIGPIPE/pipefail.
select_access() {
  awk -F '"' -v status="$1" -v demo="$2" -v keep="${LINES}" '
    $3 ~ "^[[:space:]]*" status "[[:space:]]" &&
      ((demo == "4" && $6 == "nginx-lab-demo4") ||
       (demo == "3" && $6 ~ /^ApacheBench\//)) {
      rows[count % keep] = $0
      count++
    }
    END {
      start = count > keep ? count - keep : 0
      for (i = start; i < count; i++) print rows[i % keep]
    }
  ' "${ACCESS_LOG}"
}

select_error() {
  awk -v demo="$1" -v keep="${LINES}" '
    (demo == "4" && /(^|[[:space:]])connect\(\) failed \(111: [^)]*\)/ &&
      /server: app[.]local,/ && /upstream: "http:\/\/127[.]0[.]0[.]1:3000[\/" ]/) ||
    (demo == "3" && /limiting requests/ && /by zone "perip"/ && /server: limit[.]local,/) {
      rows[count % keep] = $0
      count++
    }
    END {
      start = count > keep ? count - keep : 0
      for (i = start; i < count; i++) print rows[i % keep]
    }
  ' "${ERROR_LOG}"
}

ACCESS_502=''
ERROR_502=''
ACCESS_503=''
ERROR_503=''
if [[ "${DEMO}" == 4 || "${DEMO}" == all ]]; then
  ACCESS_502="$(select_access 502 4)" || die "Loi khi doc ${ACCESS_LOG}"
  ERROR_502="$(select_error 4)" || die "Loi khi doc ${ERROR_LOG}"
  [[ -n "${ACCESS_502}" ]] || die 'Chua co access HTTP 502 voi User-Agent nginx-lab-demo4; chua ghi file.'
  [[ -n "${ERROR_502}" ]] || die 'Chua co connect() failed (111: ...) cua app.local -> 127.0.0.1:3000; chua ghi file.'
fi
if [[ "${DEMO}" == 3 || "${DEMO}" == all ]]; then
  ACCESS_503="$(select_access 503 3)" || die "Loi khi doc ${ACCESS_LOG}"
  ERROR_503="$(select_error 3)" || die "Loi khi doc ${ERROR_LOG}"
  [[ -n "${ACCESS_503}" ]] || die 'Chua co access HTTP 503 voi User-Agent ApacheBench/; chua ghi file.'
  [[ -n "${ERROR_503}" ]] || die 'Chua co limiting requests cua limit.local, zone perip; chua ghi file.'
fi

# Tat ca nguon can thiet da duoc kiem tra truoc khi tao/ghi file dau ra.
COLLECTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
mkdir -p -- "${OUTPUT_DIR}"
TEMP_FILES=()
cleanup() {
  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    rm -f -- "${TEMP_FILES[@]}"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

write_evidence() {
  local target="$1" access_lines="$2" error_lines="$3" access_filter="$4"
  local temporary
  temporary="$(mktemp "${OUTPUT_DIR}/.${target}.XXXXXX")" || die "Khong tao duoc file tam trong ${OUTPUT_DIR}"
  TEMP_FILES+=("${temporary}")
  {
    printf '# Thu thap UTC: %s\n' "${COLLECTED_AT}"
    printf '# Nguon: %s\n# Nguon: %s\n' "${ACCESS_LOG}" "${ERROR_LOG}"
    printf '# Toi da %s dong khop gan nhat cho moi nguon.\n' "${LINES}"
    printf '# main_ext khong ghi Host. Loc access: %s\n' "${access_filter}"
    printf '\n# access.log\n%s\n\n# error.log\n%s\n' "${access_lines}" "${error_lines}"
  } >"${temporary}"
  chmod 644 -- "${temporary}"
  mv -f -- "${temporary}" "${OUTPUT_DIR}/${target}"
  printf '[collect] Da ghi %s\n' "${OUTPUT_DIR}/${target}"
}

if [[ "${DEMO}" == 4 || "${DEMO}" == all ]]; then
  write_evidence backend_down_502.log "${ACCESS_502}" "${ERROR_502}" 'HTTP 502, User-Agent nginx-lab-demo4'
fi
if [[ "${DEMO}" == 3 || "${DEMO}" == all ]]; then
  write_evidence rate_limit_503.log "${ACCESS_503}" "${ERROR_503}" 'HTTP 503, User-Agent ApacheBench/; khong xac dinh duoc Host tu access.log'
fi
