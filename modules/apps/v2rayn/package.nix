{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  unpackers = import ../lib/unpackers.nix { inherit pkgs lib; };
  sources = import ./npins;
  rawVersion = sources.v2rayN.version;
  version = lib.removePrefix "v" rawVersion;

  arch = unpackers.resolveArch {
    x86_64 = "64";
    aarch64 = "arm64";
    riscv64 = "riscv64";
    loongarch64 = "loong64";
  };

  debUrl = "https://github.com/2dust/v2rayN/releases/download/${rawVersion}/v2rayN-linux-${arch}.deb";
in
mkSandboxedApp {
  pname = "v2rayn";
  inherit version;
  src = builtins.fetchurl debUrl;
  srcType = "deb";
  execPath = "opt/v2rayN/v2rayN";
  runInDirectory = "opt/v2rayN";

  profiles = [ "desktop-gui" "dotnet" ];
  bypassProxy = true;
  postUnpack = "chmod +x $out/opt/v2rayN/v2rayN $out/opt/v2rayN/bin/*/* 2>/dev/null || true";

  environment = {
    V2RAYN_LOCAL_APPLICATION_DATA_V2 = "1";
  };

  preRunHook = unpacked: ''
    DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/v2rayN"
    mkdir -p "$DATA_DIR/bin" "$DATA_DIR/guiConfigs" "$DATA_DIR/guiLogs"
    if [ -d "${unpacked}/opt/v2rayN/bin" ]; then
      cp -rn ${unpacked}/opt/v2rayN/bin/* "$DATA_DIR/bin/" 2>/dev/null || true
    fi
  '';

  desktop = {
    desktopName = "v2rayN";
    genericName = "Proxy GUI Client";
    comment = "v2rayN - Proxy GUI Client (Bubblewrap Isolated)";
    icon = "v2rayn";
    categories = [ "Network" ];
  };
}
