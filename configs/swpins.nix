{ config, ... }:
let
  nixpkgsBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/NixOS/nixpkgs";
      update.ref = "refs/heads/${branch}";
    };
  };

  vpsadminosBranch = branch: {
    type = "git-rev";

    git-rev = {
      url = "https://github.com/vpsfreecz/vpsadminos";
      update.ref = "refs/heads/${branch}";
    };
  };
in {
  confctl.swpins.channels = {
    nixos-stable = { nixpkgs = nixpkgsBranch "nixos-22.05"; };

    os-staging = { vpsadminos = vpsadminosBranch "staging"; };

    os-runtime-deps = { vpsadminos-runtime-deps = vpsadminosBranch "osctl-env-exec"; };
  };
}
