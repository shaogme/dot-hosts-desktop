let
  sources = import ../hosts/virtual-box/npins;
  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  sandboxLib = import ../modules/apps/lib/mk-sandboxed-app/sandbox.nix { inherit lib; };
  launcherLib = import ../modules/apps/lib/mk-sandboxed-app/mk-launcher-env.nix { inherit pkgs lib; };
  wineLauncherLib = import ../modules/apps/lib/mk-sandboxed-app/mk-wine-launcher.nix { inherit pkgs lib; };
  fhsEnvLib = import ../modules/apps/lib/mk-sandboxed-app/mk-fhs-env.nix { inherit pkgs lib; };
  fhsBases = import ../modules/apps/lib/mk-sandboxed-app/fhs-bases.nix { inherit lib; };
  mkSandboxedApp = import ../modules/apps/lib/mk-sandboxed-app { inherit pkgs lib; };

  # ── 1. 验证 extraBinds 使用 --bind-try 且无硬编码 --bind ────────
  bwrapArgsTest = sandboxLib.makeBwrapArgs {
    sandboxName = "test-app";
    extraBinds = [ [ "/tmp/dumps" "/tmp/dumps" ] [ "/nonexistent/src" "/nonexistent/dest" ] ];
    extraRoBinds = [ [ "/etc/hosts" "/etc/hosts" ] ];
  };
  bwrapStr = builtins.concatStringsSep " " bwrapArgsTest;

  assertNoHardBind =
    assert !(lib.hasInfix "--bind /tmp/dumps" bwrapStr);
    assert (lib.hasInfix "--bind-try /tmp/dumps" bwrapStr);
    assert (lib.hasInfix "--bind-try /nonexistent/src" bwrapStr);
    assert (lib.hasInfix "--ro-bind-try /etc/hosts" bwrapStr);
    true;

  # ── 2. 验证沙箱持久化路径统一为 $HOME/.sandboxes，无分裂 ────────
  assertPathUnification =
    assert !(lib.hasInfix "XDG_DATA_HOME" (builtins.elemAt (lib.drop 3 bwrapArgsTest) 0));
    assert !(lib.hasInfix "XDG_DATA_HOME" (builtins.elemAt (lib.drop 3 bwrapArgsTest) 1));
    assert (lib.hasInfix "$HOME/.sandboxes/test-app" bwrapStr);
    true;

  # ── 3. 验证 Shell 变量严格转义，防命令注入 ────────────────────
  injectionEnv = {
    NORMAL = "simple_val";
    SPECIAL_QUOTES = "hello\"world; echo hacked";
    VARS = "$HOME and `whoami`";
    NEWLINE = "line1\nline2";
  };
  dummyUnpacked = pkgs.runCommand "dummy-unpacked" {} "mkdir -p $out/bin && touch $out/bin/app && chmod +x $out/bin/app";

  launcherResult = launcherLib.mkLauncherEnv {
    pname = "test-env-app";
    unpacked = dummyUnpacked;
    execPath = "bin/app";
    env = injectionEnv;
  };
  launcherProfile = launcherResult.profile;

  assertShellEscaped =
    assert (lib.hasInfix "export SPECIAL_QUOTES='hello\"world; echo hacked'" launcherProfile);
    assert (lib.hasInfix "export VARS='$HOME and `whoami`'" launcherProfile);
    assert !(lib.hasInfix ''export SPECIAL_QUOTES="hello"world'' launcherProfile);
    true;

  # ── 4. 验证 UID 1000 回退已彻底清除，动态探测 $(id -u) ────────
  sandboxSrc = builtins.readFile ../modules/apps/lib/mk-sandboxed-app/sandbox.nix;
  assertNoUid1000 =
    assert !(lib.hasInfix "/run/user/1000" sandboxSrc);
    assert (lib.hasInfix "/run/user/$(id -u)" sandboxSrc);
    true;

  # ── 5. 验证 buildFHSEnv 自动挂载拦截与隔离粒度 ────────────────
  fhsTest = fhsEnvLib.mkFhsEnv {
    pname = "test-sandbox-isolation";
    fhsBase = fhsBases.fhsBases.base;
    extraBwrapArgs = bwrapArgsTest;
    runScript = "echo ok";
  };
  fhsBwrapScript = builtins.readFile "${fhsTest}/bin/test-sandbox-isolation-fhs";

  assertRootIsolation =
    assert (lib.hasInfix "ignored+=(\"$d\")" fhsBwrapScript);
    assert (lib.hasInfix "--tmpfs /home" bwrapStr);
    assert (lib.hasInfix "--dir $HOME" bwrapStr);
    assert (lib.hasInfix "--bind $HOME/.sandboxes/test-app $HOME" bwrapStr);
    true;

  # ── 6. 验证 shareMedia = false 时遮蔽 /run/media ─────────────
  noMediaArgs = sandboxLib.makeBwrapArgs {
    sandboxName = "test-no-media";
    shareMedia = false;
  };
  noMediaStr = builtins.concatStringsSep " " noMediaArgs;
  assertMediaShielded =
    assert (lib.hasInfix "--tmpfs /run/media" noMediaStr);
    true;

in
pkgs.runCommand "sandbox-security-check" {
  passthru = {
    inherit assertNoHardBind assertPathUnification assertShellEscaped assertNoUid1000 assertRootIsolation assertMediaShielded;
  };
} ''
  echo "正在验证沙箱安全性与隔离重构规范..."
  echo "1. 验证 extraBinds 容错性 (--bind-try)..."
  test "${toString assertNoHardBind}" = "1"
  echo "2. 验证沙箱根路径统一性 ($HOME/.sandboxes)..."
  test "${toString assertPathUnification}" = "1"
  echo "3. 验证 Shell 变量转义与防注入..."
  test "${toString assertShellEscaped}" = "1"
  echo "4. 验证动态探测 UID ($(id -u))..."
  test "${toString assertNoUid1000}" = "1"
  echo "5. 验证 buildFHSEnv 敏感目录隔离与 /home tmpfs 遮蔽..."
  test "${toString assertRootIsolation}" = "1"
  echo "6. 验证 shareMedia=false 外接设备遮蔽 (/run/media tmpfs)..."
  test "${toString assertMediaShielded}" = "1"
  echo "所有沙箱隔离与系统安全性测试项均已完美通过！" > $out
''
