#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "${repo_root}/back"
./gradlew test --tests com.maumonmobile.performance.MobileApiPerformanceSmokeTest --no-daemon
