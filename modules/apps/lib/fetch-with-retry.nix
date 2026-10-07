{ pkgs, lib ? pkgs.lib }:

let
  defaultRetries = 5;
  defaultRetryDelay = 3;

  # 基于 aria2 的多线程分块并发下载与断点续传 FOD Fetcher
  fetchAria2 =
    { url
    , hash ? ""
    , sha256 ? ""
    , name ? baseNameOf url
    , pname ? null
    , unpack ? false
    , stripRoot ? true
    , extension ? null
    , retries ? defaultRetries
    , retryDelay ? defaultRetryDelay
    , userAgent ? null
    , headers ? [ ]
    , extraAria2Opts ? [ ]
    }:
    let
      finalHash =
        if hash != "" then
          hash
        else if sha256 != "" then
          sha256
        else
          throw "fetchAria2: URL '${url}' 缺少 hash 或 sha256 校验码";

      targetFileName =
        let
          noQuery = builtins.head (lib.splitString "?" (baseNameOf url));
          noFragment = builtins.head (lib.splitString "#" noQuery);
          guessedName = if noFragment != "" then noFragment else "download";
        in
        if extension != null then
          "download.${extension}"
        else if unpack then
          guessedName
        else if name != "" && name != (baseNameOf url) then
          name
        else
          guessedName;

      allAria2Opts =
        (lib.optional (userAgent != null) "--user-agent=${userAgent}")
        ++ (map (h: "--header=${h}") headers)
        ++ extraAria2Opts;

      escapedOpts = lib.concatMapStringsSep " " lib.escapeShellArg allAria2Opts;
      pnameLine = if pname != null then "echo \">>> [fetchAria2] 关联软件包: ${pname}\"" else "";
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = lib.strings.sanitizeDerivationName name;
      nativeBuildInputs = [
        pkgs.aria2
        pkgs.coreutils
      ] ++ lib.optionals unpack [
        pkgs.unzip
        pkgs.zstd
      ];

      outputHashMode = if unpack then "recursive" else "flat";
      outputHash = finalHash;
      outputHashAlgo =
        if lib.hasPrefix "sha256-" finalHash || lib.hasPrefix "sha512-" finalHash then
          null
        else
          "sha256";

      preferLocalBuild = true;
      enableParallelBuilding = false;

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;

      installPhase = ''
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

        # 1. 动态自适应探测 CPU 核心数
        # 优先读取 Nix 构建环境注入的 NIX_BUILD_CORES；若未指定或 <=0，则探测系统可用逻辑核心数
        CORES="''${NIX_BUILD_CORES:-0}"
        if [ -z "$CORES" ] || [ "$CORES" -le 0 ]; then
          CORES=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
        fi

        # 2. 计算自适应并发数 (限制在 [2, 16] 安全区间，兼顾吞吐加速与防范 CDN 429 限流)
        CONCURRENCY=$CORES
        if [ "$CONCURRENCY" -lt 2 ]; then
          CONCURRENCY=2
        elif [ "$CONCURRENCY" -gt 16 ]; then
          CONCURRENCY=16
        fi

        # 3. 规范化目标文件名，保证在控制台与进度摘要中清晰可辨
        TARGET_FILE=${lib.escapeShellArg targetFileName}
        DL_DIR="$TMPDIR/aria2-download"
        mkdir -p "$DL_DIR"
        trap 'rm -rf "$DL_DIR"' EXIT

        echo "================================================================================"
        ${pnameLine}
        echo ">>> [fetchAria2] 正在下载目标文件: $TARGET_FILE"
        echo ">>> [fetchAria2] 下载源地址 (URL): ${url}"
        echo ">>> [fetchAria2] 解包模式 (unpack): ${lib.boolToString unpack}"
        echo ">>> [fetchAria2] CPU 核心数: $CORES | 并发连接数: $CONCURRENCY"
        echo "================================================================================"

        ${pkgs.aria2}/bin/aria2c \
          --no-conf \
          --auto-file-renaming=false \
          --allow-overwrite=true \
          --ca-certificate="$SSL_CERT_FILE" \
          --split="$CONCURRENCY" \
          --max-connection-per-server="$CONCURRENCY" \
          --min-split-size="2M" \
          --continue=true \
          --max-tries=${toString retries} \
          --retry-wait=${toString retryDelay} \
          --connect-timeout=30 \
          --timeout=60 \
          --console-log-level=warn \
          --summary-interval=0 \
          --download-result=full \
          --dir="$DL_DIR" \
          --out="$TARGET_FILE" \
          ${escapedOpts} \
          ${lib.escapeShellArg url}

        # 4. 产物放置或原地解包
        ${if unpack then ''
          unpackDir="$TMPDIR/unpack"
          mkdir -p "$unpackDir"
          cd "$unpackDir"
          unpackFile "$DL_DIR/$TARGET_FILE"
          chmod -R +w "$unpackDir"

          ${if stripRoot then ''
            if [ $(ls -A "$unpackDir" | wc -l) != 1 ]; then
              echo "error: archive must contain a single file or directory when stripRoot is enabled."
              echo "hint: Pass stripRoot = false to assume a flat list of files."
              exit 1
            fi
            fn=$(cd "$unpackDir" && ls -A)
            if [ -f "$unpackDir/$fn" ]; then
              mkdir -p "$out"
              mv "$unpackDir/$fn" "$out/"
            else
              mv "$unpackDir/$fn" "$out"
            fi
          '' else ''
            mv "$unpackDir" "$out"
          ''}
          chmod 755 "$out"
        '' else ''
          mv "$DL_DIR/$TARGET_FILE" "$out"
        ''}
      '';
    };

  # 通用下载抓取/封装实现（不限定 deb，支持 deb/tarball/zip/各类通用安装包与源码）
  fetchWithRetryFn =
    arg:
    let
      isNpinsPin =
        builtins.isAttrs arg
        && (arg ? __functor || (arg ? type && (arg ? url || arg ? repository) && arg ? hash));
      pinObj =
        if arg ? pin then
          arg.pin
        else if isNpinsPin then
          arg
        else
          null;
      extraOpts =
        if arg ? pin then
          arg
        else if builtins.isAttrs arg then
          arg
        else
          { };
    in
    if lib.isDerivation arg || builtins.isPath arg then
      arg
    else if pinObj != null then
      let
        # npins 函子解析：优先检查是否有本地路径覆盖 (NPINS_OVERRIDE_<NAME>)
        resolved =
          if builtins.isFunction pinObj || pinObj ? __functor then
            pinObj { inherit pkgs; }
          else
            pinObj;
        rawOut = resolved.outPath or resolved;
      in
      if builtins.isPath rawOut || (builtins.isString rawOut && !lib.isDerivation rawOut && builtins.pathExists rawOut) then
        # 本地覆盖路径直接透传
        rawOut
      else if pinObj ? url && pinObj ? hash then
        # 命中 URL/Tarball 类型的 npins 依赖，直接通过 aria2 多线程并发与断点续传拉取
        fetchAria2 {
          inherit (pinObj) url hash;
          unpack = extraOpts.unpack or pinObj.unpack or false;
          stripRoot = extraOpts.stripRoot or pinObj.stripRoot or true;
          extension = extraOpts.extension or pinObj.extension or null;
          name = extraOpts.name or pinObj.name or (baseNameOf pinObj.url);
          pname = extraOpts.pname or pinObj.pname or null;
          retries = extraOpts.retries or defaultRetries;
          retryDelay = extraOpts.retryDelay or defaultRetryDelay;
          userAgent = extraOpts.userAgent or null;
          headers = extraOpts.headers or [ ];
          extraAria2Opts = extraOpts.extraAria2Opts or [ ];
        }
      else if lib.isDerivation rawOut then
        rawOut
      else
        rawOut
    else if builtins.isAttrs arg && arg ? url then
      fetchAria2 {
        inherit (arg) url;
        hash =
          arg.hash or arg.sha256
            or (throw "fetchWithRetry: URL '${arg.url}' 缺少 hash 或 sha256 校验码");
        name = arg.name or (baseNameOf arg.url);
        pname = arg.pname or null;
        unpack = arg.unpack or false;
        stripRoot = arg.stripRoot or true;
        extension = arg.extension or null;
        retries = arg.retries or defaultRetries;
        retryDelay = arg.retryDelay or defaultRetryDelay;
        userAgent = arg.userAgent or null;
        headers = arg.headers or [ ];
        extraAria2Opts = arg.extraAria2Opts or [ ];
      }
    else if builtins.isString arg then
      if lib.hasPrefix "http://" arg || lib.hasPrefix "https://" arg then
        throw "fetchWithRetry: 禁止直接传入未锁定的裸 URL 字符串 '${arg}'。根据仓库规范 (AGENTS.md)，所有外部网络资源必须通过 npins 锁定（推荐使用 'npins add url ...'）或显式提供带 SRI hash 的属性集 { url, hash, ... }。"
      else if lib.hasPrefix "/nix/store/" arg || (lib.hasPrefix "/" arg && builtins.pathExists arg) then
        arg
      else
        throw "fetchWithRetry: 无法识别的字符串参数 '${arg}'"
    else
      throw "fetchWithRetry: 不支持的参数类型 ${builtins.typeOf arg}";

  # 供解包管线 (mk-unpacked.nix) 调用的自动解析器：
  # 对传入的任意源码对象（deb / tarball / raw url 等），若检测为 npins pin 则自动转换为带弹性重试的 FOD derivation；
  # 已有 derivation 或路径则直接透传。
  ensureFetched =
    arg:
    if lib.isDerivation arg || builtins.isPath arg then
      arg
    else if builtins.isAttrs arg && (arg ? __functor || (arg ? type && (arg ? url || arg ? repository) && arg ? hash)) then
      fetchWithRetryFn arg
    else
      arg;
in
{
  __functor = _self: fetchWithRetryFn;
  inherit ensureFetched fetchAria2 defaultRetries defaultRetryDelay;
}
