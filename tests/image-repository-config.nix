let
  flake = builtins.getFlake (toString ../.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  evaluate =
    extra:
    import (nixpkgs + "/nixos/lib/eval-config.nix") {
      system = builtins.currentSystem;
      specialArgs.confLib.findMetaConfig = _: {
        addresses.primary.address = "192.0.2.1";
      };
      modules = [
        ../modules/services/osctl-repo-server.nix
        {
          system.stateVersion = "26.05";
        }
        extra
      ];
    };
  disabled = evaluate { };
  settings = {
    services.osctl-repo-server-site = {
      enable = true;
      package = pkgs.hello;
      repository = "fixture";
      instance = "fixture-instance";
      # Synthetic public-key strings, used only to inspect generated options.
      sshKeys = {
        producer = [ "ssh-ed25519 cHJvZHVjZXI=" ];
        publisher = [ "ssh-ed25519 cHVibGlzaGVy" ];
        admin = [ "ssh-ed25519 YWRtaW4=" ];
      };
      limits = {
        maxBytes = 1048576;
        reserveBytes = 65536;
        maxUploadBytes = 1024;
        maxRuns = 2;
        maxLease = "1h";
        exportLease = "1m";
      };
      logs = {
        maxBytes = 16384;
        files = 2;
        statisticsMaxRows = 20;
        queueSize = 2;
      };
    };
  };
  shadow = evaluate settings;
  shorter = evaluate (
    pkgs.lib.recursiveUpdate settings {
      services.osctl-repo-server-site.logs.statisticsDays = 2;
    }
  );
  public = evaluate (
    pkgs.lib.recursiveUpdate settings {
      services.osctl-repo-server-site.publicServing = true;
    }
  );
  duplicate = evaluate (
    pkgs.lib.recursiveUpdate settings {
      services.osctl-repo-server-site.sshKeys.publisher =
        settings.services.osctl-repo-server-site.sshKeys.producer;
    }
  );
  service = shadow.config.systemd.services.osctl-repo-server.serviceConfig;
  producerKeys = shadow.config.users.users.repo-producer.openssh.authorizedKeys.keys;
  maintenance = shadow.config.systemd.services.osctl-repo-server-maintenance;
  timer = shadow.config.systemd.timers.osctl-repo-server-maintenance;
in
assert !(builtins.hasAttr "osctl-repo-server" disabled.config.systemd.services);
assert !(builtins.hasAttr "osctl-repo-server-maintenance" disabled.config.systemd.timers);
assert service.User == "repo-server";
assert service.RuntimeDirectoryMode == "0755";
assert service.LogsDirectoryMode == "0700";
assert pkgs.lib.hasInfix "--producer-group repo-producer" service.ExecStart;
assert pkgs.lib.hasInfix "--trusted-proxy 127.0.0.1/32" service.ExecStart;
assert shadow.config.services.osctl-repo-server-site.logs.statisticsDays == 365;
assert pkgs.lib.hasInfix "--stats-days 365" service.ExecStart;
assert shorter.config.services.osctl-repo-server-site.logs.statisticsDays == 2;
assert pkgs.lib.hasInfix "--stats-days 2"
  shorter.config.systemd.services.osctl-repo-server.serviceConfig.ExecStart;
assert shadow.config.services.osctl-repo-server-site.logs.statisticsMaxRows == 20;
assert shorter.config.services.osctl-repo-server-site.logs.statisticsMaxRows == 20;
assert pkgs.lib.hasPrefix "restrict,command=" (builtins.head producerKeys);
assert shadow.config.users.users.repo-producer.group == "repo-producer";
assert shadow.config.users.users.repo-publisher.group == "repo-publisher";
assert
  !(builtins.hasAttr "/" shadow.config.services.nginx.virtualHosts."images.vpsadminos.org".locations);
assert
  public.config.services.nginx.virtualHosts."images.vpsadminos.org".locations."/".proxyPass
  == "http://127.0.0.1:8080";
assert !(pkgs.lib.all (a: a.assertion) duplicate.config.assertions);
assert maintenance.serviceConfig.Type == "oneshot";
assert maintenance.serviceConfig.User == "repo-maintenance";
assert maintenance.serviceConfig.SupplementaryGroups == [ "repo-admin" ];
assert shadow.config.users.users.repo-maintenance.extraGroups == [ "repo-admin" ];
assert maintenance.unitConfig.ConditionPathIsSocket == "/run/osctl-repo-server/admin.sock";
assert maintenance.unitConfig.Requisite == "osctl-repo-server.service";
assert maintenance.serviceConfig.TimeoutStartSec == 120;
assert maintenance.serviceConfig.RestrictAddressFamilies == [ "AF_UNIX" ];
assert timer.timerConfig.OnCalendar == "*:0/15";
assert timer.timerConfig.Persistent;
assert timer.timerConfig.Unit == "osctl-repo-server-maintenance.service";
assert pkgs.lib.hasInfix "set -euo pipefail" maintenance.script;
assert pkgs.lib.hasInfix "/bin/uuidgen" maintenance.script;
assert pkgs.lib.hasInfix "request expire\nrequest reclaim" maintenance.script;
assert pkgs.lib.hasInfix "/admin.sock" maintenance.script;
assert pkgs.lib.hasInfix ".ok == true" maintenance.script;
{
  disabledByDefault = true;
  distinctRestrictedRoles = true;
  finiteFixtureLimits = true;
  shadowDoesNotReplacePublicRoute = true;
  publicRouteThroughService = true;
  duplicateKeysRejected = true;
  automaticOrderedMaintenance = true;
  privateBoundedMaintenance = true;
  yearlyStatisticsDefault = true;
  explicitShorterStatisticsRetained = true;
}
