{
  config,
  lib,
  pkgs,
  ...
}:
let
  runnerUser = config.services.github-runners.runner.user;
  runnerGroup = config.services.github-runners.runner.group;
  runnerRuntimeDirectory = "/run/github-runner/runner";
  gcCoordinationDirectory = "/run/github-runner-nix-gc";
  gcLockFile = "${gcCoordinationDirectory}/lock";
  jobActiveFile = "${runnerRuntimeDirectory}/job-active";
  testStateCache = "github-runner-test-state";
  # OsVm and livepatch profiles construct Unix socket names below this path.
  testStateRoot = "/ci";
  githubRunnerJobStarted = pkgs.writeShellScript "github-runner-job-started.sh" ''
    exec ${pkgs.bash}/bin/bash ${./gh-runner/job-started.bash} \
      ${lib.escapeShellArg gcLockFile} \
      ${lib.escapeShellArg jobActiveFile}
  '';
  githubRunnerJobCompleted = pkgs.writeShellScript "github-runner-job-completed.sh" ''
    exec ${pkgs.bash}/bin/bash ${./gh-runner/job-completed.bash} \
      ${lib.escapeShellArg gcLockFile} \
      ${lib.escapeShellArg jobActiveFile}
  '';
  githubRunnerNixGc = pkgs.writeShellScript "github-runner-nix-gc" ''
    exec ${pkgs.bash}/bin/bash ${./gh-runner/nix-gc.bash} \
      ${lib.escapeShellArg gcLockFile} \
      ${lib.escapeShellArg jobActiveFile} \
      ${lib.escapeShellArg runnerUser} \
      ${config.nix.package.out}/bin/nix-collect-garbage \
      /nix/store \
      75
  '';
in
{
  nix.settings = {
    substituters = [ "https://cache.vpsadminos.org" ];
    trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };

  systemd.services.github-runner-nix-gc = {
    description = "GitHub runner conditional Nix garbage collection";
    path = with pkgs; [
      coreutils
      procps
      util-linux
    ];
    script = "exec ${githubRunnerNixGc}";
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.github-runner-nix-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      RandomizedDelaySec = "2min";
      Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/gcroots/per-user/${runnerUser} 0755 ${runnerUser} ${runnerGroup} -"
    "d ${gcCoordinationDirectory} 0770 root ${runnerGroup} -"
    "f ${gcLockFile} 0660 ${runnerUser} ${runnerGroup} -"
  ];

  networking.firewall.extraCommands = ''
    # socket network for vpsAdminOS test-runner
    iptables -A nixos-fw -m pkttype --pkt-type multicast -p udp --dport 10000:30000 -j ACCEPT
  '';

  services.github-runners.runner = {
    enable = true;
    tokenFile = "/private/gh-runner/token.txt";
    url = "https://github.com/vpsfreecz";
    runnerGroup = "vpsAdminOS runners";
    extraEnvironment = {
      TEST_STATE_ROOT = testStateRoot;
      ACTIONS_RUNNER_HOOK_JOB_STARTED = githubRunnerJobStarted;
      ACTIONS_RUNNER_HOOK_JOB_COMPLETED = githubRunnerJobCompleted;
    };
    extraPackages = with pkgs; [
      gnumake
      openssh
      util-linux
    ];
    user = "github-runner";
    group = "github-runner";
    serviceOverrides = {
      # One job per systemd invocation. Keep the persistent GitHub registration
      # (including runner labels) while systemd reaps leftover VM processes.
      ExecStart = lib.mkForce "${config.services.github-runners.runner.package}/bin/Runner.Listener run --startuptype service --once";
      ExecStartPre = lib.mkBefore [
        "${pkgs.bash}/bin/bash ${./gh-runner/check-cgroup.bash} %n"
      ];
      Restart = lib.mkForce "always";
      RestartSec = "5s";
      KillMode = "control-group";
      TimeoutStopSec = "30s";
      # The shared test-state actions retain unpublished evidence on disk.
      CacheDirectory = testStateCache;
      CacheDirectoryMode = "0700";
      BindPaths = [ "/var/cache/${testStateCache}:${testStateRoot}" ];

      # Allow access to /dev/kvm
      PrivateDevices = false;
      ReadWritePaths = [
        "/nix/var/nix/gcroots/per-user/${runnerUser}"
        gcLockFile
      ];

      # Permissions for virtiofsd
      RestrictNamespaces = false;
      NoNewPrivileges = false;
      PrivateUsers = false;
      SystemCallFilter = [
        ""
      ];
    };
  };

  users = {
    users.github-runner = {
      isSystemUser = true;
      shell = pkgs.bash;
      group = "github-runner";
      subUidRanges = [
        {
          count = 65536;
          startUid = 100000;
        }
      ];
    };

    groups.github-runner = { };
  };
}
