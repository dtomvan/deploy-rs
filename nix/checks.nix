{
  withSystem,
  self,
  lib,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
in
{
  perSystem =
    { self', ... }:
    {
      checks.deploy-rs = self'.packages.default.overrideAttrs {
        doCheck = true;
      };
    };

  flake.checks.${system} = withSystem system (args: import ./tests (args // { inherit inputs; }));

  flake.githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
    checks = lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (system: self.checks.${system});
  };
}
