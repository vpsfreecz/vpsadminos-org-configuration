{ config, ... }:
{
  cluster."org.vpsadminos/int.builder" = rec {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "builder";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.14";
      prefix = 32;
    };
    services.node-exporter = { };
  };
}
