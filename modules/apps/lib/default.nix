{ pkgs, lib ? pkgs.lib }:

let
  fetchWithRetry = import ./fetch-with-retry.nix { inherit pkgs lib; };
in
{
  inherit fetchWithRetry;
  fetchDeb = fetchWithRetry;
  mkSandboxedApp = import ./mk-sandboxed-app { inherit pkgs lib; };
  fhsBases = (import ./mk-sandboxed-app/fhs-bases.nix { inherit lib; }).fhsBases;
  mkAppModule = import ./mk-app-module.nix { inherit lib; };
}
