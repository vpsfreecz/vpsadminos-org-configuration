#!/usr/bin/env bash
set -euo pipefail

script_directory=$(dirname "$(readlink -f "$0")")
test_directory=$(mktemp -d)
worker_pid=

cleanup() {
  if [[ -n "$worker_pid" ]]; then
    kill "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
  fi

  rm -rf -- "$test_directory"
}

fail() {
  echo "$1" >&2
  exit 1
}

trap cleanup EXIT

lock_file="$test_directory/lock"
active_file="$test_directory/job-active"
store="$test_directory/store"
gc_called="$test_directory/gc-called"
gc_command="$test_directory/nix-collect-garbage"
worker_command="$test_directory/Runner.Worker"
lock_ready="$test_directory/lock-ready"

mkdir "$store"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  ": >\"\$GC_CALLED\"" \
  >"$gc_command"
chmod +x "$gc_command"
export GC_CALLED="$gc_called"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'sleep 30' \
  >"$worker_command"
chmod +x "$worker_command"

(
  exec 8>"$lock_file"
  flock 8
  : >"$lock_ready"
  sleep 1
) &
lock_holder_pid=$!

while [[ ! -e "$lock_ready" ]]; do
  sleep 0.01
done

bash "$script_directory/job-started.bash" "$lock_file" "$active_file" &
start_hook_pid=$!
sleep 0.1
[[ ! -e "$active_file" ]] || fail "job-started hook did not wait for active GC"
wait "$lock_holder_pid"
wait "$start_hook_pid"
[[ -e "$active_file" ]] || fail "job-started hook did not create the active marker"

"$worker_command" &
worker_pid=$!
bash "$script_directory/nix-gc.bash" \
  "$lock_file" "$active_file" "$(id -un)" "$gc_command" "$store" 0
[[ ! -e "$gc_called" ]] || fail "GC ran while a GitHub runner job was active"

bash "$script_directory/job-completed.bash" "$lock_file" "$active_file"
[[ ! -e "$active_file" ]] || fail "job-completed hook did not clear the marker"

kill "$worker_pid"
wait "$worker_pid" 2>/dev/null || true
worker_pid=

: >"$active_file"
bash "$script_directory/nix-gc.bash" \
  "$lock_file" "$active_file" "$(id -un)" "$gc_command" "$store" 0
[[ ! -e "$active_file" ]] || fail "GC did not clear a stale job marker"
[[ -e "$gc_called" ]] || fail "GC did not run after clearing a stale marker"

echo "GitHub runner Nix GC coordination tests passed"
