{
  config,
  pkgs,
  lib,
  confLib,
  ...
}:
let
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };

  pushCiProfile = pkgs.writeScriptBin "push-ci-generation" ''
    #!${pkgs.bash}/bin/bash

    if [ $# != 2 ] ; then
      echo "Usage: $0 <branch> <store path>"
      exit 1
    fi

    branch="$(basename $1)"
    path="$2"

    nix-env -p /nix/var/nix/profiles/ci-"$branch"-profile --set "$path"
    exit $?
  '';
in
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport ${toString config.services.nix-serve.port} -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  environment.systemPackages = [
    pushCiProfile
  ];

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/private/nix-serve/cache-priv-key.pem";
    port = config.serviceDefinitions.nix-serve.port;
  };

  # Workaround for nix-serve error saying:
  # nix-serve-start[415]: cannot determine user's home directory at ...
  systemd.services.nix-serve.environment.HOME = "/var/empty";

  users.users.push = {
    isSystemUser = true;
    group = "push";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHA0ZO7G+prBuHdY0Az5/dQJB71HrZtpKktxH8Q1g9uo root@gh-runner"
    ];
  };

  users.groups.push = { };

  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ "push" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/push-ci-generation";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  nix.settings.trusted-users = [
    "root"
    "push"
  ];

  systemd.services.ci-gc = {
    path = with pkgs; [
      nix
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeScript "ci-gc" ''
        #!${pkgs.ruby}/bin/ruby

        profile_dir = '/nix/var/nix/profiles'
        regexps = [
          /\Aci-(.+)-profile\z/
        ]
        profiles = {}

        # Find existing profiles
        Dir.entries(profile_dir).each do |v|
          next if %w[. ..].include?(v) || regexps.detect { |rx| rx =~ v }.nil?

          name = ::Regexp.last_match(1)
          days =
            if name == 'staging' || name.start_with?('staging-kernel-')
              365
            else
              90
            end

          profiles[v] = days
        end

        # Delete old generations
        profiles.each do |profile, days|
          puts "Deleting old generations of profile #{profile} (#{days} days)"

          unless Kernel.system('nix-env', '-p', File.join(profile_dir, profile), '--delete-generations', "#{days}d")
            raise "Failed to delete generations of profile #{profile}"
          end
        end

        # Delete old profiles
        now = Time.now

        profiles.each do |profile, days|
          path = File.join(profile_dir, profile)
          generations = `nix-env -p #{path} --list-generations`.strip.split("\n")

          next if generations.length > 1 || (File.lstat(path).mtime + days * 24 * 60 * 60) > now

          puts "Deleting profile #{profile}"

          generations.each do |gen|
            n, = gen.split

            # nix-env refuses to delete the current generation, so we delete them manually
            File.unlink(File.join(profile_dir, "#{profile}-#{n}-link"))
          end

          File.unlink(path)
        end

        # Collect garbage
        unless Kernel.system('nix-collect-garbage')
          raise 'Failed to collect garbage'
        end
      '';
    };
    startAt = "daily";
  };

  system.stateVersion = "22.05";
}
