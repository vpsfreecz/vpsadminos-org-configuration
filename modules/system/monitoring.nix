{ lib, config, pkgs, confMachine, confLib, ... }:
with lib;
let
  cfg = config.system.monitoring;

  exporterPort = confMachine.services.node-exporter.port;
in {
  options = {
    system.monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Monitor this system";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = ''
      # Allow access to node-exporter from mon1.int.prg.vpsfree.cz
      iptables -A nixos-fw -p tcp -m tcp -s 172.16.4.10 --dport ${toString exporterPort} -j nixos-fw-accept
    '';

    services.prometheus.exporters = {
      node = {
        enable = true;
        port = exporterPort;
        extraFlags = [ "--collector.textfile.directory=/run/metrics" ];
        enabledCollectors = [
          "vmstat"
          "interrupts"
          "textfile"
          "processes"
        ] ++ (optionals (confMachine.spin == "nixos") [ "systemd" "logind" ]);
      };
    };
  };
}
