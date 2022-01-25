{ config, pkgs, lib, ... }:
{
  services.nginx.package = pkgs.nginx.override {
    modules = with pkgs.nginxModules; [ fancyindex ];
  };
}
