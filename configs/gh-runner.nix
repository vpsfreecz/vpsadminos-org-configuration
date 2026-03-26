{ config, pkgs, ... }:
let
  runnerUser = config.services.github-runners.runner.user;
  runnerGroup = config.services.github-runners.runner.group;
in
{
  nix.settings = {
    substituters = [ "https://cache.vpsadminos.org" ];
    trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
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
