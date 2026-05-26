#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
flutter="${repo_root}/tools/flutterw"
mode="checks"

usage() {
  cat <<'EOF'
Usage: tools/ci/run-local-mobile-checks.sh [--doctor]

Runs the Flutter mobile checks from front/.

Options:
  --doctor   Print local Flutter, Android, Xcode, and CocoaPods state only.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --doctor)
      mode="doctor"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

print_status() {
  local name="$1"
  local status="$2"
  local detail="$3"

  printf '%s: %s' "${name}" "${status}"
  if [[ -n "${detail}" ]]; then
    printf ' (%s)' "${detail}"
  fi
  printf '\n'
}

run_doctor() {
  local failed=0

  if "${flutter}" --version >/tmp/maumon_flutter_version.txt 2>&1; then
    local flutter_version
    flutter_version="$(head -n 1 /tmp/maumon_flutter_version.txt)"
    print_status "Flutter" "ok" "${flutter_version}"
    if ! grep -qi "stable" /tmp/maumon_flutter_version.txt; then
      print_status "Flutter channel" "warn" "CI uses the stable channel"
    fi
  else
    print_status "Flutter" "missing" "run tools/flutterw --version for setup guidance"
    failed=1
  fi

  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}" ]]; then
    print_status "Android SDK" "ok" "ANDROID_HOME=${ANDROID_HOME}"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}" ]]; then
    print_status "Android SDK" "ok" "ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}"
  else
    print_status "Android SDK" "missing" "set ANDROID_HOME or ANDROID_SDK_ROOT"
    failed=1
  fi

  if command -v xcodebuild >/dev/null 2>&1; then
    if xcodebuild -version >/tmp/maumon_xcode_version.txt 2>&1; then
      print_status "Xcode" "ok" "$(head -n 1 /tmp/maumon_xcode_version.txt)"
    else
      print_status "Xcode" "missing" "$(tr '\n' ' ' </tmp/maumon_xcode_version.txt)"
      failed=1
    fi
  else
    print_status "Xcode" "missing" "xcodebuild not found"
    failed=1
  fi

  if command -v pod >/dev/null 2>&1; then
    print_status "CocoaPods" "ok" "$(pod --version)"
  else
    print_status "CocoaPods" "missing" "pod --version failed"
    failed=1
  fi

  return "${failed}"
}

run_flutter() {
  local label="$1"
  shift

  echo "${label}"
  "${flutter}" "$@"
}

if [[ "${mode}" == "doctor" ]]; then
  run_doctor
  exit $?
fi

cd "${repo_root}/front"
run_flutter "flutter pub get" pub get --enforce-lockfile
run_flutter "flutter analyze" analyze
run_flutter "flutter test" test
