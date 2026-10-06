#!/usr/bin/env bash
set -euo pipefail

readonly lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly workspace_root="$(dirname -- "${lab_dir}")"
readonly projects_root="${workspace_root}/projects"
readonly image_repository="ipr-ansible-lab"
build_context_dir=""

cleanup_build_context() {
  if [[ -n "${build_context_dir}" && -d "${build_context_dir}" ]]; then
    rm -rf -- "${build_context_dir}"
  fi
}

trap cleanup_build_context EXIT

usage() {
  printf 'Usage: %s [all|ubuntu24|rocky9]\n' "${BASH_SOURCE[0]}" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

stage_project() {
  local name="$1"
  local destination="$2"

  if [[ ! -d "${projects_root}/${name}" ]]; then
    echo "Required project directory not found: ${projects_root}/${name}" >&2
    exit 1
  fi

  mkdir -p "${destination}"
  rsync -a --delete \
    --exclude='.git/' \
    --exclude='.ansible/' \
    --exclude='.direnv/' \
    --exclude='.envrc' \
    --exclude='secrets/' \
    --exclude='artifacts/' \
    --exclude='ansible_cache/' \
    "${projects_root}/${name}/" "${destination}/"
}

build_dev() {
  local distro="$1"
  local base_tag="${image_repository}:base-${distro}-latest"
  local dev_tag="${image_repository}:ansible-dev-${distro}-latest"
  local base_image

  case "${distro}" in
    ubuntu24) base_image="ubuntu:24.04" ;;
    rocky9) base_image="rockylinux:9" ;;
    *) usage; exit 2 ;;
  esac

  if ! docker image inspect "${base_tag}" >/dev/null 2>&1; then
    "${lab_dir}/build-base.sh" "${distro}"
  fi

  build_context_dir="$(mktemp -d "${TMPDIR:-/tmp}/ipr-ansible-lab-dev.XXXXXX")"

  mkdir -p "${build_context_dir}/projects/ansible_mgmt" \
    "${build_context_dir}/projects/os_mgmt"

  stage_project ansible_mgmt "${build_context_dir}/projects/ansible_mgmt"
  stage_project os_mgmt "${build_context_dir}/projects/os_mgmt"

  if [[ -r "${projects_root}/os_mgmt/artifacts/certs/IPR-CA.crt" ]]; then
    install -D -m 0644 "${projects_root}/os_mgmt/artifacts/certs/IPR-CA.crt" \
      "${build_context_dir}/projects/os_mgmt/artifacts/certs/IPR-CA.crt"
  fi

  if [[ ! -f "${projects_root}/playbook" ]]; then
    echo "Project wrapper not found: ${projects_root}/playbook" >&2
    exit 1
  fi
  install -m 0755 "${projects_root}/playbook" "${build_context_dir}/projects/playbook"
  cp -- "${lab_dir}/Dockerfile.ansible-dev" "${build_context_dir}/Dockerfile"

  local build_status=0
  docker build \
    --file "${build_context_dir}/Dockerfile" \
    --build-arg "BASE_IMAGE=${base_tag}" \
    --label "org.ipr.ansible-dev.source-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --tag "${dev_tag}" \
    "${build_context_dir}" || build_status="$?"
  rm -rf -- "${build_context_dir}"
  build_context_dir=""
  return "${build_status}"
}

require_command docker
require_command rsync
docker info >/dev/null

case "${1:-all}" in
  all)
    build_dev ubuntu24
    build_dev rocky9
    ;;
  ubuntu24|rocky9)
    [[ $# -le 1 ]] || { usage; exit 2; }
    build_dev "$1"
    ;;
  *) usage; exit 2 ;;
esac