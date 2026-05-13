# SPDX-FileCopyrightText: 2024 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  inputs = {
    deploy-rs.url = "@deploy-rs@";
    nixpkgs.follows = "deploy-rs/nixpkgs";
    flake-parts.follows = "deploy-rs/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, lib, ... }:
      let
        user = "deploy";
        system = "x86_64-linux";
        inherit (inputs.deploy-rs.legacyPackages.${system}.lib.activate) nixos custom;
      in
      {
        imports = [ inputs.deploy-rs.flakeModules.default ];

        systems = lib.singleton system;

        nixosConfigurations.server = inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./server.nix
            ./common.nix
            # Import the base config used by nixos tests
            (inputs.nixpkgs.outPath + "/nixos/lib/testing/nixos-test-base.nix")
            # Deployment breaks the network settings, so we need to restore them
            (lib.importJSON ./network.json)
            # Deploy packages
            (
              { pkgs, ... }:
              {
                environment.systemPackages = [
                  pkgs.figlet
                  pkgs.hello
                ];
                nixpkgs.hostPlatform = system;
              }
            )
          ];
        };

        perSystem =
          { pkgs, ... }:
          {
            packages.activatePackage = pkgs.writeShellApplication {
              name = "activate";
              text = ''
                mkdir -p /home/${user}/.nix-profile/bin
                rm -f -- /home/${user}/.nix-profile/bin/hello /home/${user}/.nix-profile/bin/figlet
                ln -s ${lib.getExe pkgs.hello} /home/${user}/.nix-profile/bin/hello
                ln -s ${lib.getExe pkgs.figlet} /home/${user}/.nix-profile/bin/figlet
              '';
            };
          };

        deploy.nodes = {
          server = {
            hostname = "server";
            sshUser = "root";
            sshOpts = [
              "-o"
              "StrictHostKeyChecking=no"
              "-o"
              "StrictHostKeyChecking=no"
            ];
            profiles.system.path = nixos self.nixosConfigurations.server;
          };

          server-override = {
            hostname = "override";
            sshUser = "override";
            user = "override";
            sudo = "override";
            sshOpts = [ ];
            confirmTimeout = 0;
            activationTimeout = 0;
            profiles.system.path = nixos self.nixosConfigurations.server;
          };

          profile = {
            hostname = "server";
            sshUser = "${user}";
            sshOpts = [
              "-o"
              "UserKnownHostsFile=/dev/null"
              "-o"
              "StrictHostKeyChecking=no"
            ];
            profiles = {
              "hello-world".path = custom {
                base = self.packages.${system}.activatePackage;
                activate = "\"$PROFILE/bin/activate\"";
              };
            };
          };
        };
      }
    );
}
