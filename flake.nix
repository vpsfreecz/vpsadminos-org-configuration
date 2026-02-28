{
  description = "confctl cluster configuration for vpsadminos.org";

  inputs = {
    confctl.url = "github:vpsfreecz/confctl";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    vpsadminos = {
      url = "github:vpsfreecz/vpsadminos/staging";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, confctl, ... }:
    let
      channels = {
        "nixos-stable" = {
          nixpkgs = "nixpkgs";
        };

        "os-staging" = {
          vpsadminos = "vpsadminos";
        };
      };
    in
    {
      confctl = confctl.lib.mkConfctlOutputs {
        confDir = ./.;
        inherit inputs channels;
      };

      devShells.x86_64-linux.default = confctl.lib.mkDevShell { system = "x86_64-linux"; };
    };
}
