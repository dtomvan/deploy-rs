{
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
    "aarch64-linux"
  ];

  perSystem =
    {
      self',
      pkgs,
      lib,
      ...
    }:
    {
      packages = {
        default = self'.packages.deploy-rs;
        deploy-rs = pkgs.callPackage ../package.nix { };
      };

      legacyPackages.lib = import ./deploy-lib.nix {
        inherit pkgs;
        inherit (self'.packages) deploy-rs;
      };

      apps = {
        default = self'.apps.deploy-rs;
        deploy-rs = {
          type = "app";
          program = lib.getExe' self'.packages.default "deploy";
        };
      };
    };

  flake.lib.makeDeployLib =
    {
      deploy-rs ? pkgs.deploy-rs,
      pkgs,
    }:
    import ./deploy-lib.nix { inherit pkgs deploy-rs; };
}
