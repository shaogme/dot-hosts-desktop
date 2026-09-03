{ lib }:

rec {
  # ── Src ADT (仅接受 ADT, 无 srcType 字符串分发) ──
  #   src = { deb = <file>; }
  #       | { tarball = <file>; stripRoot ? bool; }
  #       | { custom = <drv | path>; }
  # 返回: { kind; file; stripRoot; }
  normalizeSrc = { src, stripRoot ? true }:
    if !(builtins.isAttrs src) then
      throw "mkSandboxedApp: src 必须为 ADT attrset ({ deb = ...; } | { tarball = ...; } | { custom = ...; }), 实际类型 ${builtins.typeOf src}"
    else if src ? deb then
      {
        kind = "deb";
        file = src.deb;
        inherit stripRoot;
      }
    else if src ? tarball then
      {
        kind = "tarball";
        file = src.tarball;
        stripRoot = if src ? stripRoot then src.stripRoot else stripRoot;
      }
    else if src ? custom then
      { kind = "custom"; file = src.custom; inherit stripRoot; }
    else
      throw "mkSandboxedApp: src ADT 缺少 deb|tarball|custom 键 (实际键: ${lib.concatStringsSep "," (builtins.attrNames src)})";

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
    # shareThemeStatic（icons/gtk ini 快照）vs shareThemeLive（desktop-theme/darkman/dconf-runtime），默认全 true。
    shareThemeStatic = true;
    shareThemeLive = true;
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
}
