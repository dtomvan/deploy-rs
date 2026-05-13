# toplevel flake-parts module
{
  imports = [
    ./formatting.nix
    ./packages.nix
    ./checks.nix
    ./devshells.nix
    ./overlay.nix
  ];

  flake = {
    flakeModules.default = ./flake-module.nix;
    flakeModule = ./flake-module.nix;
  };
}
