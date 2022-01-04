{ config, pkgs, lib, confLib, ... }:
let
  cache = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.cache";
  };

  images = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.images";
  };

  iso = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.iso";
  };

  www = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/int.www";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      80 443 # nginx
    ];
  };

  environment.systemPackages = with pkgs; [
    apacheHttpd # for htpasswd
  ];

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "vpsadminos.org" = {
        serverAliases = [
          "www.vpsadminos.org"
          "ref.vpsadminos.org"
          "man.vpsadminos.org"
        ];
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${www.services.nginx.address}:${toString www.services.nginx.port}";
      };

      "images.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${images.services.nginx.address}:${toString images.services.nginx.port}";
      };

      "iso.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${iso.services.nginx.address}:${toString iso.services.nginx.port}";
      };

      "cache.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://${cache.services.nix-serve.address}:${toString cache.services.nix-serve.port}";
      };
    };
  };
}
