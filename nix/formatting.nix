{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem.treefmt.programs = {
    actionlint.enable = true;
    nixfmt.enable = true;
    rumdl-format.enable = true;
    rustfmt.enable = true;
  };
}
