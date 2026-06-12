{
  config,
  pkgs,
  lib,
  inputs,
  flakeInputs,
}:
let
  system = "x86_64-linux";
  nixpkgsPkgs =
    if flakeInputs ? nixpkgs && flakeInputs.nixpkgs ? legacyPackages then
      flakeInputs.nixpkgs.legacyPackages.${system}
    else
      pkgs;

  vpsadminosSystem =
    modules:
    flakeInputs.vpsadminos.lib.vpsadminosSystem {
      inherit system modules;
      pkgs = nixpkgsPkgs;
      specialArgs = {
        inherit inputs flakeInputs;
      };
    };
in
{
  vpsadminos = vpsadminosSystem [
    {
      imports = [
        (inputs.vpsadminos + "/os/configs/iso.nix")
      ];

      system.secretsDir = null;
    }
  ];
}
