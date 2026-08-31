let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
(import (sources.nixpkgs + "/nixos/lib/eval-config.nix") {
  inherit pkgs;
  modules = [ ./configuration.nix ];
}).config.system.build.toplevel
