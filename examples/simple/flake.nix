# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  description = "Deploy GNU hello to localhost";

  inputs.deploy-rs.url = "github:serokell/deploy-rs";

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
    }:
    {
      deploy.nodes.example = {
        hostname = "localhost";
        profiles.hello = {
          user = "balsoft";
          path = deploy-rs.legacyPackages.x86_64-linux.lib.activate.custom {
            base = nixpkgs.legacyPackages.x86_64-linux.hello;
            activate = "./bin/hello";
          };
        };
      };

      checks = builtins.mapAttrs (
        system: deployPkgs: deployPkgs.lib.deployChecks self.deploy
      ) deploy-rs.legacyPackages;
    };
}
