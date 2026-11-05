{ ... }:
{
  services.nginx.virtualHosts."images.vpsadminos.org".locations."/".extraConfig = ''
    # Replace caller-supplied attribution at the public HTTPS edge.
    proxy_set_header X-Repo-Client-IP $remote_addr;
    proxy_buffering off;
  '';
}
