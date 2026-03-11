{ config, ... }:
{
  cluster."org.vpsadminos/int.docker-registry" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "docker-registry";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.33";
      prefix = 32;
    };
    services = {
      docker-registry = { };
      node-exporter = { };
    };
    tags = [ "target" ];
  };
}
