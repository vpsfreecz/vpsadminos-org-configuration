{ config, lib, ... }:
with lib;
let
  service =
    { config, ... }:
    {
      options = {
        port = mkOption {
          type = types.int;
          description = ''
            Default port the service listens on
          '';
        };

        monitor = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Default monitoring the service needs
          '';
        };
      };
    };
in {
  options = {
    serviceDefinitions = mkOption {
      type = types.attrsOf (types.submodule service);
      description = ''
        Mapping of services to ports and other options
      '';
    };
  };

  config = {
    serviceDefinitions = {
      buildbot-master.port = 8010;
      nginx.port = 80;
      nix-serve.port = 5000;
      node-exporter.port = 9100;
    };
  };
}
