{ lib }:

let
  # O(n) 去重 (attrset 插入, 替代 lib.unique O(n²)).
  dedupePkgs = list:
    builtins.attrValues
      (builtins.listToAttrs
        (map
          (p:
            let
              key =
                if builtins.isAttrs p then (p.pname or p.name or (builtins.toString (p.outPath or p)))
                else builtins.toString p;
            in
            { name = key; value = p; })
          list));

  mkFhsBase = { label, pkgsList }: {
    inherit label pkgsList;
    _isFhsBase = true;
  };

  combine = bases:
    mkFhsBase {
      label = lib.concatStringsSep "+" (map (b: b.label) bases);
      pkgsList = p: lib.concatMap (b: b.pkgsList p) bases;
    };

  # 增量扩展: fhsBase.extend (pkgs: [ ... ])
  extend = base: extraFn:
    assert lib.isFunction extraFn;
    mkFhsBase {
      label = "${base.label}+extra";
      pkgsList = p: base.pkgsList p ++ extraFn p;
    };

  resolveTargetPkgs = base: p: dedupePkgs (base.pkgsList p);

  # ── 自包含包集 ──
  # NOTE: 包引用一律显式 `pkgs.` 限定, 禁止 `with pkgs`.
  # P 为 `rec` 自引用集合, 裸名 (`wayland`/`gtk3`/`qt5`/`qt6` 等) 会优先解析到
  # P 自身同名函数而非 nixpkgs 包, 曾导致 derivation 列表混入函数
  # (cannot coerce a function to a string). 同胞组合 (`qt`/`desktop-gui`)
  # 保留裸名自引用 (有意为之).
  P = rec {
    base = pkgs: [
      pkgs.glibc
      pkgs.gcc.cc.lib
      pkgs.zlib
      pkgs.bzip2
      pkgs.xz
      pkgs.dbus
      pkgs.openssl
    ];

    x11 = pkgs: [
      pkgs.libx11
      pkgs.libxcomposite
      pkgs.libxdamage
      pkgs.libxext
      pkgs.libxfixes
      pkgs.libxrandr
      pkgs.libxrender
      pkgs.libxtst
      pkgs.libxcb
      pkgs.libxi
      pkgs.libxcursor
      pkgs.libICE
      pkgs.libSM
      pkgs.libxinerama
      pkgs.libxscrnsaver
      pkgs.libxshmfence
      pkgs.libxkbfile
    ];

    wayland = pkgs: [
      pkgs.wayland
      pkgs.libxkbcommon
    ];

    graphics = pkgs: [
      pkgs.libGL
      pkgs.libGLU
      pkgs.libgbm
      pkgs.mesa
      pkgs.libva
      pkgs.libdrm
      pkgs.vulkan-loader
      pkgs.pciutils
    ];

    audio = pkgs: [
      pkgs.pipewire
      pkgs.alsa-lib
      pkgs.libpulseaudio
    ];

    fonts = pkgs: [
      pkgs.fontconfig.lib
      pkgs.freetype
      pkgs.harfbuzz
    ];

    gtk3 = pkgs: [
      pkgs.gtk3
      pkgs.glib
      pkgs.cairo
      pkgs.pango
      pkgs.atk
      pkgs.gdk-pixbuf
      pkgs.libayatana-appindicator
      pkgs.libappindicator-gtk3
      pkgs.gsettings-desktop-schemas
      pkgs.dconf
      pkgs.dconf.lib
    ];

    qt5 = pkgs: [
      pkgs.qt5.qtbase
      pkgs.qt5.qtwayland
      pkgs.qt5.qtx11extras
      pkgs.qt5.qtsvg
      pkgs.qt5.qtdeclarative
    ];

    qt6 = pkgs: [
      pkgs.qt6.qtbase
      pkgs.qt6.qtwayland
      pkgs.qt6.qtsvg
      pkgs.qt6.qtdeclarative
    ];

    qt = pkgs: qt5 pkgs ++ qt6 pkgs;

    webkitgtk = pkgs: [
      pkgs.webkitgtk_4_1
      pkgs.libsoup_3
    ];

    dotnet = pkgs: [
      pkgs.icu
      pkgs.sqlite
    ];

    media = pkgs: [
      pkgs.ffmpeg
      pkgs.libvpx
      pkgs.libevent
      pkgs.nss
      pkgs.nspr
      pkgs.curl
      pkgs.krb5
      pkgs.cups
    ];

    electron = pkgs: [
      pkgs.at-spi2-core
      pkgs.cups
      pkgs.expat
      pkgs.libgbm
      pkgs.libsecret
      pkgs.libnotify
      pkgs.nspr
      pkgs.nss
      pkgs.systemdLibs
    ];

    xcb = pkgs: [
      pkgs.libxcb
      pkgs.libxcb-util
      pkgs.libxcb-image
      pkgs.libxcb-keysyms
      pkgs.libxcb-render-util
      pkgs.libxcb-wm
      pkgs.libxcb-cursor
      pkgs.libxcb-errors
    ];

    desktop-gui = pkgs:
      base pkgs
      ++ x11 pkgs
      ++ wayland pkgs
      ++ graphics pkgs
      ++ audio pkgs
      ++ fonts pkgs
      ++ gtk3 pkgs
      ++ xcb pkgs;
  };

  b = name: pkgsList: mkFhsBase { label = name; inherit pkgsList; };

  fhsBases = rec {
    base = b "base" P.base;
    x11 = b "x11" P.x11;
    wayland = b "wayland" P.wayland;
    graphics = b "graphics" P.graphics;
    audio = b "audio" P.audio;
    fonts = b "fonts" P.fonts;
    gtk3 = b "gtk3" P.gtk3;
    qt5 = b "qt5" P.qt5;
    qt6 = b "qt6" P.qt6;
    qt = b "qt" P.qt;
    webkitgtk = b "webkitgtk" P.webkitgtk;
    dotnet = b "dotnet" P.dotnet;
    media = b "media" P.media;
    electron = b "electron" P.electron;
    xcb = b "xcb" P.xcb;

    desktop-gui = b "desktop-gui" P.desktop-gui;

    desktop-gui-media = combine [ desktop-gui media ];
    desktop-gui-electron = combine [ desktop-gui electron ];
    desktop-gui-electron-media = combine [ desktop-gui electron media ];
    desktop-gui-electron-media-xcb-qt = combine [ desktop-gui electron media xcb qt ];
    desktop-gui-webkitgtk = combine [ desktop-gui webkitgtk ];
    desktop-gui-dotnet = combine [ desktop-gui dotnet ];
  };
in
{
  inherit mkFhsBase combine extend resolveTargetPkgs fhsBases dedupePkgs;
}
