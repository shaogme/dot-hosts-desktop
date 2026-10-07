let
  sources = import ../hosts/virtual-box/npins;
  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  fetchWithRetryLib = import ../modules/apps/lib/fetch-with-retry.nix { inherit pkgs lib; };
  fetchWithRetrySrc = builtins.readFile ../modules/apps/lib/fetch-with-retry.nix;

  # ── 1. 验证禁止直接传入裸 URL 字符串 ──────────────────────────────
  testBareUrlBlocked =
    let
      res = builtins.tryEval (fetchWithRetryLib "https://example.com/malicious.deb");
    in
    assert res.success == false;
    true;

  # ── 2. 验证 fetch-with-retry 源码中已彻底移除 builtins.fetchurl 后门 ─
  assertNoFetchurlBackdoor =
    assert !(lib.hasInfix "builtins.fetchurl" fetchWithRetrySrc);
    true;

  # ── 3. 验证 unpack=true 不再退回 pkgs.fetchzip，而是使用 aria2 FOD ─
  assertNoFetchzipBypass =
    assert !(lib.hasInfix "pkgs.fetchzip" fetchWithRetrySrc);
    assert (lib.hasInfix "outputHashMode = if unpack then \"recursive\" else \"flat\"" fetchWithRetrySrc);
    assert (lib.hasInfix "dontFixup = true" fetchWithRetrySrc);
    true;

  # ── 4. 验证 clash-verge / v2rayn / onlyoffice 均已接入 npins，无裸 URL
  clashVergePkgSrc = builtins.readFile ../modules/apps/clash-verge/package.nix;
  v2raynPkgSrc = builtins.readFile ../modules/apps/v2rayn/package.nix;
  onlyofficePkgSrc = builtins.readFile ../modules/apps/onlyoffice/package.nix;

  assertNoBareUrlInApps =
    assert !(lib.hasInfix "debUrl =" clashVergePkgSrc);
    assert !(lib.hasInfix "https://" clashVergePkgSrc);
    assert !(lib.hasInfix "debUrl =" v2raynPkgSrc);
    assert !(lib.hasInfix "https://" v2raynPkgSrc);
    assert !(lib.hasInfix "debUrl =" onlyofficePkgSrc);
    assert !(lib.hasInfix "https://" onlyofficePkgSrc);
    true;

  # ── 5. 验证 npins sources.json 均已正确锁定哈希与 URL ─────────────
  clashPins = (builtins.fromJSON (builtins.readFile ../modules/apps/clash-verge/npins/sources.json)).pins;
  v2raynPins = (builtins.fromJSON (builtins.readFile ../modules/apps/v2rayn/npins/sources.json)).pins;
  onlyofficePins = (builtins.fromJSON (builtins.readFile ../modules/apps/onlyoffice/npins/sources.json)).pins;

  assertNpinsLocked =
    assert clashPins ? "clash-verge" && lib.hasPrefix "sha256-" clashPins."clash-verge".hash;
    assert v2raynPins ? "v2rayn-x86_64" && lib.hasPrefix "sha256-" v2raynPins."v2rayn-x86_64".hash;
    assert v2raynPins ? "v2rayn-aarch64" && lib.hasPrefix "sha256-" v2raynPins."v2rayn-aarch64".hash;
    assert onlyofficePins ? "onlyoffice-x86_64" && lib.hasPrefix "sha256-" onlyofficePins."onlyoffice-x86_64".hash;
    assert onlyofficePins ? "onlyoffice-aarch64" && lib.hasPrefix "sha256-" onlyofficePins."onlyoffice-aarch64".hash;
    true;

  # ── 6. 验证各包正常完成 Nix 表达式求值 ───────────────────────────
  clashVergePkg = import ../modules/apps/clash-verge/package.nix { inherit pkgs lib; };
  v2raynPkg = import ../modules/apps/v2rayn/package.nix { inherit pkgs lib; };
  onlyofficePkg = import ../modules/apps/onlyoffice/package.nix { inherit pkgs lib; };

  assertPkgsEvaluated =
    assert clashVergePkg.name == "clash-verge-2.5.7";
    assert v2raynPkg.name == "v2rayn-7.25.5";
    assert onlyofficePkg.name == "onlyoffice-9.4.0";
    true;

  # ── 7. 验证所有 "type": "Url" 的应用均维护独立的 update.sh 脚本 ──
  allAppsDir = ../modules/apps;
  appsEntries = builtins.readDir allAppsDir;
  urlAppsMissingUpdate = lib.filter (appName:
    let
      appPath = allAppsDir + "/${appName}";
      sourcesJsonPath = appPath + "/npins/sources.json";
      updateShPath = appPath + "/update.sh";
    in
    if appsEntries.${appName} == "directory" && builtins.pathExists sourcesJsonPath then
      let
        sourcesData = builtins.fromJSON (builtins.readFile sourcesJsonPath);
        hasUrlType = lib.any (pin: pin.type or "" == "Url") (builtins.attrValues (sourcesData.pins or { }));
      in
      hasUrlType && !(builtins.pathExists updateShPath)
    else
      false
  ) (builtins.attrNames appsEntries);

  assertAllUrlAppsHaveUpdateScript =
    assert urlAppsMissingUpdate == [ ];
    true;

in
pkgs.runCommand "dependency-management-check" {
  passthru = {
    inherit
      testBareUrlBlocked
      assertNoFetchurlBackdoor
      assertNoFetchzipBypass
      assertNoBareUrlInApps
      assertNpinsLocked
      assertPkgsEvaluated
      assertAllUrlAppsHaveUpdateScript;
  };
} ''
  echo "正在验证依赖管理与 npins / AGENTS.md 规范重构..."
  echo "1. 验证裸 URL 被阻断异常..."
  test "${toString testBareUrlBlocked}" = "1"
  echo "2. 验证 fetch-with-retry 无 builtins.fetchurl 后门..."
  test "${toString assertNoFetchurlBackdoor}" = "1"
  echo "3. 验证 unpack=true 采用 aria2c FOD 解包并移除 fetchzip 绕过..."
  test "${toString assertNoFetchzipBypass}" = "1"
  echo "4. 验证 clash-verge / v2rayn / onlyoffice 无裸 URL 拼接..."
  test "${toString assertNoBareUrlInApps}" = "1"
  echo "5. 验证 npins sources.json 多架构依赖哈希已锁定..."
  test "${toString assertNpinsLocked}" = "1"
  echo "6. 验证软件包求值正常..."
  test "${toString assertPkgsEvaluated}" = "1"
  echo "7. 验证所有 'type': 'Url' 的跟踪源均具备独立的 update.sh 更新脚本..."
  test "${toString assertAllUrlAppsHaveUpdateScript}" = "1"
  echo "所有依赖管理与 npins 规范检查项均已完美通过！" > $out
''
