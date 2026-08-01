#!/usr/bin/env bash
set -euo pipefail

lock_file=$1
active_file=$2

exec 9>"$lock_file"
flock 9

rm -f -- "$active_file"
echo "Cleared the GitHub runner job marker; Nix garbage collection can resume"
