#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
front_dir="${repo_root}/front"
dry_run="${MAUMON_IOS_RELEASE_DRY_RUN:-true}"
upload="${MAUMON_IOS_TESTFLIGHT_UPLOAD:-false}"
signing_env=(
  MAUMON_IOS_DEVELOPMENT_TEAM
  MAUMON_IOS_EXPORT_OPTIONS_PLIST_BASE64
  MAUMON_IOS_PROVISIONING_PROFILE_BASE64
  MAUMON_IOS_CERTIFICATE_P12_BASE64
  MAUMON_IOS_CERTIFICATE_PASSWORD
  MAUMON_IOS_KEYCHAIN_PASSWORD
)
upload_env=(
  MAUMON_APP_STORE_CONNECT_API_KEY_ID
  MAUMON_APP_STORE_CONNECT_API_ISSUER_ID
  MAUMON_APP_STORE_CONNECT_API_KEY_P8_BASE64
)
release_manifest_path="${MAUMON_RELEASE_MANIFEST_PATH:-}"
release_manifest_abs=""
release_notes="${MAUMON_IOS_RELEASE_NOTES:-}"
tester_notes="${MAUMON_IOS_TESTER_NOTES:-}"
missing_env=()
temp_dir=""
keychain_path=""

cleanup() {
  if [[ -n "${keychain_path}" && -f "${keychain_path}" ]]; then
    security delete-keychain "${keychain_path}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${temp_dir}" && -d "${temp_dir}" ]]; then
    rm -rf "${temp_dir}"
  fi
}

trap cleanup EXIT

decode_base64() {
  if base64 --decode </dev/null >/dev/null 2>&1; then
    base64 --decode
  else
    base64 -D
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    missing_env+=("${name}")
  fi
}

pubspec_version() {
  awk '/^version:/ { print $2; exit }' "${front_dir}/pubspec.yaml"
}

