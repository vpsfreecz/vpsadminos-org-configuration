{ config, pkgs, ... }:
{
  nix.settings = {
    substituters = [ "https://cache.vpsadminos.org" ];
    trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

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

    groups.github-runner = {};
  };
}