{ pkgs, lib ? pkgs.lib }:

{
  mkSandboxedApp = import ./mk-sandboxed-app { inherit pkgs lib; };
  fhsBases = (import ./mk-sandboxed-app/fhs-bases.nix { inherit lib; }).fhsBases;
  mkAppModule = import ./mk-app-module.nix { inherit lib; };
}
