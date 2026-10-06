#!/usr/bin/env bash
set -euo pipefail

readonly source_dir="/mnt/projects-source"
readonly projects_dir="/home/sc-ansible/projects"
readonly snapshot_marker="${projects_dir}/.lab-projects-snapshot"

if [[ ! -d "${source_dir}" ]]; then
  echo "Read-only project source mount is missing: ${source_dir}" >&2
  exit 1
fi

if [[ ! -e "${snapshot_marker}" ]]; then
  install -d "${projects_dir}"
  shopt -s dotglob nullglob
  for project_name in ansible_mgmt os_mgmt; do
    if [[ ! -d "${source_dir}/${project_name}" ]]; then
      echo "Required project source is missing: ${source_dir}/${project_name}" >&2
      exit 1
    fi
    cp -a -- "${source_dir}/${project_name}" "${projects_dir}/"
  done

  if [[ ! -f "${source_dir}/playbook" ]]; then
    echo "Project wrapper is missing: ${source_dir}/playbook" >&2
    exit 1
  fi
  cp -a -- "${source_dir}/playbook" "${projects_dir}/playbook"
  touch "${snapshot_marker}"
fi

exec "$@"