#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export MOBILE_PERFORMANCE_PROFILE="${MOBILE_PERFORMANCE_PROFILE:-performance}"
export MOBILE_PERFORMANCE_SAMPLES="${MOBILE_PERFORMANCE_SAMPLES:-3}"
export MOBILE_PERFORMANCE_REPORT_DIR="${MOBILE_PERFORMANCE_REPORT_DIR:-build/reports/mobile-performance}"
export MOBILE_PERFORMANCE_P95_BUDGET_MS="${MOBILE_PERFORMANCE_P95_BUDGET_MS:-2500}"
export MOBILE_PERFORMANCE_ERROR_RATE_BUDGET="${MOBILE_PERFORMANCE_ERROR_RATE_BUDGET:-0.01}"
export MOBILE_PERFORMANCE_MIN_SUCCESS_RATE="${MOBILE_PERFORMANCE_MIN_SUCCESS_RATE:-0.99}"

case "${MOBILE_PERFORMANCE_REPORT_DIR}" in
  /*) ;;
  *) export MOBILE_PERFORMANCE_REPORT_DIR="${repo_root}/${MOBILE_PERFORMANCE_REPORT_DIR}" ;;
esac

cd "${repo_root}/back"
./gradlew test \
  --tests com.maumonmobile.performance.MobileApiPerformanceSmokeTest \
  --no-daemon

report_path="${MOBILE_PERFORMANCE_REPORT_DIR}/mobile-performance-smoke.json"
if [[ ! -f "${report_path}" ]]; then
  echo "Expected mobile performance report not found: ${report_path}" >&2
  exit 1
fi

echo "Mobile performance smoke report: ${report_path}"
