{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? import ../lib/mk-sandboxed-app { inherit pkgs lib; } }:

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
mkSandboxedApp.qtApp {
  pname = "wechat";
  inherit version;
  src = { deb = src; };
  execPath = "opt/apps/com.tencent.wechat/files/wechat";
  runInDirectory = "opt/apps/com.tencent.wechat/files";

  sandbox = { homeDirs = [ ".xwechat" "Documents/WeChat_Data" "xwechat_files" ]; };

  env = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR_ROUNDING_POLICY = "PassThrough";
  };

  # 虚拟环境兼容: 提供 /usr/bin/lsblk 符号链接, 避免微信调用 lsblk 探测块设备时报错
  fhsExtraCommands = [
    "ln -sf ${pkgs.coreutils}/bin/true $out/usr/bin/lsblk"
  ];

  postUnpackHooks = [
    ''
      if [ -d "$out/opt/apps/com.tencent.wechat/entries/icons" ]; then
        mkdir -p $out/share
        cp -a --reflink=auto $out/opt/apps/com.tencent.wechat/entries/icons $out/share/ 2>/dev/null \
          || cp -rn $out/opt/apps/com.tencent.wechat/entries/icons $out/share/
        chmod -R u+w $out/share/icons 2>/dev/null || true
        find "$out/share/icons" -type f -name "com.tencent.wechat.png" -exec sh -c '
          link="$1"
          d=$(dirname "$link")
          if [ ! -e "$d/wechat.png" ]; then
            ln -sf "$link" "$d/wechat.png"
          fi
        ' _ {} \;
      fi
    ''
  ];

  icons = { hicolor.auto = true; };

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
