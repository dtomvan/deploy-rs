# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
# SPDX-FileCopyrightText: 2020 Andreas Fuchs <asf@boinkor.net>
#
# SPDX-License-Identifier: MPL-2.0
{
  flake.overlays.default =
    final: prev:
    let
      deploy-rs = prev.callPackage ../package.nix { };
    in
    {
      deploy-rs = {
        inherit deploy-rs;

        lib = import ./deploy-lib.nix {
          inherit deploy-rs;
          pkgs = prev;
        };
      };
    };
}
