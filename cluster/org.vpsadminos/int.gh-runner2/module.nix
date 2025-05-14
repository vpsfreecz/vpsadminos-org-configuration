{ config, ... }:
{
  cluster."org.vpsadminos/int.gh-runner2" = rec {
    spin = "nixos";
    swpins.channels = [ "nixos-stable" "os-staging" ];
    host = { name = "gh-runner2"; domain = "int.vpsadminos.org"; };
    addresses.primary = { address = "172.16.4.22"; prefix = 32; };
    services = {
      nix-serve = {};
      node-exporter = {};
    };
    tags = [ "target" "gh-runner" ];
  };
}
