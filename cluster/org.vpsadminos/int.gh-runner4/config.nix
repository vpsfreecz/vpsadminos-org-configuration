{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
    ../../../configs/gh-runner.nix
  ];

  services.github-runners.runner = {
    name = "gh-runner4.int.vpsadminos.org";

    # This AMD runner is hosted on a production node and is reserved for the
    # livepatch lifecycle. Without the default self-hosted/OS/architecture
    # labels, generic CI jobs cannot be scheduled here accidentally.
    noDefaultLabels = true;
    extraLabels = [ "amd-livepatch" ];
  };

  system.stateVersion = "24.11";
}
