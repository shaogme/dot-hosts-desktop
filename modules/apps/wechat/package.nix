{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;
  wechatPin = sources.wechat;

  version =
    let
      match = builtins.match ".*/com\\.tencent\\.wechat_([0-9.]+)_.*\\.deb" wechatPin.url;
    in
    if match != null then builtins.head match
    else throw "wechat: Could not parse version from URL: ${wechatPin.url}";

  src = pkgs.fetchurl {
    url = wechatPin.url;
    hash = wechatPin.hash;
    curlOptsList = [ "-A" "debian APT-HTTP/1.3 (1.6.11)" ];
  };
in
mkSandboxedApp {
  pname = "wechat";
  inherit version src;
  srcType = "deb";
  execPath = "opt/apps/com.tencent.wechat/files/wechat";
  runInDirectory = "opt/apps/com.tencent.wechat/files";

  profiles = [ "desktop-gui" "media" "electron" "xcb" ];
  sandboxDirs = [ ".xwechat" "Documents/WeChat_Data" "xwechat_files" ];
  hostDirs = [ ".xwechat" "Documents/WeChat_Data" "xwechat_files" ];

  environment = {
    QT_QPA_PLATFORM = "xcb";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  };

  postUnpack = ''
    if [ -d "$out/opt/apps/com.tencent.wechat/entries/icons" ]; then
      mkdir -p $out/share
      cp -rn $out/opt/apps/com.tencent.wechat/entries/icons $out/share/
      chmod -R u+w $out/share/icons 2>/dev/null || true
      for icon_dir in "$out"/share/icons/hicolor/*/apps; do
        if [ -d "$icon_dir" ]; then
          if [ -f "$icon_dir/com.tencent.wechat.png" ] && [ ! -f "$icon_dir/wechat.png" ]; then
            ln -sf "$icon_dir/com.tencent.wechat.png" "$icon_dir/wechat.png"
          fi
        fi
      done
    fi
  '';

  aliases = [ "wechat-universal" "weixin" ];

  desktop = {
    desktopName = "WeChat";
    genericName = "Instant Messaging";
    comment = "WeChat Desktop Client (Bubblewrap Isolated)";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    icon = "wechat";
    startupWMClass = "wechat";
  };
}
