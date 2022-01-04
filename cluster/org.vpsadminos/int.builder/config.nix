{ config, pkgs, lib, confLib, ... }:
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];
  
  environment.systemPackages = with pkgs; [
    git
  ];
}
