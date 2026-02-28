{
  config,
  pkgs,
  lib,
  confLib,
  inputs,
  ...
}:
with lib;
let
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/proxy";
  };

  docsOs = inputs.vpsadminos;

  docsPkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [
      (import ("${docsOs}/os/overlays/osctl.nix"))
      (import ("${docsOs}/os/overlays/ruby.nix"))
    ];
  };

  trackingCode = pkgs.writeText "vpsfree-matomo.js" ''
    var _paq = window._paq || [];
    /* tracker methods like "setCustomDimension" should be called before "trackPageView" */
    _paq.push(['trackPageView']);
    _paq.push(['enableLinkTracking']);
    (function() {
      var u="https://piwik.vpsfree.cz/";
      _paq.push(['setTrackerUrl', u+'matomo.php']);
      _paq.push(['setSiteId', '8']);
      var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
      g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
    })();
  '';

  docsSource = pkgs.runCommand "os-docs-src" { } ''
    mkdir -p $out
    cp -r ${inputs.vpsadminos}/docs/. $out/
    mkdir -p $out/js
    ln -s ${trackingCode} $out/js/vpsfree-matomo.js
  '';

  configOverride = pkgs.writeText "mkdocs-override.yml" (
    builtins.toJSON {
      docs_dir = docsSource;
      extra_javascript = [ "js/vpsfree-matomo.js" ];
    }
  );

  mkdocsConfig =
    pkgs.runCommand "mkdocs-merged.yml"
      {
        buildInputs = [ docsPkgs.yaml-merge ];
      }
      ''
        yaml-merge ${inputs.vpsadminos}/mkdocs.yml ${configOverride} > $out
      '';

  docs = pkgs.runCommand "docsroot" { buildInputs = [ docsPkgs.mkdocs ]; } ''
    mkdir -p $out
    pushd ${inputs.vpsadminos}
    mkdocs build --config-file ${mkdocsConfig} --site-dir $out
    popd
  '';

  md2manRakefile = pkgs.writeText "vpsadminos-md2man.rakefile" ''
    require 'md2man/rakefile'
    require 'md2man/roff/engine'
    require 'md2man/html/engine'

    # Override markdown engine to add extra parameter
    [Md2Man::Roff, Md2Man::HTML].each do |mod|
      mod.send(:remove_const, :ENGINE)
      mod.send(:const_set, :ENGINE, Redcarpet::Markdown.new(mod.const_get(:Engine),
        tables: true,
        autolink: true,
        superscript: true,
        strikethrough: true,
        no_intra_emphasis: false,
        fenced_code_blocks: true,

        # This option is needed for command options to be rendered property
        disable_indented_code_blocks: true,
      ))
    end
  '';

  manPaths = [
    "${inputs.vpsadminos}/osctl/man"
    "${inputs.vpsadminos}/osctl-exportfs/man"
    "${inputs.vpsadminos}/osctl-image/man"
    "${inputs.vpsadminos}/osctl-repo/man"
    "${inputs.vpsadminos}/converter/man"
    "${inputs.vpsadminos}/osup/man"
    "${inputs.vpsadminos}/svctl/man"
    "${inputs.vpsadminos}/osvm/man"
    "${inputs.vpsadminos}/test-runner/man"
  ];

  buildMan =
    pkgs.runCommand "vpsadminos-webmanuals"
      {
        buildInputs = [
          docsPkgs.osctl-env-exec
          pkgs.git
        ];
      }
      ''
        # Necessary for unicode characters in manpages
        export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
        export LANG="en_US.UTF-8"

        mkdir $out
        ln -s ${md2manRakefile} $out/Rakefile

        mkdir $out/man

        for manPath in ${concatStringsSep " " manPaths} ; do
          cp -r $manPath/* $out/man/

          # Since we're copying from Nix store, the copied files are all read-only,
          # but we need write access.
          chmod -R +w $out/man
        done

        # md2man copies style.css from its gemdir in Nix store to man/style.css
        # and later tries to open it and write to it. That doesn't work, because
        # the copied file is read-only. So we create an empty man/style.css to avoid
        # md2man touching it and after the manpages are generated, we copy it
        # in place ourselves.
        touch $out/man/style.css

        cd $out
        osctl-env-exec rake md2man:web

        rm -f $out/man/style.css
        mv $out/man/* $out/
        cp $(osctl-env-exec 'bash -c "echo $GEM_HOME"')/gems/md2man-*/lib/md2man/rakefile/style.css $out/style.css

        rmdir $out/man
        rm -f $out/Rakefile
      '';

  refGems =
    pkgs.runCommand "ref-gems"
      {
        buildInputs = [
          docsPkgs.osctl-env-exec
          pkgs.git
        ];
      }
      ''
        cp -R ${inputs.vpsadminos} vpsadminos
        chmod -R +w vpsadminos
        mkdir $out
        pushd vpsadminos
          for gem in libosctl osctl osctl-exportfs osctl-image osctl-repo osctld converter osup svctl osvm test-runner; do
            pushd $gem
              mkdir -p $out/$gem
              YARD_OUTPUT=$out/$gem osctl-env-exec rake yard
              test -f $out/$gem/index.html || (echo "gem $gem didn't produce index.html" && exit 1);
            popd
          done
        popd
      '';

  # osManual = import "${inputs.vpsadminos}/os/manual" { inherit pkgs; };

  # refOs = pkgs.runCommand "ref-os" {} ''
  #  mkdir $out
  #  ln -s ${osManual.html}/share/doc/vpsadminos $out/os
  # '';

  ref = pkgs.buildEnv {
    name = "refroot";
    paths = [
      refGems
      # refOs
    ];
  };
in
{
  imports = [
    ../../../environments/base.nix
    ../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport 80 -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nginx = {
    enable = true;

    appendConfig = ''
      worker_processes auto;
    '';

    virtualHosts = {
      "www.vpsadminos.org" = {
        root = docs;
        default = true;
      };

      "man.vpsadminos.org" = {
        root = buildMan;
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };

      "ref.vpsadminos.org" = {
        root = ref;
        locations = {
          "/" = {
            extraConfig = "autoindex on;";
          };
        };
      };
    };
  };

  system.stateVersion = "22.05";
}
