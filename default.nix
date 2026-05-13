# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  pkgs ? import <nixpkgs> { },
  ...
}:
pkgs.callPackage ./package.nix { }
