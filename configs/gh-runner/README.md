# GitHub runner job cleanup

The runners serve both vpsAdmin and vpsAdminOS. Each listener accepts one
job with `--once`. When the listener exits, systemd signals the processes in
its service cgroup and gives them 30 seconds to exit before sending SIGKILL.
This covers detached test-runner workers, QEMU guests and virtiofsd helpers,
including when GitHub skips a canceled workflow's cleanup steps. The Nix
daemon runs in its own service.

Before starting another listener, the service checks its cgroup for surviving
processes. If a process is stuck, the journal names its PID and cgroup and the
service retries after five seconds. Inspect the service with
`journalctl -u github-runner-runner.service`.

The NixOS runner module cleans its work directory at each service start.
The shared test-state actions use `/ci` inside the service. This bind mount
keeps QEMU socket paths short and stores files in
`/var/cache/github-runner-test-state` on the host. Unpublished test
evidence survives jobs and restarts there. After recovering evidence from an
interrupted job, an operator can remove that run's directory. The runner
keeps its registration and labels, and the Nix store is shared between jobs.
Drain the current job before activating or rolling back this change on a host.
Recover any needed evidence from the old service's private `/tmp` before
the first activation.

Run `bash configs/gh-runner/test-job-cleanup.bash` from the checkout to exercise
the handoff using a local systemd user manager and cgroup v2. When upgrading
the runner package, check that its listener still supports `run --once` with
a persistent registration.
