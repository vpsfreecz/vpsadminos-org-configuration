{ config, pkgs, lib, confDir, confLib, confData, ... }:
with lib;
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };

  images = import ../../../lib/images.nix { inherit config lib pkgs; };

  httpRoot = "/var/lib/vpsadminos-iso";

  sha256 = name: isoBuild: pkgs.runCommand "${name}-sha256" {} ''
    sha256sum ${isoBuild}/iso/vpsadminos.iso > $out
  '';

  addIso = name: osBuild: ''
    arch="${osBuild.config.nixpkgs.localSystem.system}"
    name="vpsadminos-${osBuild.config.system.osLabel}-$arch.iso"
    srciso="${osBuild.config.system.build.isoImage}/iso/vpsadminos.iso"
    dstiso="${httpRoot}/$name"
    dstsum="''${dstiso}.sha256"

    [ ! -f "$dstiso" ] \
      && cp "$srciso" "$dstiso"

    [ ! -f "$dstsum" ] \
      && cp "${sha256 name osBuild.config.system.build.isoImage}" "$dstsum"

    ln -sf "$name" "${httpRoot}/vpsadminos-latest-$arch.iso"
    ln -sf "''${name}.sha256" "${httpRoot}/vpsadminos-latest-$arch.iso.sha256"
  '';

  #deployIsoImages = pkgs.runCommand "deploy-vpsadminos-iso" {} ''
  deployIsoImages = pkgs.writeScript "deploy-vpsadminos-iso" ''
    #!${pkgs.bash}/bin/bash

    mkdir -p "${httpRoot}"

    ${concatStringsSep "\n\n" (mapAttrsToList addIso images)}
  '';
in {
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
      "iso.vpsadminos.org" = {
        root = httpRoot;
        locations = {
          "/fancyindex/".alias = (toString pkgs.fancyIndexTheme) + "/";

          "/".extraConfig = ''
            include ${pkgs.fancyIndexTheme}/fancyindex.conf;
          '';
        };
      };
    };
  };

  systemd.services.deploy-vpsadminos-iso = {
    description = "Deploys vpsAdminOS ISO to the web server root";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = deployIsoImages;
    };
  };

  system.stateVersion = "22.05";
}
