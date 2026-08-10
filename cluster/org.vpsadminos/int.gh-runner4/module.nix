{ config, ... }:
{
  cluster."org.vpsadminos/int.gh-runner4" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "gh-runner4";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.31";
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
