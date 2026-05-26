#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
pod="${repo_root}/tools/pod"
platform="all"
failed=0
temp_files=()

if [[ "$(uname -s)" == "Darwin" && -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  selected_developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "${selected_developer_dir}" == "/Library/Developer/CommandLineTools" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

cleanup() {
  if [[ "${#temp_files[@]}" -gt 0 ]]; then
    rm -f "${temp_files[@]}"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: tools/ci/run-mobile-release-preflight.sh --platform <android|ios|all>

Checks the release toolchain that must exist before Android or iOS builds.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Missing value for --platform." >&2
        usage >&2
        exit 2
      fi
      platform="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${platform}" in
  android|ios|all)
    ;;
  *)
    echo "Expected --platform to be android, ios, or all." >&2
    usage >&2
    exit 2
    ;;
esac

record() {
  local name="$1"
  local status="$2"
  local detail="${3:-}"

  printf '%s: %s' "${name}" "${status}"
  if [[ -n "${detail}" ]]; then
    printf ' (%s)' "${detail}"
  fi
  printf '\n'

  if [[ "${status}" != "ok" && "${status}" != "warn" ]]; then
    failed=1
  fi
}

require_file() {
  local relative_path="$1"
  local name="$2"

  if [[ -f "${repo_root}/${relative_path}" ]]; then
    record "${name}" "ok" "${relative_path}"
  else
    record "${name}" "missing" "${relative_path}"
  fi
}

new_temp_file() {
  local file

  file="$(mktemp "${TMPDIR:-/tmp}/maumon-release-preflight.XXXXXX")"
  temp_files+=("${file}")
  printf '%s' "${file}"
}

flutter_config_android_sdk() {
  local config_output
  local sdk_path

  if ! config_output="$("${repo_root}/tools/flutterw" config --list 2>/dev/null)"; then
    return 1
  fi

  sdk_path="$(printf '%s\n' "${config_output}" | awk -F': ' '/^[[:space:]]*android-sdk:/ { print $2; exit }')"
  if [[ -n "${sdk_path}" && "${sdk_path}" != "(Not set)" && -d "${sdk_path}" ]]; then
    printf '%s' "${sdk_path}"
    return 0
  fi

  return 1
}

check_flutter() {
  local doctor_output
  local output

  require_file "front/pubspec.yaml" "Flutter scaffold"
  if output="$("${repo_root}/tools/flutterw" --version 2>&1)"; then
    record "Flutter" "ok" "$(printf '%s\n' "${output}" | head -n 1)"
  else
    record "Flutter" "missing" "${output//$'\n'/ }"
    return
  fi

  doctor_output="$(new_temp_file)"
  if "${repo_root}/tools/flutterw" doctor -v >"${doctor_output}" 2>&1; then
    record "flutter doctor -v" "ok"
  else
    record "flutter doctor -v" "warn" "diagnostics include missing optional or platform-specific tooling"
  fi
}

check_android() {
  local java_output
  local sdk_path=""

  echo "== Android release preflight =="
  check_flutter

  if java_output="$(java -version 2>&1)"; then
    record "Java" "ok" "$(printf '%s\n' "${java_output}" | head -n 1)"
  else
    record "Java" "missing" "java -version failed"
  fi

  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}" ]]; then
    sdk_path="${ANDROID_HOME}"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}" ]]; then
    sdk_path="${ANDROID_SDK_ROOT}"
  else
    sdk_path="$(flutter_config_android_sdk || true)"
  fi

  if [[ -n "${sdk_path}" ]]; then
    record "Android SDK" "ok" "${sdk_path}"
  else
    record "Android SDK" "missing" "set ANDROID_HOME or ANDROID_SDK_ROOT"
  fi
}

check_ios() {
  local pod_detail
  local pod_output
  local xcode_output

  echo "== iOS release preflight =="
  check_flutter

  if xcode_output="$(xcodebuild -version 2>&1)"; then
    record "Xcode" "ok" "$(printf '%s\n' "${xcode_output}" | head -n 1)"
  else
    record "Xcode" "missing" "${xcode_output//$'\n'/ }"
  fi

  if pod_output="$("${pod}" --version 2>&1)"; then
    record "CocoaPods" "ok" "$(printf '%s\n' "${pod_output}" | tail -n 1)"
  else
    pod_detail="$(printf '%s\n' "${pod_output}" | head -n 1)"
    record "CocoaPods" "missing" "${pod_detail:-pod --version failed}"
  fi
}

if [[ "${platform}" == "android" || "${platform}" == "all" ]]; then
  check_android
fi

if [[ "${platform}" == "ios" || "${platform}" == "all" ]]; then
  check_ios
fi

exit "${failed}"
