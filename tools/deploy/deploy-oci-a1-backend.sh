#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  OCI_A1_SSH_HOST
  OCI_A1_SSH_PORT
  OCI_A1_SSH_USER
  OCI_A1_SSH_PRIVATE_KEY_B64
  OCI_A1_SSH_KNOWN_HOSTS_B64
  OCI_A1_BACKEND_ENV_B64
  OCI_A1_VERTEX_KEY_JSON_B64
  MAUMON_BACKEND_BUNDLE_PATH
  MAUMON_BACKEND_IMAGE_TAG
)

for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
done

if [[ ! -f "${MAUMON_BACKEND_BUNDLE_PATH}" ]]; then
  echo "Backend bundle not found: ${MAUMON_BACKEND_BUNDLE_PATH}" >&2
  exit 1
fi

if [[ ! "${MAUMON_BACKEND_IMAGE_TAG}" =~ ^[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid MAUMON_BACKEND_IMAGE_TAG: ${MAUMON_BACKEND_IMAGE_TAG}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

ssh_key="${tmp_dir}/oci-a1-key"
known_hosts="${tmp_dir}/known_hosts"
backend_env="${tmp_dir}/backend.env"
vertex_key="${tmp_dir}/vertex-key.json"
bundle_copy="${tmp_dir}/maum-on-mobile-backend-bundle.tar.gz"

printf '%s' "${OCI_A1_SSH_PRIVATE_KEY_B64}" | base64 --decode >"${ssh_key}"
printf '%s' "${OCI_A1_SSH_KNOWN_HOSTS_B64}" | base64 --decode >"${known_hosts}"
printf '%s' "${OCI_A1_BACKEND_ENV_B64}" | base64 --decode >"${backend_env}"
printf '%s' "${OCI_A1_VERTEX_KEY_JSON_B64}" | base64 --decode >"${vertex_key}"
cp "${MAUMON_BACKEND_BUNDLE_PATH}" "${bundle_copy}"
chmod 600 "${ssh_key}"

ssh_base=(
  ssh
  -i "${ssh_key}"
  -p "${OCI_A1_SSH_PORT}"
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile="${known_hosts}"
  "${OCI_A1_SSH_USER}@${OCI_A1_SSH_HOST}"
)

scp_base=(
  scp
  -i "${ssh_key}"
  -P "${OCI_A1_SSH_PORT}"
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile="${known_hosts}"
)

remote_staging="/tmp/maum-on-mobile-deploy-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}"

"${ssh_base[@]}" "mkdir -p '${remote_staging}'"
"${scp_base[@]}" "${bundle_copy}" "${backend_env}" "${vertex_key}" "${OCI_A1_SSH_USER}@${OCI_A1_SSH_HOST}:${remote_staging}/"

"${ssh_base[@]}" \
  "MAUMON_BACKEND_IMAGE_TAG='${MAUMON_BACKEND_IMAGE_TAG}' MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS='${MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS:-90}' REMOTE_STAGING='${remote_staging}' bash -s" <<'REMOTE'
set -euo pipefail

container_name="maum-on-mobile-back"
previous_container_name="maum-on-mobile-back-previous"
image_tag="${MAUMON_BACKEND_IMAGE_TAG}"
health_timeout_seconds="${MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS}"
container_uid="10001"
container_gid="10001"
staging_dir="${REMOTE_STAGING}"
release_root="/opt/maum-on-mobile/releases"
release_dir="${release_root}/${image_tag//[^A-Za-z0-9_.-]/-}"
env_file="/etc/maum-on-mobile/backend.env"
vertex_key_file="/etc/maum-on-mobile/vertex-key.json"
bundle_path="${staging_dir}/maum-on-mobile-backend-bundle.tar.gz"

rollback() {
  echo "rollback: restoring previous backend container" >&2
  sudo docker logs --tail 200 "${container_name}" || true
  sudo docker rm -f "${container_name}" >/dev/null 2>&1 || true
  if sudo docker inspect "${previous_container_name}" >/dev/null 2>&1; then
    sudo docker rename "${previous_container_name}" "${container_name}"
    sudo docker start "${container_name}"
  fi
}

require_remote_file() {
  if [[ ! -f "$1" ]]; then
    echo "Remote file not found: $1" >&2
    exit 1
  fi
}

install_runtime() {
  if ! command -v docker >/dev/null 2>&1; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl docker.io
  else
    if ! command -v curl >/dev/null 2>&1; then
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl
    fi
  fi

  sudo systemctl enable --now docker
}

wait_for_health() {
  local deadline=$((SECONDS + health_timeout_seconds))
  until sudo docker exec "${container_name}" curl -fsS "http://127.0.0.1:8080/actuator/health" >/dev/null; do
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 3
  done
}

require_remote_file "${bundle_path}"
require_remote_file "${staging_dir}/backend.env"
require_remote_file "${staging_dir}/vertex-key.json"

install_runtime

sudo install -d -m 0755 "${release_root}"
sudo rm -rf "${release_dir}"
sudo install -d -m 0755 "${release_dir}"
sudo tar -xzf "${bundle_path}" -C "${release_dir}"
sudo install -d -m 0750 /etc/maum-on-mobile
sudo install -m 0640 "${staging_dir}/backend.env" "${env_file}"
sudo install -m 0400 "${staging_dir}/vertex-key.json" "${vertex_key_file}"
sudo chown "${container_uid}:${container_gid}" "${vertex_key_file}"

sudo docker build -t "${image_tag}" -f "${release_dir}/Dockerfile" "${release_dir}"
sudo docker rm -f "${previous_container_name}" >/dev/null 2>&1 || true

if sudo docker inspect "${container_name}" >/dev/null 2>&1; then
  sudo docker stop "${container_name}" >/dev/null 2>&1 || true
  sudo docker rename "${container_name}" "${previous_container_name}"
fi

sudo docker run \
  --detach \
  --name "${container_name}" \
  --restart unless-stopped \
  --publish 8080:8080 \
  --env-file "${env_file}" \
  --mount type=bind,source="${vertex_key_file}",target=/run/secrets/vertex-key.json,readonly \
  --health-cmd 'curl -fsS http://127.0.0.1:8080/actuator/health || exit 1' \
  --health-interval 30s \
  --health-timeout 5s \
  --health-start-period 40s \
  --health-retries 5 \
  "${image_tag}"

if ! wait_for_health; then
  rollback
  exit 1
fi

curl -fsS "http://127.0.0.1:8080/actuator/health" >/dev/null
sudo docker rm "${previous_container_name}" >/dev/null 2>&1 || true
rm -rf "${staging_dir}"
echo "deployed ${image_tag}"
REMOTE
