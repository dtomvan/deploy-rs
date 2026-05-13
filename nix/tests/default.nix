# SPDX-FileCopyrightText: 2024 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

# withSystem lambda
{
  self',
  pkgs,
  inputs,
  ...
}:
let
  mkTest =
    {
      name ? "",
      user ? "root",
      isLocal ? true,
      deployArgs,
    }:
    pkgs.testers.runNixOSTest (
      { lib, ... }:
      {
        inherit name;

        nodes.server = {
          _module.args = { inherit inputs; };

          imports = [
            ./server.nix
            ./common.nix
          ];

          virtualisation.additionalPaths = lib.optionals (!isLocal) [
            pkgs.hello
            pkgs.figlet
            self'.packages.deploy-rs
          ];
        };

        nodes.client = {
          _module.args = { inherit inputs; };
          imports = [ ./common.nix ];

          environment.systemPackages = [ self'.packages.deploy-rs ];
          # nix evaluation takes a lot of memory, especially in non-flake usage
          virtualisation.memorySize = lib.mkForce 4096;
          virtualisation.additionalPaths = [
            # needed so client can lock it inside of their flake under /tmp
            ../..
          ]
          ++ lib.optionals isLocal [
            pkgs.hello
            pkgs.figlet
          ];
        };

        testScript =
          { nodes, ... }:
          let
            inherit (import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs) snakeOilPrivateKey;

            serverNetworkJSON = pkgs.writers.writeJSON "server-network.json" nodes.server.system.build.networkConfig;

            flake = pkgs.replaceVars ./deploy-flake.nix {
              deploy-rs = ../..;
            };
          in
          # python
          ''
            start_all()

            # Prepare
            client.succeed("cd `mktemp -d`")
            client.succeed("cp ${flake} ./flake.nix")
            client.succeed("cp ${./server.nix} ./server.nix")
            client.succeed("cp ${./common.nix} ./common.nix")
            client.succeed("cp ${serverNetworkJSON} ./network.json")
            client.succeed("nix flake lock")

            # Setup SSH key
            client.succeed("mkdir -m 700 /root/.ssh")
            client.succeed('cp --no-preserve=mode ${snakeOilPrivateKey} /root/.ssh/id_ed25519')
            client.succeed("chmod 600 /root/.ssh/id_ed25519")

            # Test SSH connection
            server.wait_for_open_port(22)
            client.wait_for_unit("network.target")
            client.succeed(
              "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no server 'echo hello world' >&2",
              timeout=30
            )

            # Make sure the hello and figlet packages are missing
            server.fail("su ${user} -l -c 'hello | figlet'")

            # Deploy to the server
            client.succeed("deploy ${deployArgs}")

            # Make sure packages are present after deployment
            server.succeed("su ${user} -l -c 'hello | figlet' >&2")
          '';
      }
    );
in
{
  # Deployment with client-side build
  local-build = mkTest {
    name = "local-build";
    deployArgs = "-s .#server -- --offline";
  };

  # Deployment with server-side build
  remote-build = mkTest {
    name = "remote-build";
    isLocal = false;
    deployArgs = "-s .#server --remote-build -- --offline";
  };

  # Deployment with overridden options
  options-overriding = mkTest {
    name = "options-overriding";
    deployArgs = builtins.concatStringsSep " " [
      "-s .#server-override"
      "--hostname server --profile-user root --ssh-user root --sudo 'sudo -u'"
      "--ssh-opts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"
      "--confirm-timeout 30 --activation-timeout 30"
      "-- --offline"
    ];
  };

  # User profile deployment
  profile = mkTest {
    name = "profile";
    user = "deploy";
    deployArgs = "-s .#profile -- --offline";
  };

  hyphen-ssh-opts-regression = mkTest {
    name = "profile";
    user = "deploy";
    deployArgs = "-s .#profile --ssh-opts '-p 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' -- --offline";
  };
}
