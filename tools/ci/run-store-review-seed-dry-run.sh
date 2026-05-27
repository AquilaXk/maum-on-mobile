#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

node --test "${repo_root}/tools/ci/store-review-seed-contract.test.mjs"

(
  cd "${repo_root}/back"
  ./gradlew test \
    --tests com.maumonmobile.application.service.StoreReviewSeedServiceTest \
    --tests com.maumonmobile.adapter.in.web.review.StoreReviewSeedControllerTest \
    --no-daemon
)
