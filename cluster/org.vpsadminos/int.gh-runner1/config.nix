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
    name = "gh-runner1.int.vpsadminos.org";
  };

  system.stateVersion = "24.11";
}
