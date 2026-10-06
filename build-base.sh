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

build_base() {
  local distro="$1"
  local base_image
  local output_tag

  case "${distro}" in
    ubuntu24) base_image="ubuntu:24.04" ;;
    rocky9) base_image="rockylinux:9" ;;
    *) usage; exit 2 ;;
  esac

  output_tag="${image_repository}:base-${distro}-latest"
  docker build --pull \
    --file "${build_context_dir}/Dockerfile.base" \
    --build-arg "BASE_IMAGE=${base_image}" \
    --tag "${output_tag}" \
    "${build_context_dir}"
}

require_command docker
docker info >/dev/null

build_context_dir="$(mktemp -d "${TMPDIR:-/tmp}/ipr-ansible-lab-base.XXXXXX")"
mkdir -p "${build_context_dir}/certs"
cp -- "${lab_dir}/Dockerfile.base" "${build_context_dir}/Dockerfile.base"
cp -- "${lab_dir}/container-entrypoint.sh" "${build_context_dir}/container-entrypoint.sh"
if [[ -r "${projects_root}/os_mgmt/artifacts/certs/IPR-CA.crt" ]]; then
  install -m 0644 "${projects_root}/os_mgmt/artifacts/certs/IPR-CA.crt" \
    "${build_context_dir}/certs/IPR-CA.crt"
fi

case "${1:-all}" in
  all)
    build_base ubuntu24
    build_base rocky9
    ;;
  ubuntu24|rocky9)
    [[ $# -le 1 ]] || { usage; exit 2; }
    build_base "$1"
    ;;
  *) usage; exit 2 ;;
esac