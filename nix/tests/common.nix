# SPDX-FileCopyrightText: 2024 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  inputs,
  lib,
  ...
}:
{
  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = lib.mkForce [ ];
    };
  };

  # system.includeBuildDependencies = true;

  # The "nixos-test-profile" profile disables the `switch-to-configuration` script by default
  system.switch.enable = true;

  virtualisation.graphics = false;
  virtualisation.memorySize = 1536;
  boot.loader.grub.enable = false;
  documentation.enable = false;
}
