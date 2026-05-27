#!/usr/bin/env bash
set -euo pipefail

changed_files_path="${1:?changed files path is required}"

android=false
backend=false
frontend=false
ios=false
javascript=false
repository=false
docs_only=true
ci=false
saw_file=false

is_docs_file() {
  case "$1" in
    README.md|LICENSE|LICENSE.*|*.md|docs/**)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue
  saw_file=true

  if ! is_docs_file "${file}"; then
    docs_only=false
  fi

  case "${file}" in
    .github/workflows/ci.yml|tools/ci/**)
      ci=true
      repository=true
      ;;
    contracts/mobile-api/**)
      backend=true
      frontend=true
      repository=true
      ;;
    contracts/accessibility/**)
      android=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/store-privacy/**)
      frontend=true
      repository=true
      ;;
    contracts/store-content/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/store-review/review-seed.json)
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/store-review/**)
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/store-listing/**)
      android=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/release-candidate/**)
      android=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/performance/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/security-release/**)
      android=true
      backend=true
      frontend=true
      ios=true
      javascript=true
      repository=true
      ;;
    contracts/privacy/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/ops/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/support/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/release-manifest/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    contracts/infra/**)
      android=true
      backend=true
      frontend=true
      ios=true
      repository=true
      ;;
    .github/pull_request_template.md)
      ;;
    .github/**|.gitignore|.coderabbit.yaml)
      repository=true
      ;;
  esac

  case "${file}" in
    back/**)
      backend=true
      ;;
  esac

  case "${file}" in
    front/**)
      frontend=true
      ;;
  esac

  case "${file}" in
    front/android/**)
      android=true
      ;;
    android/**|gradle/**|build.gradle|build.gradle.kts|settings.gradle|settings.gradle.kts|gradle.properties|gradlew|gradlew.bat)
      android=true
      ;;
  esac

  case "${file}" in
    front/ios/**)
      ios=true
      ;;
    ios/**|Podfile|Podfile.lock|Package.swift|*.xcodeproj/**|*.xcworkspace/**)
      ios=true
      ;;
  esac

  case "${file}" in
    package.json|package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lockb|src/**|app/**|components/**|lib/**|mobile/**)
      javascript=true
      ;;
  esac
done < "${changed_files_path}"

if [[ "${saw_file}" == "false" ]]; then
  android=true
  backend=true
  frontend=true
  ios=true
  javascript=true
  repository=true
  docs_only=false
fi

if [[ "${ci}" == "true" ]]; then
  android=true
  backend=true
  frontend=true
  ios=true
  javascript=true
  repository=true
  docs_only=false
fi

outputs_payload() {
  cat <<EOF
android=${android}
backend=${backend}
frontend=${frontend}
ios=${ios}
javascript=${javascript}
repository=${repository}
docs_only=${docs_only}
ci=${ci}
EOF
}

write_outputs() {
  {
    outputs_payload
  } >> "${GITHUB_OUTPUT}"
}

write_summary() {
  {
    echo "### Changed files"
    sed 's/^/- `/' "${changed_files_path}" | sed 's/$/`/'
    echo
    echo "### CI gates"
    echo "- android: ${android}"
    echo "- backend: ${backend}"
    echo "- frontend: ${frontend}"
    echo "- ios: ${ios}"
    echo "- javascript: ${javascript}"
    echo "- repository: ${repository}"
    echo "- docs_only: ${docs_only}"
    echo "- ci: ${ci}"
  } >> "${GITHUB_STEP_SUMMARY}"
}

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  write_outputs
else
  outputs_payload
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  write_summary
fi
