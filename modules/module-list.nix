rec {
  shared = [
    ./cluster
    ./services/definitions.nix
    ./system/monitoring.nix
  ];

  nixos = shared ++ [
    # Modules only for NixOS
  ];

  vpsadminos = shared ++ [
    # Modules only for vpsAdminOS
  ];
}
