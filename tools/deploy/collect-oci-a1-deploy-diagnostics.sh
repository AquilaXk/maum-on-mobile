#!/usr/bin/env bash
set -euo pipefail

phase="before"
output_dir="deploy-debug"
container_name="maum-on-mobile-back"
previous_container_name="maum-on-mobile-back-previous"
image_tag=""
log_tail="200"

usage() {
  cat <<USAGE
Usage: collect-oci-a1-deploy-diagnostics.sh [options]

Options:
  --phase NAME                 Diagnostic phase label. Default: before
  --output-dir PATH            Directory for diagnostic files. Default: deploy-debug
  --container NAME             Active backend container name. Default: maum-on-mobile-back
  --previous-container NAME    Previous backend container name. Default: maum-on-mobile-back-previous
  --image IMAGE                Optional backend image tag to inspect
  --log-tail LINES             Reserved log-tail validation option. Default: 200
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      phase="${2:?phase value is required}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:?output directory is required}"
      shift 2
      ;;
    --container)
      container_name="${2:?container name is required}"
      shift 2
      ;;
    --previous-container)
      previous_container_name="${2:?previous container name is required}"
      shift 2
      ;;
    --image)
      image_tag="${2:?image tag is required}"
      shift 2
      ;;
    --log-tail)
      log_tail="${2:?log tail value is required}"
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

if [[ ! "${phase}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid phase: ${phase}" >&2
  exit 2
fi

if [[ "${output_dir}" == *".."* ]]; then
  echo "Invalid output directory: ${output_dir}" >&2
  exit 2
fi

if [[ ! "${container_name}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]]; then
  echo "Invalid container name: ${container_name}" >&2
  exit 2
fi

if [[ ! "${previous_container_name}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]]; then
  echo "Invalid previous container name: ${previous_container_name}" >&2
  exit 2
fi

if [[ -n "${image_tag}" && ! "${image_tag}" =~ ^[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9_.:-]+$ ]]; then
  echo "Invalid image tag: ${image_tag}" >&2
  exit 2
fi

if [[ ! "${log_tail}" =~ ^[0-9]+$ ]] || (( log_tail < 1 || log_tail > 5000 )); then
  echo "Invalid log tail: ${log_tail}" >&2
  exit 2
fi

install -d -m 0755 "${output_dir}"

docker_prefix=()
if ! docker info >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo -n docker info >/dev/null 2>&1; then
    docker_prefix=(sudo -n)
  else
    echo "docker is unavailable" >"${output_dir}/${phase}-docker-unavailable.txt"
  fi
fi

capture() {
  local name="$1"
  shift

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"${output_dir}/${phase}-${name}" 2>&1 || true
}

{
  echo "phase=${phase}"
  echo "run_id=${GITHUB_RUN_ID:-local}"
  echo "run_attempt=${GITHUB_RUN_ATTEMPT:-0}"
  echo "sha=${GITHUB_SHA:-unknown}"
  echo "ref=${GITHUB_REF:-unknown}"
  echo "container=${container_name}"
  echo "previous_container=${previous_container_name}"
  echo "image=${image_tag:-unknown}"
  date -u '+generated_at=%Y-%m-%dT%H:%M:%SZ'
} >"${output_dir}/${phase}-metadata.txt"

if [[ -f "${output_dir}/${phase}-docker-unavailable.txt" ]]; then
  exit 0
fi

capture "docker-info.txt" "${docker_prefix[@]}" docker info
capture "docker-ps.txt" "${docker_prefix[@]}" docker ps -a
capture "container-status.txt" "${docker_prefix[@]}" docker inspect --format \
  'name={{.Name}} image={{.Config.Image}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} restart={{.HostConfig.RestartPolicy.Name}} ports={{json .NetworkSettings.Ports}}' \
  "${container_name}"
capture "previous-container-status.txt" "${docker_prefix[@]}" docker inspect --format \
  'name={{.Name}} image={{.Config.Image}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} restart={{.HostConfig.RestartPolicy.Name}} ports={{json .NetworkSettings.Ports}}' \
  "${previous_container_name}"

if [[ -n "${image_tag}" ]]; then
  capture "image-status.txt" "${docker_prefix[@]}" docker image inspect --format \
    'id={{.Id}} tags={{json .RepoTags}} digests={{json .RepoDigests}} created={{.Created}} size={{.Size}}' \
    "${image_tag}"
fi
