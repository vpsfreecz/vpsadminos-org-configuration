{ config, ... }:
{
  cluster."org.vpsadminos/int.cache" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    host = { name = "cache"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.30"; prefix = 32; };
    services = {
      nix-serve = {};
      node-exporter = {};
    };
  };
}
