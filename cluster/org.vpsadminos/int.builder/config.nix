{ config, pkgs, lib, confLib, ... }:
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  environment.systemPackages = with pkgs; [
    git
  ];

  nix.settings = {
    substituters = [ "https://cache.vpsadminos.org" ];
    trusted-public-keys = [ "cache.vpsadminos.org:wpIJlNZQIhS+0gFf1U3MC9sLZdLW3sh5qakOWGDoDrE=" ];
    extra-sandbox-paths = [
      "/nix/var/cache/ccache"
    ];
  };

  system.stateVersion = "22.05";
}
