# SPDX-FileCopyrightText: 2024 Sefa Eyeoglu <contact@scrumplex.net>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, ... }:
let
  inherit (lib)
    filterAttrs
    mkEnableOption
    mkOption
    ;

  inherit (lib.types)
    attrsOf
    bool
    int
    listOf
    nullOr
    package
    str
    submoduleWith
    ;

  genericSettings = {
    options = {
      sshUser = mkOption {
        type = nullOr str;
        default = null;
      };
      user = mkOption {
        type = nullOr str;
        default = null;
      };
      sshOpts = mkOption {
        type = listOf str;
        default = [ ];
      };
      fastConnection = mkOption {
        type = nullOr bool;
        default = null;
      };
      autoRollback = mkOption {
        type = nullOr bool;
        default = null;
      };
      confirmTimeout = mkOption {
        type = nullOr int;
        default = null;
      };
      activationTimeout = mkOption {
        type = nullOr int;
        default = null;
      };
      tempPath = mkOption {
        type = nullOr str;
        default = null;
      };
      magicRollback = mkOption {
        type = nullOr bool;
        default = null;
      };
      sudo = mkOption {
        type = nullOr str;
        default = null;
      };
      remoteBuild = mkOption {
        type = nullOr bool;
        default = null;
      };
      interactiveSudo = mkOption {
        type = nullOr bool;
        default = null;
      };
    };
  };
  profileSettings = {
    options = {
      enable = mkEnableOption "" // {
        default = true;
      };
      path = mkOption {
        type = package;
      };
      profilePath = mkOption {
        type = nullOr str;
        default = null;
      };
    };
  };
  nodeSettings = {
    options = {
      enable = mkEnableOption "" // {
        default = true;
      };
      hostname = mkOption {
        type = str;
      };
      profilesOrder = mkOption {
        type = listOf str;
        default = [ ];
      };
      profiles = mkOption {
        type = attrsOf profileModule;
      };
    };
  };

  nodesSettings = {
    options.nodes = mkOption {
      type = attrsOf nodeModule;
    };
  };

  profileModule = submoduleWith {
    modules = [
      genericSettings
      profileSettings
    ];
  };

  nodeModule = submoduleWith {
    modules = [
      genericSettings
      nodeSettings
    ];
  };

  rootModule = submoduleWith {
    modules = [
      genericSettings
      nodesSettings
    ];
  };
in
{
  options.deploy = mkOption {
    type = rootModule;
  };

  # filter profiles and nodes by enabledness
  config.flake.deploy =
    let
      isEnabled = (_: v: v.enable);
    in
    config.deploy
    // {
      nodes =
        config.deploy.nodes
        |> filterAttrs isEnabled
        |> builtins.mapAttrs (_n: node: node // { profiles = node.profiles |> filterAttrs isEnabled; });
    };

  config.perSystem =
    { inputs', ... }:
    {
      checks = inputs'.deploy-rs.legacyPackages.lib.deployChecks config.deploy;
    };
}
