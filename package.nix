{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "deploy-rs";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "A Simple multi-profile Nix-flake deploy tool";
    mainProgram = "deploy";
  };
}
