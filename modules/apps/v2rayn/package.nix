{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

let
  sources = import ./npins;
  system = pkgs.stdenv.hostPlatform.system;
  pin =
    if system == "x86_64-linux" then
      sources.v2rayn-x86_64
    else if system == "aarch64-linux" then
      sources.v2rayn-aarch64
    else
      throw "v2rayn: 不支持的系统架构 '${system}'";

  version =
    let
      match = builtins.match ".*/download/([0-9.]+)/.*" pin.url;
    in
    if match != null then builtins.head match else "7.25.5";
in
mkSandboxedApp.dotnetApp {
  pname = "v2rayn";
  inherit version;
  src = { deb = mkSandboxedApp.fetchWithRetry pin; };
  execPath = "opt/v2rayN/v2rayN";
  runInDirectory = "opt/v2rayN";

  sandbox = { bypassProxy = true; };

  postUnpackHooks = [
    ''chmod +x $out/opt/v2rayN/v2rayN $out/opt/v2rayN/bin/*/* 2>/dev/null || true''
  ];

  env = {
    V2RAYN_LOCAL_APPLICATION_DATA_V2 = "1";
  };

  # @UNPACKED@ 由管线在构建期静态替换为 unpacked store 路径 (无函数闭包).
  preRunHooks = [
    ''DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/v2rayN"''
    ''mkdir -p "$DATA_DIR/bin" "$DATA_DIR/guiConfigs" "$DATA_DIR/guiLogs"''
    ''if [ -d "@UNPACKED@/opt/v2rayN/bin" ]; then cp -rn @UNPACKED@/opt/v2rayN/bin/* "$DATA_DIR/bin/" 2>/dev/null || true; fi''
    ''chmod -R +x "$DATA_DIR/bin" 2>/dev/null || true''
  ];

  icons = { hicolor.auto = true; };

  desktop = {
    desktopName = "v2rayN";
    genericName = "Proxy GUI Client";
    comment = "v2rayN - Proxy GUI Client (Bubblewrap Isolated)";
    icon = "v2rayn";
    categories = [ "Network" ];
  };
}
