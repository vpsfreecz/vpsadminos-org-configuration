{ config, ... }:
{
  cluster."org.vpsadminos/int.www" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" "os-runtime-deps" ];
    host = { name = "www"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.17"; prefix = 32; };
    services = {
      nginx = {};
      node-exporter = {};
    };
    tags = [ "target" ];
  };
}
