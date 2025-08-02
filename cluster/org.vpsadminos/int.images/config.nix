{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
let
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };
in
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
    ../../../configs/nginx-fancyindex.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport 80 -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nginx = {
    enable = true;

    appendConfig = ''
      worker_processes auto;
    '';

    virtualHosts = {
      "images.vpsadminos.org" = {
        root = "/srv/images";
        locations = {
          "/fancyindex/".alias = (toString pkgs.fancyIndexTheme) + "/";

          "/".extraConfig = ''
            include ${pkgs.fancyIndexTheme}/fancyindex.conf;
          '';
        };
      };
    };
  };

  system.stateVersion = "22.05";
}
