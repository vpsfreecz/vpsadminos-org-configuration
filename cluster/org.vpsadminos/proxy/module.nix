{ config, ... }:
{
  cluster."org.vpsadminos/proxy" = rec {
    spin = "nixos";
    swpins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    host = {
      name = "proxy";
      domain = "vpsadminos.org";
    };
    addresses = {
      v4 = [
        {
          address = "37.205.14.58";
          prefix = 32;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:fe:48::1";
          prefix = 64;
        }
      ];
    };
    services.node-exporter = { };
    tags = [ "target" ];
  };
}
