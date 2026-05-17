{ config, pkgs, ... }:
let
  runnerUser = config.services.github-runners.runner.user;
  runnerGroup = config.services.github-runners.runner.group;
  githubRunnerNixGc = pkgs.writeShellScript "github-runner-nix-gc" ''
    set -eu

    store=/nix/store
    threshold=75

    blocks_total="$(${pkgs.coreutils}/bin/stat -f -c '%b' "$store")"
    blocks_free="$(${pkgs.coreutils}/bin/stat -f -c '%f' "$store")"
    blocks_used=$((blocks_total - blocks_free))
    usage=$((blocks_used * 100 / blocks_total))

    if [ "$usage" -lt "$threshold" ]; then
      echo "$store usage is $usage%, below threshold $threshold%; skipping Nix garbage collection"
      exit 0
    fi

    echo "$store usage is $usage%, at or above threshold $threshold%; running Nix garbage collection"
    exec ${config.nix.package.out}/bin/nix-collect-garbage
  '';
in
{
  nix.settings = {
    substituters = [ "https://cache.vpsadminos.org" ];
    trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };

  systemd.services.github-runner-nix-gc = {
    description = "GitHub runner conditional Nix garbage collection";
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
    extraPackages = with pkgs; [
      gnumake
      openssh
    ];
    user = "github-runner";
    group = "github-runner";
    serviceOverrides = {
      # Allow access to /dev/kvm
      PrivateDevices = false;
      ReadWritePaths = [
        "/nix/var/nix/gcroots/per-user/${runnerUser}"
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
