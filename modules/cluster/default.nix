{ config, lib, confLib, ... }@args:
with lib;
let
  topLevelConfig = config;

  machine =
    { config, ... }:
    {
      options = {
        services = mkOption {
          type = types.attrsOf (types.submodule service);
          default = {};
          description = ''
            Services published by this machine
          '';
          apply = mapAttrs (name: sv:
            let
              def = topLevelConfig.serviceDefinitions.${name};
            in {
              address = if isNull sv.address then config.addresses.primary.address else sv.address;
              port = if isNull sv.port then def.port else sv.port;
              monitor = if isNull sv.monitor then def.monitor else sv.monitor;
            });
        };
      };
    };

  service =
    { config, ... }:
    {
      options = {
        address = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Address that other machines can access the service on
          '';
        };

        port = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Port the service listens on
          '';
        };

        monitor = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            What kind of monitoring this services needs
          '';
        };
      };
    };

in {
  imports = [
    ../services/definitions.nix
  ];

  options = {
    cluster = mkOption {
      type = types.attrsOf (types.submodule machine);
    };
  };
}
