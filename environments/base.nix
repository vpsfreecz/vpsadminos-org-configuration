{
  config,
  pkgs,
  lib,
  confData,
  inputs,
  ...
}:
with lib;
{
  time.timeZone = "Europe/Amsterdam";

  networking = {
    search = [
      "vpsfree.cz"
      "prg.vpsfree.cz"
      "base48.cz"
    ];
    nameservers = [
      "172.16.9.90"
      "1.1.1.1"
    ];
  };

  services.openssh.enable = true;

  nixpkgs.overlays = import ../overlays;

  nix.settings = {
    sandbox = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
  ]
  ++ (optional (hasAttr "vpsadminos" inputs) "vpsadminos=${inputs.vpsadminos}");

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
  ];

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; admins ++ builders;
}
