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

docker_network="${MAUMON_DOCKER_NETWORK:-maum-on-mobile}"
app_data_dir="${MAUMON_APP_DATA_DIR:-/var/lib/maumon-data/app}"
postgres_container_name="${MAUMON_POSTGRES_CONTAINER_NAME:-maum-on-mobile-postgres}"
postgres_data_volume="${MAUMON_POSTGRES_DATA_VOLUME:-maum-on-mobile-postgres-data}"
postgres_image_tag="${MAUMON_POSTGRES_IMAGE_TAG:-postgres:16-alpine}"
deploy_managed_postgres="${MAUMON_DEPLOY_MANAGED_POSTGRES:-auto}"
host_http_port="${MAUMON_HOST_HTTP_PORT:-80}"
deploy_health_timeout_seconds="${MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS:-90}"
deploy_run_id="${GITHUB_RUN_ID:-local}"
deploy_run_attempt="${GITHUB_RUN_ATTEMPT:-0}"

if [[ ! "${docker_network}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]]; then
  echo "Invalid MAUMON_DOCKER_NETWORK: ${docker_network}" >&2
  exit 1
fi

if [[ ! "${app_data_dir}" =~ ^/[A-Za-z0-9._/-]+$ || "${app_data_dir}" == *".."* ]]; then
  echo "Invalid MAUMON_APP_DATA_DIR: ${app_data_dir}" >&2
  exit 1
fi

if [[ ! "${postgres_container_name}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]]; then
  echo "Invalid MAUMON_POSTGRES_CONTAINER_NAME: ${postgres_container_name}" >&2
  exit 1
fi

if [[ ! "${postgres_data_volume}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]]; then
  echo "Invalid MAUMON_POSTGRES_DATA_VOLUME: ${postgres_data_volume}" >&2
  exit 1
fi

if [[ ! "${postgres_image_tag}" =~ ^[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid MAUMON_POSTGRES_IMAGE_TAG: ${postgres_image_tag}" >&2
  exit 1
fi

if [[ ! "${deploy_managed_postgres}" =~ ^(auto|true|false)$ ]]; then
  echo "Invalid MAUMON_DEPLOY_MANAGED_POSTGRES: ${deploy_managed_postgres}" >&2
  exit 1
fi

if [[ ! "${host_http_port}" =~ ^[0-9]+$ ]] || (( host_http_port < 1 || host_http_port > 65535 )); then
  echo "Invalid MAUMON_HOST_HTTP_PORT: ${host_http_port}" >&2
  exit 1
fi

if [[ ! "${deploy_health_timeout_seconds}" =~ ^[0-9]+$ ]] || (( deploy_health_timeout_seconds < 1 || deploy_health_timeout_seconds > 3600 )); then
  echo "Invalid MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS: ${deploy_health_timeout_seconds}" >&2
  exit 1
fi

if [[ ! "${deploy_run_id}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid GITHUB_RUN_ID: ${deploy_run_id}" >&2
  exit 1
fi

if [[ ! "${deploy_run_attempt}" =~ ^[0-9]+$ ]]; then
  echo "Invalid GITHUB_RUN_ATTEMPT: ${deploy_run_attempt}" >&2
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

remote_staging="/tmp/maum-on-mobile-deploy-${deploy_run_id}-${deploy_run_attempt}"

"${ssh_base[@]}" "install -d -m 0700 '${remote_staging}'"
"${scp_base[@]}" "${bundle_copy}" "${backend_env}" "${vertex_key}" "${OCI_A1_SSH_USER}@${OCI_A1_SSH_HOST}:${remote_staging}/"

"${ssh_base[@]}" \
  "MAUMON_BACKEND_IMAGE_TAG='${MAUMON_BACKEND_IMAGE_TAG}' MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS='${deploy_health_timeout_seconds}' MAUMON_HOST_HTTP_PORT='${host_http_port}' MAUMON_DOCKER_NETWORK='${docker_network}' MAUMON_APP_DATA_DIR='${app_data_dir}' MAUMON_POSTGRES_CONTAINER_NAME='${postgres_container_name}' MAUMON_POSTGRES_DATA_VOLUME='${postgres_data_volume}' MAUMON_POSTGRES_IMAGE_TAG='${postgres_image_tag}' MAUMON_DEPLOY_MANAGED_POSTGRES='${deploy_managed_postgres}' REMOTE_STAGING='${remote_staging}' bash -s" <<'REMOTE'
set -euo pipefail

container_name="maum-on-mobile-back"
previous_container_name="maum-on-mobile-back-previous"
image_tag="${MAUMON_BACKEND_IMAGE_TAG}"
health_timeout_seconds="${MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS}"
host_http_port="${MAUMON_HOST_HTTP_PORT:-80}"
network_name="${MAUMON_DOCKER_NETWORK:-maum-on-mobile}"
app_data_dir="${MAUMON_APP_DATA_DIR:-/var/lib/maumon-data/app}"
postgres_container_name="${MAUMON_POSTGRES_CONTAINER_NAME:-maum-on-mobile-postgres}"
postgres_data_volume="${MAUMON_POSTGRES_DATA_VOLUME:-maum-on-mobile-postgres-data}"
postgres_image_tag="${MAUMON_POSTGRES_IMAGE_TAG:-postgres:16-alpine}"
deploy_managed_postgres="${MAUMON_DEPLOY_MANAGED_POSTGRES:-auto}"
container_uid="10001"
container_gid="10001"
staging_dir="${REMOTE_STAGING}"
release_root="/opt/maum-on-mobile/releases"
release_dir="${release_root}/${image_tag//[^A-Za-z0-9_.-]/-}"
env_file="/etc/maum-on-mobile/backend.env"
vertex_key_file="/etc/maum-on-mobile/vertex-key.json"
bundle_path="${staging_dir}/maum-on-mobile-backend-bundle.tar.gz"

if [[ ! "${health_timeout_seconds}" =~ ^[0-9]+$ ]] || (( health_timeout_seconds < 1 || health_timeout_seconds > 3600 )); then
  echo "Invalid MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS: ${health_timeout_seconds}" >&2
  exit 1
fi

cleanup_remote_staging() {
  rm -f "${staging_dir}/backend.env" "${staging_dir}/vertex-key.json" "${bundle_path}" >/dev/null 2>&1 || true
  rmdir --ignore-fail-on-non-empty "${staging_dir}" >/dev/null 2>&1 || true
}

rollback() {
  echo "rollback: restoring previous backend container" >&2
  sudo docker logs --tail 200 "${container_name}" || true
  sudo docker rm -f "${container_name}" >/dev/null 2>&1 || true
  if sudo docker inspect "${previous_container_name}" >/dev/null 2>&1; then
    sudo docker rename "${previous_container_name}" "${container_name}"
    sudo docker start "${container_name}"
  fi
}

trap cleanup_remote_staging EXIT
trap 'exit 143' TERM

require_remote_file() {
  if [[ ! -f "$1" ]]; then
    echo "Remote file not found: $1" >&2
    exit 1
  fi
}

env_value() {
  local key="$1"
  # backend.env는 root 전용 권한으로 보관하므로 값 조회도 sudo로 수행한다.
  sudo awk -v key="${key}" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "${env_file}"
}

postgres_url_host() {
  local url="$1"
  local rest="${url#jdbc:postgresql://}"
  if [[ "${rest}" == "${url}" ]]; then
    return 1
  fi
  rest="${rest%%/*}"
  rest="${rest%%:*}"
  printf '%s' "${rest}"
}

postgres_url_db_name() {
  local url="$1"
  local rest="${url#jdbc:postgresql://}"
  local db_name="postgres"
  if [[ "${rest}" == */* ]]; then
    db_name="${rest#*/}"
    db_name="${db_name%%\?*}"
    db_name="${db_name%%#*}"
    db_name="${db_name%%/*}"
  fi
  printf '%s' "${db_name:-postgres}"
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

prepare_runtime_resources() {
  if ! sudo docker network inspect "${network_name}" >/dev/null 2>&1; then
    sudo docker network create "${network_name}" >/dev/null
  fi

  sudo install -d -m 0750 -o "${container_uid}" -g "${container_gid}" "${app_data_dir}"
}

allow_host_http_ingress() {
  if [[ ! "${host_http_port}" =~ ^[0-9]+$ ]] || (( host_http_port < 1 || host_http_port > 65535 )); then
    echo "Invalid MAUMON_HOST_HTTP_PORT: ${host_http_port}" >&2
    exit 1
  fi

  if ! command -v iptables >/dev/null 2>&1; then
    echo "iptables is required to allow host HTTP ingress" >&2
    exit 1
  fi

  # OCI Ubuntu 기본 INPUT reject보다 앞에 HTTP 허용 규칙을 둔다.
  if ! sudo iptables -C INPUT -p tcp --dport "${host_http_port}" -j ACCEPT >/dev/null 2>&1; then
    sudo iptables -I INPUT 1 -p tcp --dport "${host_http_port}" -j ACCEPT
  fi
}

wait_for_postgres() {
  local db_username="$1"
  local db_name="$2"
  local deadline=$((SECONDS + health_timeout_seconds))
  until sudo docker exec "${postgres_container_name}" pg_isready -U "${db_username}" -d "${db_name}" >/dev/null; do
    if (( SECONDS >= deadline )); then
      return 1
    fi
    sleep 3
  done
}

prepare_managed_postgres() {
  local db_url
  local db_host
  local db_name
  local db_username
  local db_password
  local postgres_aliases

  db_url="$(env_value DB_URL)"
  db_host="$(postgres_url_host "${db_url}")"

  if [[ "${deploy_managed_postgres}" == "false" ]]; then
    return
  fi

  if [[ "${db_host}" != "postgres" ]]; then
    if [[ "${deploy_managed_postgres}" == "true" ]]; then
      echo "Managed PostgreSQL requires DB_URL host postgres" >&2
      exit 1
    fi
    return
  fi

  db_name="$(postgres_url_db_name "${db_url}")"
  db_username="$(env_value DB_USERNAME)"
  db_password="$(env_value DB_PASSWORD)"

  if [[ -z "${db_username}" || -z "${db_password}" || -z "${db_name}" ]]; then
    echo "Managed PostgreSQL requires DB_URL, DB_USERNAME, and DB_PASSWORD" >&2
    exit 1
  fi

  sudo docker volume create "${postgres_data_volume}" >/dev/null

  if ! sudo docker inspect "${postgres_container_name}" >/dev/null 2>&1; then
    sudo docker run \
      --detach \
      --name "${postgres_container_name}" \
      --restart unless-stopped \
      --network "${network_name}" \
      --network-alias postgres \
      --env POSTGRES_DB="${db_name}" \
      --env POSTGRES_USER="${db_username}" \
      --env POSTGRES_PASSWORD="${db_password}" \
      --mount type=volume,source="${postgres_data_volume}",target=/var/lib/postgresql/data \
      "${postgres_image_tag}" >/dev/null
  else
    sudo docker start "${postgres_container_name}" >/dev/null
    postgres_aliases="$(sudo docker inspect --format "{{range \$name, \$network := .NetworkSettings.Networks}}{{if eq \$name \"${network_name}\"}}{{range \$network.Aliases}}{{.}} {{end}}{{end}}{{end}}" "${postgres_container_name}" 2>/dev/null || true)"
    if [[ " ${postgres_aliases} " != *" postgres "* ]]; then
      sudo docker network disconnect "${network_name}" "${postgres_container_name}" >/dev/null 2>&1 || true
      sudo docker network connect --alias postgres "${network_name}" "${postgres_container_name}"
    fi
  fi

  if ! wait_for_postgres "${db_username}" "${db_name}"; then
    echo "Managed PostgreSQL did not become ready" >&2
    exit 1
  fi
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

prepare_runtime_resources
allow_host_http_ingress
prepare_managed_postgres

sudo docker build -t "${image_tag}" -f "${release_dir}/Dockerfile" "${release_dir}"
sudo docker rm -f "${previous_container_name}" >/dev/null 2>&1 || true

if sudo docker inspect "${container_name}" >/dev/null 2>&1; then
  sudo docker stop "${container_name}" >/dev/null 2>&1 || true
  sudo docker rename "${container_name}" "${previous_container_name}"
fi

if ! sudo docker run \
  --detach \
  --name "${container_name}" \
  --restart unless-stopped \
  --publish "${host_http_port}:8080" \
  --network "${network_name}" \
  --env-file "${env_file}" \
  --mount type=bind,source="${app_data_dir}",target=/app/data \
  --mount type=bind,source="${vertex_key_file}",target=/run/secrets/vertex-key.json,readonly \
  --health-cmd 'curl -fsS http://127.0.0.1:8080/actuator/health || exit 1' \
  --health-interval 30s \
  --health-timeout 5s \
  --health-start-period 40s \
  --health-retries 5 \
  "${image_tag}"; then
  rollback
  exit 1
fi

if ! wait_for_health; then
  rollback
  exit 1
fi

curl -fsS "http://127.0.0.1:${host_http_port}/actuator/health" >/dev/null
sudo docker rm "${previous_container_name}" >/dev/null 2>&1 || true
echo "deployed ${image_tag}"
REMOTE
