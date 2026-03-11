{
  config,
  confLib,
  ...
}:
let
  thisMachine = config.cluster."org.vpsadminos/int.docker-registry";

  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };
in
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow registry access only from the public proxy
    iptables -A nixos-fw -p tcp --dport ${toString config.services.dockerRegistry.port} -s ${proxy.addresses.primary.address} -j nixos-fw-accept
  '';

  services.dockerRegistry = {
    enable = true;
    listenAddress = thisMachine.addresses.primary.address;
    port = config.serviceDefinitions.docker-registry.port;
    storagePath = "/var/lib/docker-registry";
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "daily";

    extraConfig = {
      proxy = {
        remoteurl = "https://registry-1.docker.io";
        ttl = "168h";
      };
    };
  };

  system.stateVersion = "24.11";
}
