{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [ self'.packages.default ];
        RUST_SRC_PATH = toString pkgs.rustPlatform.rustLibSrc;
        buildInputs = with pkgs; [
          cargo
          rustc
          rust-analyzer
          rustfmt
          clippy
          reuse
          rustPlatform.rustLibSrc
        ];
      };
    };
}
