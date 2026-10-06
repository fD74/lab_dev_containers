#!/usr/bin/env bash
set -euo pipefail

readonly lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly workspace_root="$(dirname -- "${lab_dir}")"
readonly projects_source="${workspace_root}/projects"
readonly image_repository="ipr-ansible-lab"

usage() {
  printf 'Usage: %s <base|ansible-dev> <ubuntu24|rocky9> [instance]\n' \
    "${BASH_SOURCE[0]}" >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 2
fi

mode="$1"
distro="$2"
instance="${3:-main}"

if [[ ! "${mode}" =~ ^(base|ansible-dev)$ || ! "${distro}" =~ ^(ubuntu24|rocky9)$ || ! "${instance}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  usage
  exit 2
fi

if [[ ! -d "${projects_source}" ]]; then
  echo "Project source directory not found: ${projects_source}" >&2
  exit 1
fi

image_tag="${image_repository}:${mode}-${distro}-latest"
container_name="ipr-lab-${mode}-${distro}-${instance}"

if ! docker image inspect "${image_tag}" >/dev/null 2>&1; then
  build_script="${lab_dir}/build-base.sh"
  if [[ "${mode}" == ansible-dev ]]; then
    build_script="${lab_dir}/build-ansible-dev.sh"
  fi
  echo "Image not found: ${image_tag}" >&2
  echo "Build it with ${build_script} ${distro}" >&2
  exit 1
fi

if docker container inspect "${container_name}" >/dev/null 2>&1; then
  if [[ "$(docker inspect --format '{{.State.Running}}' "${container_name}")" != true ]]; then
    docker start "${container_name}" >/dev/null
  fi
  printf 'Existing persistent container: %s\n' "${container_name}"
  printf 'Its project snapshot and image are unchanged; use a new instance name for a new snapshot.\n'
else
  docker run -d \
    --name "${container_name}" \
    --restart unless-stopped \
    --mount "type=bind,source=${projects_source},target=/mnt/projects-source,readonly" \
    "${image_tag}" >/dev/null
  printf 'Created persistent container: %s\n' "${container_name}"
fi

printf 'Read-only source: %s -> /mnt/projects-source\n' "${projects_source}"
printf 'Writable project snapshot: /home/sc-ansible/projects\n'
printf 'Open a shell with: docker exec -it -u tester %s bash\n' "${container_name}"