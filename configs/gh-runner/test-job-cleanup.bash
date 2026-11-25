#!/usr/bin/env bash
# Positional arguments in bash -c snippets expand in the child shell.
# shellcheck disable=SC2016
set -euo pipefail

# Exercise a job handoff in disposable services on the local user manager.
cd "$(dirname "$0")/../.."
fixture=$(mktemp -d)
unit="test-runner-cleanup-${fixture##*/}.service"
cleanup() {
  systemctl --user stop "$unit" 2>/dev/null || true
  rm -rf -- "$fixture"
}
trap cleanup EXIT

settings=$(nix eval --impure --json --expr '
  let f = builtins.getFlake (toString ./.);
      os = f.inputs.nixpkgs.lib.nixosSystem {
        system = builtins.currentSystem;
        modules = [ ./configs/gh-runner.nix ];
      };
      service = os.config.systemd.services.github-runner-runner;
  in { inherit (service.serviceConfig) ExecStart ExecStartPre KillMode KillSignal Restart
         BindPaths CacheDirectory; inherit (service.environment) TEST_STATE_ROOT; }
')
jq -e '.ExecStart | endswith("/bin/Runner.Listener run --startuptype service --once")' \
  <<<"$settings" >/dev/null
# Keep every previously valid OsVm socket and livepatch profile path within
# budget, for all repository/run IDs and retries supported under /tmp.
jq -e '.TEST_STATE_ROOT as $root | ("/var/cache/" + .CacheDirectory + ":" + $root) as $mount |
  ($root | utf8bytelength) <= 4 and (.BindPaths | index($mount)) != null' <<<"$settings" >/dev/null
jq -e '.ExecStartPre[0] | endswith("check-cgroup.bash %n")' <<<"$settings" >/dev/null
guard="\"$(command -v bash)\" \"$PWD/configs/gh-runner/check-cgroup.bash\""

# A dirty cgroup must refuse admission even if systemd could not reap it.
dirty_unit="dirty-$unit"
if systemd-run --user --wait --collect --pipe --quiet --unit="$dirty_unit" \
    bash -c 'sleep 10 & exec bash "$1" "$2"' _ \
    "$PWD/configs/gh-runner/check-cgroup.bash" "$dirty_unit" >"$fixture/guard.log" 2>&1; then
  echo "Guard admitted another process" >&2
  exit 1
fi
grep -F 'remains in' "$fixture/guard.log"

# Model a canceled test job with a detached guest which ignores graceful stop.
# The next invocation stands in for a build-only job on the same registration.
cat >"$fixture/job.bash" <<'JOB'
set -euo pipefail
cd "$1"
if [[ -e guest.pid ]]; then
  if kill -0 "$(<guest.pid)" 2>/dev/null; then
    echo "Guest survived the job handoff" >&2
    exit 1
  fi
  touch next-job-started
  exec sleep 60
fi
setsid bash -c 'trap "" INT TERM; echo "$$" >guest.pid; exec sleep 60' &
while [[ ! -s guest.pid ]]; do sleep 0.02; done
exit 0
JOB

properties=()
for name in KillMode KillSignal Restart; do
  properties+=("--property=$name=$(jq -er --arg key "$name" '.[$key]' <<<"$settings")")
done
systemd-run --user --quiet --collect --unit="$unit" "${properties[@]}" \
  --property="ExecStartPre=$guard $unit" --property=TimeoutStopSec=1s --property=RestartSec=100ms \
  "$(command -v bash)" "$fixture/job.bash" "$fixture"
timeout 15 bash -c 'until test -e "$1/next-job-started"; do sleep 0.1; done' _ "$fixture"
echo "Runner job handoff passed"
