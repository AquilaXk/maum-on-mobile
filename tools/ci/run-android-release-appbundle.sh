#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
front_dir="${repo_root}/front"
required_env=(
  MAUMON_ANDROID_KEYSTORE_BASE64
  MAUMON_ANDROID_KEYSTORE_PASSWORD
  MAUMON_ANDROID_KEY_ALIAS
  MAUMON_ANDROID_KEY_PASSWORD
  MAUMON_FIREBASE_APP_ID
  MAUMON_FIREBASE_PROJECT_ID
  MAUMON_FIREBASE_API_KEY
  MAUMON_FIREBASE_SENDER_ID
)
missing_env=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      export MAUMON_ANDROID_RELEASE_DRY_RUN=true
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: tools/ci/run-android-release-appbundle.sh [--dry-run]

Builds the signed Android App Bundle, or validates inputs without building when --dry-run is set.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

for name in "${required_env[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing_env+=("${name}")
  fi
done

if (( ${#missing_env[@]} > 0 )); then
  echo "Android release appbundle requires the following environment variables:" >&2
  printf ' - %s\n' "${missing_env[@]}" >&2
  exit 1
fi

if [[ "${MAUMON_ANDROID_RELEASE_DRY_RUN:-false}" == "true" ]]; then
  echo "Android release appbundle dry run ok"
  echo "flutter build appbundle --release"
  exit 0
fi

tmp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
release_dir="$(mktemp -d "${tmp_parent%/}/maumon-android-release.XXXXXX")"
cleanup() {
  rm -rf "${release_dir}"
}
trap cleanup EXIT

decode_base64() {
  if base64 --decode </dev/null >/dev/null 2>&1; then
    base64 --decode
  else
    base64 -D
  fi
}

release_keystore="${release_dir}/maumon-release.keystore"
printf '%s' "${MAUMON_ANDROID_KEYSTORE_BASE64}" | decode_base64 > "${release_keystore}"
export MAUMON_ANDROID_KEYSTORE_PATH="${release_keystore}"

cd "${front_dir}"
"${repo_root}/tools/flutterw" pub get
"${repo_root}/tools/flutterw" build appbundle --release

bundle_path="${front_dir}/build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "${bundle_path}" ]]; then
  echo "Android release appbundle was not generated at ${bundle_path}." >&2
  exit 1
fi

echo "Android release appbundle generated: ${bundle_path}"
