{ config, ... }:
{
  cluster."org.vpsadminos/int.gh-runner1" = rec {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "gh-runner1";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.21";
      prefix = 32;
    };
    services = {
      nix-serve = { };
      node-exporter = { };
    };
    tags = [
      "target"
      "gh-runner"
    ];
  };
}
