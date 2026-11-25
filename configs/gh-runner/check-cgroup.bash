#!/usr/bin/env bash
set -euo pipefail

# Run first in ExecStartPre, before the runner recreates its workspace or
# connects to GitHub. systemd can restart a unit with surviving processes
# after its stop timeout, for example when a VM is stuck in kernel I/O.
unit=$1
# A container can expose legacy memberships before systemd's unified tree.
path=
while IFS=: read -r hierarchy controllers membership; do
  if [[ $hierarchy == 0 && -z $controllers ]]; then
    path=${membership%/.control}
    break
  fi
done </proc/self/cgroup
if [[ $path != */"$unit" ]]; then
  echo "Cannot identify the cgroup for $unit in /proc/self/cgroup" >&2
  exit 1
fi

group=/sys/fs/cgroup$path
[[ -r "$group/cgroup.procs" ]] || { echo "Cannot read $group/cgroup.procs" >&2; exit 1; }
shopt -s globstar dotglob
for processes in "$group"/**/cgroup.procs; do
  while read -r pid; do
    if [[ $pid != "$$" ]]; then
      echo "Deferring $unit start: PID $pid remains in ${processes%/cgroup.procs}" >&2
      exit 1
    fi
  done <"$processes"
done
