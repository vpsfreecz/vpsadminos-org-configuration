# Operations and schema upgrades: docs/operations/image-repository.md
{
  config,
  lib,
  pkgs,
  confLib,
  ...
}:
let
  cfg = config.services.osctl-repo-server-site;
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };
  roles = [
    "producer"
    "publisher"
    "admin"
  ];
  socket = role: "/run/osctl-repo-server/${role}.sock";
  roleName = role: "repo-${role}";
  forceCommand =
    role:
    pkgs.writeShellScript "repo-${role}-ssh" ''
      exec ${cfg.package}/bin/osctl-repo-server ctl --socket ${lib.escapeShellArg (socket role)}
    '';
  keys = role: map (key: ''restrict,command="${forceCommand role}" ${key}'') cfg.sshKeys.${role};
  allKeys = lib.concatMap (role: cfg.sshKeys.${role}) roles;
  keyIDs = map (key: lib.concatStringsSep " " (lib.take 2 (lib.splitString " " key))) allKeys;
  positive =
    description:
    lib.mkOption {
      type = lib.types.ints.positive;
      inherit description;
    };
  duration =
    description:
    lib.mkOption {
      type = lib.types.strMatching "[1-9][0-9]*(s|m|h)";
      inherit description;
    };
  args = [
    "serve"
    "--root"
    cfg.stateDirectory
    "--listen"
    "127.0.0.1:${toString cfg.port}"
    "--repository"
    cfg.repository
    "--instance"
    cfg.instance
    "--producer-socket"
    (socket "producer")
    "--publisher-socket"
    (socket "publisher")
    "--admin-socket"
    (socket "admin")
    "--producer-group"
    (roleName "producer")
    "--publisher-group"
    (roleName "publisher")
    "--admin-group"
    (roleName "admin")
    "--max-bytes"
    (toString cfg.limits.maxBytes)
    "--reserve-bytes"
    (toString cfg.limits.reserveBytes)
    "--max-upload-bytes"
    (toString cfg.limits.maxUploadBytes)
    "--max-runs"
    (toString cfg.limits.maxRuns)
    "--max-lease"
    cfg.limits.maxLease
    "--export-lease"
    cfg.limits.exportLease
    "--trusted-proxy"
    "127.0.0.1/32"
    "--client-ip-header"
    "X-Repo-Client-IP"
    "--access-log"
    "/var/log/osctl-repo-server/access.jsonl"
    "--access-log-max-bytes"
    (toString cfg.logs.maxBytes)
    "--access-log-files"
    (toString cfg.logs.files)
    "--stats-days"
    (toString cfg.logs.statisticsDays)
    "--stats-max-rows"
    (toString cfg.logs.statisticsMaxRows)
    "--event-queue"
    (toString cfg.logs.queueSize)
  ];
