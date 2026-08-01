#!/usr/bin/env bash
set -euo pipefail

lock_file=$1
active_file=$2

exec 9>"$lock_file"
flock 9

umask 077
printf 'active\n' >"$active_file"
echo "Marked the GitHub runner job active; Nix garbage collection is deferred"
