{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
let
  cache = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.cache";
  };

  dockerRegistry = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.docker-registry";
  };

  ghRunner1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.gh-runner1";
  };

  ghRunner2 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.gh-runner2";
  };

  images = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.images";
  };

  iso = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.iso";
  };

  www = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/int.www";
  };

  dockerRegistryAllowedCidrs = [
    "${ghRunner1.addresses.primary.address}/32"
    "${ghRunner2.addresses.primary.address}/32"

    # aitherdev and other dev machines
    "172.16.106.0/24"
  ];

  dockerRegistryAllowConfig = lib.concatStringsSep "\n" (
    map (cidr: "allow ${cidr};") dockerRegistryAllowedCidrs
  );
in
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [
      80
      443 # nginx
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
        locations."/".proxyPass =
          "http://${www.services.nginx.address}:${toString www.services.nginx.port}";
      };

      "images.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass =
          "http://${images.services.nginx.address}:${toString images.services.nginx.port}";
      };

      "iso.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass =
          "http://${iso.services.nginx.address}:${toString iso.services.nginx.port}";
      };

      "cache.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${cache.services.nix-serve.address}:${toString cache.services.nix-serve.port}";
          extraConfig = ''
            proxy_intercept_errors on;
            error_page 502 503 504 =404 /404.html;
          '';
        };
        locations."/404.html" = {
          return = "404 'File not found.'";
          extraConfig = ''
            internal;
          '';
        };
      };

      "docker-registry.vpsadminos.org" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${dockerRegistry.services.docker-registry.address}:${toString dockerRegistry.services.docker-registry.port}";
          extraConfig = ''
            ${dockerRegistryAllowConfig}
            deny all;
          '';
        };
      };

      "check-online.vpsadminos.org" = {
        enableACME = true;
        addSSL = true;
        root = pkgs.runCommand "check-online" { } ''
          mkdir $out
          echo online > $out/index.html
        '';
      };
    };
  };

  system.stateVersion = "22.05";
}
