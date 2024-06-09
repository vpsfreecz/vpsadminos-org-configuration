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
  confctl.swpins.core.pins = {
    nixpkgs = {
      type = "git-rev";
      git-rev = {
        url = "https://github.com/NixOS/nixpkgs";
        update.ref = "refs/heads/nixos-unstable";
        update.auto = false;
      };
    };
  };

  confctl.swpins.channels = {
    nixos-stable = { nixpkgs = nixpkgsBranch "nixos-24.05"; };

    os-staging = { vpsadminos = vpsadminosBranch "staging"; };

    os-runtime-deps = { vpsadminos-runtime-deps = vpsadminosBranch "osctl-env-exec"; };
  };
}
