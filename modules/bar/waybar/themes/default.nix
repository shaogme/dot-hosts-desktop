{
  pkgs,
  lib,
  config,
  ...
}:

let
  defaultTheme = import ./default-theme.nix { inherit pkgs lib config; };
in
{
  default-theme = defaultTheme;
  default = defaultTheme;
}