resolve_release_manifest_path() {
  if [[ -z "${release_manifest_path}" ]]; then
    release_manifest_abs=""
  elif [[ "${release_manifest_path}" = /* ]]; then
    release_manifest_abs="${release_manifest_path}"
  else
    release_manifest_abs="${repo_root}/${release_manifest_path}"
  fi
}

release_manifest_field() {
  local field_path="$1"
  node -e '
const fs = require("fs");
const manifestPath = process.argv[1];
const fieldPath = process.argv[2];
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
let value = manifest;
for (const key of fieldPath.split(".")) {
  value = value == null ? undefined : value[key];
}
if (value !== undefined && value !== null) {
  process.stdout.write(String(value).trim());
}
' "${release_manifest_abs}" "${field_path}"
}

load_release_manifest_notes() {
  resolve_release_manifest_path
  if [[ -z "${release_manifest_abs}" || ! -f "${release_manifest_abs}" ]]; then
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    echo "node is unavailable; release manifest notes were not loaded."
    return 0
  fi

  if [[ -z "${release_notes}" ]]; then
    release_notes="$(release_manifest_field "storeReleaseNotes.appStore")"
  fi
  if [[ -z "${tester_notes}" ]]; then
    tester_notes="$(release_manifest_field "testerNotes")"
  fi
}

load_release_manifest_notes

if [[ "${dry_run}" == "true" ]]; then
  echo "iOS TestFlight archive dry run ok"
  if command -v xcodebuild >/dev/null 2>&1; then
    xcodebuild -version
  else
    echo "xcodebuild unavailable in dry run"
  fi
  echo "version: $(pubspec_version)"
  echo "release manifest: ${release_manifest_abs:-none}"
  echo "release notes length: ${#release_notes}"
  echo "tester notes length: ${#tester_notes}"
  echo "flutter build ipa --release --export-options-plist <decoded export options>"
  if [[ "${upload}" == "true" ]]; then
    echo "TestFlight upload dry run: xcrun altool --upload-app --type ios --file <ipa>"
  else
    echo "TestFlight upload skipped in dry run"
  fi
  exit 0
fi

for name in "${signing_env[@]}"; do
  require_env "${name}"
done

if [[ "${upload}" == "true" ]]; then
  for name in "${upload_env[@]}"; do
    require_env "${name}"
  done
fi

if (( ${#missing_env[@]} > 0 )); then
  echo "iOS TestFlight archive requires the following environment variables:" >&2
  printf ' - %s\n' "${missing_env[@]}" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required for iOS archive/export." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required for iOS archive/export." >&2
  exit 1
fi

xcode_output="$(xcodebuild -version)"
xcode_version="$(printf '%s\n' "${xcode_output}" | head -n 1)"
printf '%s\n' "${xcode_output}"
if [[ "${xcode_version}" != Xcode\ 26* ]]; then
  echo "Xcode 26 is required for iOS archive/export; selected ${xcode_version}." >&2
  exit 1
fi
xcrun --sdk iphoneos --show-sdk-version

temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
temp_dir="$(mktemp -d "${temp_parent%/}/maumon-ios-release.XXXXXX")"
keychain_path="${temp_dir}/maumon-ios-release.keychain-db"
certificate_path="${temp_dir}/certificate.p12"
profile_path="${temp_dir}/profile.mobileprovision"
export_options_path="${temp_dir}/ExportOptions.plist"

printf '%s' "${MAUMON_IOS_CERTIFICATE_P12_BASE64}" | decode_base64 > "${certificate_path}"
printf '%s' "${MAUMON_IOS_PROVISIONING_PROFILE_BASE64}" | decode_base64 > "${profile_path}"
printf '%s' "${MAUMON_IOS_EXPORT_OPTIONS_PLIST_BASE64}" | decode_base64 > "${export_options_path}"

security create-keychain -p "${MAUMON_IOS_KEYCHAIN_PASSWORD}" "${keychain_path}"
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${MAUMON_IOS_KEYCHAIN_PASSWORD}" "${keychain_path}"
security import "${certificate_path}" \
  -P "${MAUMON_IOS_CERTIFICATE_PASSWORD}" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "${keychain_path}"
security list-keychains -d user -s "${keychain_path}" $(security list-keychains -d user | tr -d '"')
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${MAUMON_IOS_KEYCHAIN_PASSWORD}" "${keychain_path}"

mkdir -p "${HOME}/Library/MobileDevice/Provisioning Profiles"
cp "${profile_path}" "${HOME}/Library/MobileDevice/Provisioning Profiles/maumon.mobileprovision"

cd "${front_dir}"
"${repo_root}/tools/flutterw" pub get
"${repo_root}/tools/flutterw" build ipa --release --export-options-plist "${export_options_path}"

ipa_path="$(find "${front_dir}/build/ios/ipa" -name '*.ipa' -print -quit)"
if [[ -z "${ipa_path}" || ! -f "${ipa_path}" ]]; then
  echo "iOS IPA was not generated under ${front_dir}/build/ios/ipa." >&2
  exit 1
fi

echo "iOS IPA generated: ${ipa_path}"
echo "version: $(pubspec_version)"
echo "release manifest: ${release_manifest_abs:-none}"
echo "release notes length: ${#release_notes}"
echo "tester notes length: ${#tester_notes}"

if [[ "${upload}" != "true" ]]; then
  echo "TestFlight upload skipped. Set MAUMON_IOS_TESTFLIGHT_UPLOAD=true to upload."
  exit 0
fi

api_key_dir="${HOME}/.appstoreconnect/private_keys"
api_key_path="${api_key_dir}/AuthKey_${MAUMON_APP_STORE_CONNECT_API_KEY_ID}.p8"
mkdir -p "${api_key_dir}"
printf '%s' "${MAUMON_APP_STORE_CONNECT_API_KEY_P8_BASE64}" | decode_base64 > "${api_key_path}"
chmod 600 "${api_key_path}"

xcrun altool --upload-app \
  --type ios \
  --file "${ipa_path}" \
  --apiKey "${MAUMON_APP_STORE_CONNECT_API_KEY_ID}" \
  --apiIssuer "${MAUMON_APP_STORE_CONNECT_API_ISSUER_ID}"

echo "TestFlight upload requested: ${ipa_path}"
