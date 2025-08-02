{
  lib,
  config,
  pkgs,
  confMachine,
  confLib,
  ...
}:
with lib;
let
  cfg = config.system.monitoring;

  exporterPort = confMachine.services.node-exporter.port;
in
{
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

      # Allow access to node-exporter from mon2.int.prg.vpsfree.cz
      iptables -A nixos-fw -p tcp -m tcp -s 172.16.4.18 --dport ${toString exporterPort} -j nixos-fw-accept
    '';

    services.prometheus.exporters = {
      node = {
        enable = true;
        port = exporterPort;
        extraFlags = [
          "--collector.disable-defaults"
          "--collector.filesystem"
          "--collector.loadavg"
          "--collector.meminfo"
          "--collector.os"
          "--collector.systemd"
          "--collector.logind"
          "--collector.uname"
          "--collector.textfile"
          "--collector.textfile.directory=/run/metrics"
        ];
      };
    };

    # The node_exporter module sets this only when systemd is in enabledCollectors.
    # Since we're configuring the collectors manually to reduce node_exporter's
    # footprint, the condition does not match and the collector does not have
    # access to systemd's dbus socket.
    systemd.services.prometheus-node-exporter.serviceConfig.RestrictAddressFamilies = [ "AF_UNIX" ];
  };
}
