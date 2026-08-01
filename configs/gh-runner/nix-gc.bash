#!/usr/bin/env bash
set -euo pipefail

lock_file=$1
active_file=$2
runner_user=$3
gc_command=$4
store=$5
threshold=$6

if [[ ! "$threshold" =~ ^[0-9]+$ ]] || ((threshold > 100)); then
  echo "Invalid Nix store usage threshold: $threshold" >&2
  exit 1
fi

exec 9>"$lock_file"
flock 9

if [[ -e "$active_file" ]]; then
  if pgrep -u "$runner_user" -f '(^|/)Runner\.Worker( |$)' >/dev/null; then
    echo "A GitHub runner job is active; skipping Nix garbage collection"
    exit 0
  fi

  echo "Removing stale GitHub runner job marker: $active_file"
  rm -f -- "$active_file"
fi

blocks_total=$(stat -f -c '%b' "$store")
blocks_free=$(stat -f -c '%f' "$store")

if ((blocks_total == 0)); then
  echo "Cannot determine usage of $store: filesystem has no blocks" >&2
  exit 1
fi

blocks_used=$((blocks_total - blocks_free))
usage=$((blocks_used * 100 / blocks_total))

if ((usage < threshold)); then
  echo "$store usage is $usage%, below threshold $threshold%; skipping Nix garbage collection"
  exit 0
fi

echo "$store usage is $usage%, at or above threshold $threshold%; running Nix garbage collection"
"$gc_command"
