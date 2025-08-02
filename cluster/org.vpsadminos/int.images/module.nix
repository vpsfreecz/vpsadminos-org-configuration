{ config, ... }:
{
  cluster."org.vpsadminos/int.images" = rec {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "images";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.15";
      prefix = 32;
    };
    services = {
      nginx = { };
      node-exporter = { };
    };
    tags = [ "target" ];
  };
}
