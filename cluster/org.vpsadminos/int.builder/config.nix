{ config, pkgs, lib, confLib, ... }:
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  environment.systemPackages = with pkgs; [
    git
  ];

  nix.sandboxPaths = [
    "/nix/var/cache/ccache"
  ];

  system.stateVersion = "22.05";
}