in
{
  options.services.osctl-repo-server-site = {
    enable = lib.mkEnableOption "the image repository service";
    publicServing = lib.mkEnableOption "public serving after coherent catalog adoption";
    package = lib.mkOption {
      type = lib.types.package;
      description = "Reviewed osctl-repo-server package from the selected vpsAdminOS input.";
    };
    repository = lib.mkOption { type = lib.types.strMatching "[A-Za-z0-9_-]+"; };
    instance = lib.mkOption { type = lib.types.strMatching "[A-Za-z0-9_.-]+"; };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    stateDirectory = lib.mkOption {
      type = lib.types.strMatching "/.*";
      default = "/var/lib/osctl-repo-server";
    };
    adoptedDirectory = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "/.+");
      default = null;
      description = "Existing image root made writable only after exclusive coherent adoption.";
    };
    sshKeys = lib.genAttrs roles (
      role:
      lib.mkOption {
        type = lib.types.listOf (
          lib.types.strMatching "(ssh-ed25519|ssh-rsa|ecdsa-sha2-[^ ]+|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) [A-Za-z0-9+/=]+( .*)?"
        );
        default = [ ];
        description = "Deployment-supplied public keys for the restricted ${role} role.";
      }
    );
    limits = {
      maxBytes = positive "Maximum accounted image bytes.";
      reserveBytes = positive "Filesystem bytes reserved for public serving and recovery.";
      maxUploadBytes = positive "Maximum bytes in one uploaded file.";
      maxRuns = positive "Maximum retained runs.";
      maxLease = duration "Maximum run lease, such as a number of hours.";
      exportLease = duration "Bounded portable-export transfer lease.";
    };
    logs = {
      maxBytes = positive "Maximum bytes per private JSON Lines file.";
      files = positive "Total retained access files, including the active file.";
      statisticsDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 365;
        description = "UTC days retained in aggregate statistics. Shorter history remains an explicit operator choice.";
      };
      statisticsMaxRows = positive "Maximum aggregate rows per repository and instance.";
      queueSize = positive "Maximum queued request events before dropping measurements.";
    };
    maintenance = {
      onCalendar = lib.mkOption {
        type = lib.types.strMatching ".+";
        default = "*:0/15";
        description = "Calendar schedule for staging expiry and reclamation.";
      };
      timeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Maximum seconds allowed for one expiry/reclamation invocation.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (role: cfg.sshKeys.${role} != [ ]) roles;
        message = "Image repository activation requires separate producer, publisher and administrator public keys.";
      }
      {
        assertion = cfg.limits.maxUploadBytes <= cfg.limits.maxBytes;
        message = "Image upload limit must fit the image byte budget.";
      }
      {
        assertion =
          lib.length (lib.unique keyIDs) == lib.length keyIDs
          && lib.all (key: !(lib.hasInfix "\n" key || lib.hasInfix "\r" key)) allKeys;
        message = "Repository SSH roles require distinct single-line public keys.";
      }
      {
        assertion = cfg.stateDirectory != "/";
        message = "The repository state directory must be a dedicated directory.";
      }
    ];
    users.groups = {
      repo-server = { };
      repo-maintenance = { };
    }
    // lib.genAttrs (map roleName roles) (_: { });
    users.users = {
      repo-server = {
        isSystemUser = true;
        group = "repo-server";
        extraGroups = map roleName roles;
      };
      repo-maintenance = {
        isSystemUser = true;
        group = "repo-maintenance";
        extraGroups = [ "repo-admin" ];
      };
    }
    // lib.listToAttrs (
      map (
        role:
        lib.nameValuePair (roleName role) {
          isSystemUser = true;
          group = roleName role;
          home = "/var/empty";
          shell = pkgs.bash;
          openssh.authorizedKeys.keys = keys role;
        }
      ) roles
    );
    systemd.services.osctl-repo-server = {
      description = "Container image repository";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        User = "repo-server";
        Group = "repo-server";
        SupplementaryGroups = map roleName roles;
        ExecStart = "${cfg.package}/bin/osctl-repo-server ${lib.escapeShellArgs args}";
        RuntimeDirectory = "osctl-repo-server";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "osctl-repo-server";
        StateDirectoryMode = "0700";
        LogsDirectory = "osctl-repo-server";
        LogsDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 45;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.stateDirectory
        ]
        ++ lib.optional (cfg.adoptedDirectory != null) cfg.adoptedDirectory;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
    systemd.services.osctl-repo-server-maintenance = {
      description = "Expire staging runs and reclaim unreferenced image files";
      after = [ "osctl-repo-server.service" ];
      unitConfig = {
        Requisite = "osctl-repo-server.service";
        ConditionPathIsSocket = socket "admin";
      };
      script = ''
        set -euo pipefail
        request() {
          local operation="$1"
          local request_id
          request_id="$(${pkgs.util-linux}/bin/uuidgen)"
          ${pkgs.jq}/bin/jq -cn \
            --arg request_id "$request_id" \
            --arg operation "$operation" \
            --arg repository ${lib.escapeShellArg cfg.repository} \
            '{request_id: $request_id, operation: $operation, repository: $repository, params: {}}' \
            | ${cfg.package}/bin/osctl-repo-server ctl --socket ${lib.escapeShellArg (socket "admin")} \
            | ${pkgs.jq}/bin/jq -e '.ok == true' > /dev/null
        }
        request expire
        request reclaim
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "repo-maintenance";
        Group = "repo-maintenance";
        SupplementaryGroups = [ "repo-admin" ];
        TimeoutStartSec = cfg.maintenance.timeoutSeconds;
        TimeoutStopSec = 10;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };
    systemd.timers.osctl-repo-server-maintenance = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.maintenance.onCalendar;
        Persistent = true;
        Unit = "osctl-repo-server-maintenance.service";
      };
    };
    systemd.tmpfiles.rules = [ "d ${cfg.stateDirectory} 0700 repo-server repo-server -" ];
    services.nginx = {
      appendHttpConfig = ''
        map $remote_addr $repo_client_ip {
          default $remote_addr;
          ${proxy.addresses.primary.address} $http_x_repo_client_ip;
        }
      '';
      virtualHosts."images.vpsadminos.org".locations = {
        "/runs/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header X-Repo-Client-IP $repo_client_ip;
            proxy_buffering off;
          '';
        };
        "/" = lib.mkIf cfg.publicServing {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header X-Repo-Client-IP $repo_client_ip;
            proxy_buffering off;
          '';
        };
      };
    };
  };
}
