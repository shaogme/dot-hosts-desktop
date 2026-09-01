{ pkgs, lib ? pkgs.lib }:

rec {
  profiles = import ./profiles.nix { inherit pkgs lib; };
  unpackers = import ./unpackers.nix { inherit pkgs lib; };
  mkSandboxedApp = import ./mk-sandboxed-app.nix { inherit pkgs lib; };
  mkAppModule = import ./mk-app-module.nix { inherit lib; };
}
