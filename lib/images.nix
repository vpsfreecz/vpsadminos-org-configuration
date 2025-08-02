{
  config,
  pkgs,
  lib,
}:
with lib;
let
  # allows to build vpsadminos with specific
  vpsadminosCustom =
    {
      modules ? [ ],
      vpsadminos,
      nixpkgs,
      vpsadmin,
    }:
    let
      # this is fed into scopedImport so vpsadminos sees correct <nixpkgs> everywhere
      overrides = {
        __nixPath =
          [
            {
              prefix = "nixpkgs";
              path = nixpkgs;
            }
            {
              prefix = "vpsadminos";
              path = vpsadminos;
            }
          ]
          ++ (optional (!isNull vpsadmin) {
            prefix = "vpsadmin";
            path = vpsadmin;
          })
          ++ builtins.nixPath;
        import = fn: scopedImport overrides fn;
        scopedImport = attrs: fn: scopedImport (overrides // attrs) fn;
        builtins = builtins // overrides;
      };
    in
    builtins.scopedImport overrides (vpsadminos + "/os/") {
      pkgs = nixpkgs;
      system = "x86_64-linux";
      configuration = { };
      modules = modules;
    };

  vpsadminos =
    {
      modules ? [ ],
      ...
    }@args:
    vpsadminosCustom {
      inherit modules;
      vpsadminos = args.vpsadminos or <vpsadminos>;
      nixpkgs = args.nixpkgs or <nixpkgs>;
      vpsadmin = args.vpsadmin or null;
    };

in
{
  vpsadminos = vpsadminos {
    modules = [
      {
        imports = [
          <vpsadminos/os/configs/iso.nix>
        ];

        system.secretsDir = null;
      }
    ];
  };
}
