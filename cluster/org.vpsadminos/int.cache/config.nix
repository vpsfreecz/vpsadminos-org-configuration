{ config, pkgs, lib, confLib, ... }:
let
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };
in {
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport ${toString config.services.nix-serve.port} -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/private/nix-serve/cache-priv-key.pem";
    port = config.serviceDefinitions.nix-serve.port;
  };

  # Workaround for nix-serve error saying:
  # nix-serve-start[415]: cannot determine user's home directory at ...
  systemd.services.nix-serve.environment.HOME = "/var/empty";

  users.users.push = {
    isSystemUser = true;
    group = "push";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA0ZO7G+prBuHdY0Az5/dQJB71HrZtpKktxH8Q1g9uo root@gh-runner"
    ];
  };

  users.groups.push = {};

  nix.settings.trusted-users = [ "root" "push" ];

  system.stateVersion = "22.05";
}
