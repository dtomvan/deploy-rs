{
  pkgs,
  deploy-rs,
}:
let
  inherit (builtins)
    concatLists
    isInt
    ;

  inherit (pkgs.lib)
    getExe
    getExe'
    mapAttrsToList
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
        (pkgs.writeShellScript "deploy-rs-activate" ''
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
        '')
        (pkgs.writeShellScript "activate-rs" ''
          exec ${getExe' deploy-rs "activate"} "$@"
        '')
      ];
      passthru = { inherit base; };
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

  activate.profile =
    {
      base,
      profileName,
      priority ? null,
    }:
    assert priority == null || isInt priority;
    activate.custom {
      inherit base;
      activate =
        # bash
        ''
          declare -a nixFlags=(--extra-experimental-features "nix-command flakes")

          if nix "''${nixFlags[@]}" profile list --json | ${getExe pkgs.jq} -e '.elements["${profileName}"]' >/dev/null; then
            echo removing existing ${profileName}... >&2
            set -x
            nix "''${nixFlags[@]}" profile remove "${profileName}"
            set +x
          fi

          echo installing new ${profileName}... >&2
          declare -a extraArgs=()
          ${optionalString (priority != null) ''
            extraArgs+=(--priority "${toString priority}")
          ''}
          set -x
          nix "''${nixFlags[@]}" profile install "${base}" "''${extraArgs[@]}"
          set +x

          echo "done"
        '';

      dryActivate = ''
        echo nix profile install "${base}" --priority ${toString priority} >&2
      '';

      boot = ''
        echo WARNING: adding profiles \"on boot\" is a no-op
      '';
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
          profiles =
            deploy.nodes
            |> mapAttrsToList (
              node_name: as:
              as.profiles
              |> mapAttrsToList (profile_name: profile: "${node_name}.${profile_name}:${profile.path}")
            )
            |> concatLists;
        }
        ''
          for x in "''${profiles[@]}"; do
            IFS=":" read -r node_path profile_path <<< "$x"

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
