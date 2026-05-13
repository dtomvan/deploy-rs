# SPDX-FileCopyrightText: 2024 Sefa Eyeoglu <contact@scrumplex.net>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, ... }:
let
  inherit (lib) mkOption;

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

  # due to how deploy-rs rust code works we need to re-export the deploy metadata anyways
  config.flake = { inherit (config) deploy; };

  config.perSystem =
    { inputs', ... }:
    {
      checks = inputs'.deploy-rs.legacyPackages.lib.deployChecks config.deploy;
    };
}
