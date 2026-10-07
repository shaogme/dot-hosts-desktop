{ lib }:

rec {
  # ── Src ADT (仅接受 ADT, 无 srcType 字符串分发) ──
  #   src = { deb = <file>; }
  #       | { tarball = <file>; stripRoot ? bool; }
  #       | { zip = <file>; }
  #       | { nsis = <file>; }
  #       | { inno = <file>; }
  #       | { msi = <file>; }
  #       | { custom = <drv | path>; }
  # 返回: { kind; file; stripRoot; }
  normalizeSrc = { src, stripRoot ? true }:
    let
      effectiveStripRoot = if src ? stripRoot then src.stripRoot else stripRoot;
    in
    if !(builtins.isAttrs src) then
      throw "mkSandboxedApp: src 必须为 ADT attrset ({ deb = ...; } | { tarball = ...; } | { zip = ...; } | { nsis = ...; } | { inno = ...; } | { msi = ...; } | { custom = ...; }), 实际类型 ${builtins.typeOf src}"
    else if src ? deb then
      {
        kind = "deb";
        file = src.deb;
        stripRoot = effectiveStripRoot;
      }
    else if src ? tarball then
      {
        kind = "tarball";
        file = src.tarball;
        stripRoot = effectiveStripRoot;
      }
    else if src ? zip then
      { kind = "zip"; file = src.zip; stripRoot = effectiveStripRoot; }
    else if src ? nsis then
      { kind = "nsis"; file = src.nsis; stripRoot = effectiveStripRoot; }
    else if src ? inno then
      { kind = "inno"; file = src.inno; stripRoot = effectiveStripRoot; }
    else if src ? msi then
      { kind = "msi"; file = src.msi; stripRoot = effectiveStripRoot; }
    else if src ? custom then
      { kind = "custom"; file = src.custom; stripRoot = effectiveStripRoot; }
    else
      throw "mkSandboxedApp: src ADT 缺少 deb|tarball|zip|nsis|inno|msi|custom 键 (实际键: ${lib.concatStringsSep "," (builtins.attrNames src)})";

  # npins set (含 outPath) 显式展开为 store 路径, 避免 builtins.isPath 误判.
  srcOutPath = file:
    if builtins.isAttrs file && file ? outPath && !(lib.isDerivation file) then
      file.outPath
    else
      file;

  # ── Sandbox 类型化子模块 (封闭 attrset, 未知字段 throw) ──
  sandboxDefaults = {
    isolatedHome = true;
    shareNet = true;
    wayland = true;
    x11 = true;
    audio = true;
    dbus = true;
    inputMethod = true;
    bypassProxy = false;
    shareDownloads = true;
    shareUserDirs = false;
    shareData = true;
    shareMedia = true;
    shareGames = false;
    shareInput = false;
    shareShm = true;
    # shareThemeStatic（icons/gtk ini 快照）vs shareThemeLive（desktop-theme/darkman/dconf-runtime），默认全 true。
    shareThemeStatic = true;
    shareThemeLive = true;
    # 宿主机字体与字体配置继承（系统字体与用户字体目录），默认开启
    shareFonts = true;
    sharedDirs = [ ];
    roSharedDirs = [ ];
    extraBinds = [ ];
    extraRoBinds = [ ];
    extraBwrapArgs = [ ];
    homeDirs = [ ];
    name = null;
  };

  allowedSandboxKeys = builtins.attrNames sandboxDefaults;

  normalizeSandbox = { sandbox ? { }, pname }:
    let
      unknown = lib.filter (k: !(builtins.elem k allowedSandboxKeys)) (builtins.attrNames sandbox);
    in
    if unknown != [ ] then
      throw "mkSandboxedApp: sandbox 含未知字段 [${lib.concatStringsSep ", " unknown}] (允许: ${lib.concatStringsSep ", " allowedSandboxKeys})"
    else
      sandboxDefaults // { name = pname; } // sandbox;

  # ── Icons ADT (仅接受 ADT, 无 iconStrategy 字符串) ──
  #   icons = { hicolor.auto = true; }
  #         | { firefox.sizes ? [int]; }  (sizes 缺省为默认 7 档)
  #         | { none = true; }
  #         | null (等价 hicolor.auto)
  # 返回: { kind = "hicolor"|"firefox"|"none"; sizes; }
  defaultFirefoxSizes = [ 16 24 32 48 64 128 256 ];

  normalizeIcons = { icons ? null }:
    if icons == null then
      { kind = "hicolor"; sizes = [ ]; }
    else if !(builtins.isAttrs icons) then
      throw "mkSandboxedApp: icons 必须为 ADT attrset 或 null"
    else if icons ? none then
      { kind = "none"; sizes = [ ]; }
    else if icons ? firefox then
      let f = icons.firefox; in
      {
        kind = "firefox";
        sizes =
          if builtins.isAttrs f && f ? sizes then f.sizes
          else defaultFirefoxSizes;
      }
    else if icons ? hicolor then
      { kind = "hicolor"; sizes = [ ]; }
    else
      throw "mkSandboxedApp: icons ADT 缺少 hicolor|firefox|none 键";

  # ── Env (仅 env, 静态 attrset, 无 environment 别名) ──
  normalizeEnv = { env ? { } }:
    if !(builtins.isAttrs env) then
      throw "mkSandboxedApp: env 必须为 attrset"
    else
      env;

  # ── Hooks (仅静态 string 列表, 无函数动态分发) ──
  # preRunHooks: [string], runInDirectory: null | string (静态, 相对路径按 unpacked 解析)
  # 返回: { preRunLines; runDir; }
  resolvePreRun = { preRunHooks ? [ ], runInDirectory ? null, unpacked }:
    let
      _checkHooks =
        if !(builtins.isList preRunHooks) then
          throw "mkSandboxedApp: preRunHooks 必须为 string 列表"
        else if lib.any (h: lib.isFunction h) preRunHooks then
          throw "mkSandboxedApp: preRunHooks 不接受函数"
        else true;
      _checkDir =
        if runInDirectory != null && lib.isFunction runInDirectory then
          throw "mkSandboxedApp: runInDirectory 不接受函数"
        else true;
    in
    assert _checkHooks; assert _checkDir;
    {
      preRunLines = lib.concatStringsSep "\n"
        (lib.filter (s: s != "") (map toString preRunHooks));
      runDir =
        if runInDirectory == null then null
        else if lib.hasPrefix "/" runInDirectory then runInDirectory
        else "${unpacked}/${runInDirectory}";
    };

  # fhsExtraCommands: [string] (无 extraBuildCommands 字符串/函数)
  resolveExtraBuildCommands = { fhsExtraCommands ? [ ] }:
    if !(builtins.isList fhsExtraCommands) then
      throw "mkSandboxedApp: fhsExtraCommands 必须为 string 列表"
    else
      lib.concatStringsSep "\n" (map toString fhsExtraCommands);

  # postUnpackHooks: [string] (无 postUnpack 字符串注入)
  resolvePostUnpack = { postUnpackHooks ? [ ] }:
    if !(builtins.isList postUnpackHooks) then
      throw "mkSandboxedApp: postUnpackHooks 必须为 string 列表"
    else
      lib.concatStringsSep "\n" (map toString postUnpackHooks);

  # ── Wine 类型化子模块 (封闭 attrset, 未知字段 throw) ──
  wineFontsDefaults = {
    enableOfficeFonts = true;
    enableCjkFallback = true;
    enableFontSmoothing = true;
    customFonts = [ ];
  };

  allowedWineFontsKeys = builtins.attrNames wineFontsDefaults;

  normalizeWineFonts = raw:
    let
      fonts = if builtins.isAttrs raw && raw ? fonts && builtins.isAttrs raw.fonts then raw.fonts else raw;
    in
    if !(builtins.isAttrs fonts) then
      throw "mkSandboxedApp: wine.fonts 必须为 attrset"
    else
      let
        unknown = lib.filter (k: !(builtins.elem k allowedWineFontsKeys)) (builtins.attrNames fonts);
      in
      if unknown != [ ] then
        throw "mkSandboxedApp: wine.fonts 含未知字段 [${lib.concatStringsSep ", " unknown}] (允许: ${lib.concatStringsSep ", " allowedWineFontsKeys})"
      else
        wineFontsDefaults // fonts;

  wineDefaults = {
    package = null;
    arch = "win64";
    dxvk = false;
    fonts = wineFontsDefaults;
    registry = { };
    regFiles = [ ];
    dllOverrides = { };
    drives = {
      "d:" = "Downloads";
    };
    tricks = [ ];
    dpi = null;
    waitWineserver = true;
    debug = "-all";
  };

  allowedWineKeys = builtins.attrNames wineDefaults;

  normalizeWine = raw:
    let
      wine = if builtins.isAttrs raw && raw ? wine && builtins.isAttrs raw.wine then raw.wine else raw;
    in
    if !(builtins.isAttrs wine) then
      throw "mkSandboxedApp: wine 必须为 attrset"
    else
      let
        unknown = lib.filter (k: !(builtins.elem k allowedWineKeys)) (builtins.attrNames wine);
        normalizedFonts = normalizeWineFonts (wine.fonts or { });
        arch = wine.arch or "win64";
        _checkArch =
          if arch != "win64" && arch != "win32" then
            throw "mkSandboxedApp: wine.arch 必须为 'win64' 或 'win32' (实际: '${arch}')"
          else true;
      in
      if unknown != [ ] then
        throw "mkSandboxedApp: wine 含未知字段 [${lib.concatStringsSep ", " unknown}] (允许: ${lib.concatStringsSep ", " allowedWineKeys})"
      else
        assert _checkArch;
        wineDefaults // wine // { fonts = normalizedFonts; };
}
