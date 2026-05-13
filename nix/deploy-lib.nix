args@{
  pkgs,
  deploy-rs,
}:
let
  inherit (builtins)
    concatStringsSep
    length
    ;

  inherit (pkgs.lib)
    getExe
    getExe'
    isDerivation
    mapAttrsToListRecursiveCond
    optionalString
    ;

  activate.custom =
    {
      base,
      activate,
      dryActivate ? "echo ${pkgs.writeShellScript "activate" activate}",
      boot ? "echo ${pkgs.writeShellScript "activate" activate}",
    }:
    pkgs.buildEnv {
      name = "activatable-" + base.name;
      paths = [
        base
        (pkgs.writeShellApplication {
          name = "deploy-rs-activate";
          text = ''
            case "''${1:?}" in
              dry-activate)
                ${dryActivate}
                ;;
              boot)
                ${boot}
                ;;
              activate)
                ${activate}
                ;;
            esac
          '';
        })
        (pkgs.writeShellApplication {
          name = "activate-rs";
          text = ''
            exec ${getExe' deploy-rs "activate"} "$@"
          '';
        })
      ];
    };

  activate.nixos =
    {
      base,
    }:
    activate.custom {
      base = base.config.system.build.toplevel;

      activate =
        # bash
        ''
          # work around https://github.com/NixOS/nixpkgs/issues/73404
          pushd /tmp

          "$PROFILE/bin/switch-to-configuration" switch

          # https://github.com/serokell/deploy-rs/issues/31
          ${
            let
              inherit (base.config.boot.loader) systemd-boot efi;
            in
            optionalString systemd-boot.enable "sed -i '/^default /d' ${efi.efiSysMountPoint}/loader/loader.conf"
          }
          popd
        '';

      dryActivate = "\"$PROFILE/bin/switch-to-configuration\" dry-activate";
      boot = "\"$PROFILE/bin/switch-to-configuration\" boot";
    };

  activate.home-manager =
    {
      base,
    }:
    activate.custom {
      base = base.activationPackage;
      activate = "\"$PROFILE/activate\"";
    };

  activate.darwin =
    {
      base,
    }:
    activate.custom {
      base = base.config.system.build.toplevel;
      activate = "HOME=/var/root \"$PROFILE/activate\"";
    };

  activate.noop =
    {
      base,
    }:
    activate.custom {
      inherit base;
      activate = ":";
    };

  deployChecks = deploy: {
    deploy-schema = pkgs.runCommand "jsonschema-deploy-system" { } ''
      ${getExe pkgs.check-jsonschema} \
        --schemafile ${../interface.json} \
        ${pkgs.writers.writeJSON "deploy.json" deploy}
      touch $out
    '';

    deploy-activate =
      pkgs.runCommand "deploy-rs-check-activate"
        {
          __structuredAttrs = true;
          # length 3 here is because the attrpath is: [ node_name, "profiles", profile_name ]
          profiles = mapAttrsToListRecursiveCond (p: as: (length p <= 3) && !(isDerivation as)) (
            profile_path: node_path: "${concatStringsSep ":" profile_path}:${node_path}"
          ) deploy.nodes;
        }
        ''
          for x in "''${profiles[@]}"; do
            IFS=":" read -r profile_path node_path <<< "$x"

            for sc in deploy-rs-activate activate-rs; do
              test -f "$profile_path/$sc" || (echo "#$node_path is missing the $sc activation script" && exit 1);
            done
          done

          touch $out
        '';
  };
in
{
  inherit activate deployChecks;
}
