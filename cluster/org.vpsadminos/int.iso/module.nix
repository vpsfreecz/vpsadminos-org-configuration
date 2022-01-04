{ config, ... }:
{
  cluster."org.vpsadminos/int.iso" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    host = { name = "iso"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.16"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
    tags = [ "target" ];
  };
}
