{ config, ... }:
{
  cluster."org.vpsadminos/int.gh-runner3" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "gh-runner3";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.25";
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
