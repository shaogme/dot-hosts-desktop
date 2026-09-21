{ pkgs, lib ? pkgs.lib }:

let
  defaultRetries = 5;
  defaultRetryDelay = 3;

  # 默认的 curl 弹性重试参数集:
  # --retry 5: 重试 5 次
  # --retry-delay 3: 每次重试等待 3 秒
  # --retry-all-errors: 对所有瞬态错误（包括网络断开、超时、429/5xx 等）均进行重试
  # --retry-connrefused: 针对连接被拒绝的情况亦进行重试
  makeRetryCurlOpts =
    { retries ? defaultRetries
    , retryDelay ? defaultRetryDelay
    , curlOptsList ? [ ]
    }:
    [
      "--retry"
      (toString retries)
      "--retry-delay"
      (toString retryDelay)
      "--retry-all-errors"
      "--retry-connrefused"
    ]
    ++ curlOptsList;

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
      retryOpts = makeRetryCurlOpts {
        retries = extraOpts.retries or defaultRetries;
        retryDelay = extraOpts.retryDelay or defaultRetryDelay;
        curlOptsList = extraOpts.curlOptsList or [ ];
      };
    in
    if lib.isDerivation arg || builtins.isPath arg then
      arg
    else if pinObj != null then
      let
        # npins 函子解析：注入 pkgs 实例化为 derivation，同时保留 NPINS_OVERRIDE 机制
        resolved =
          if builtins.isFunction pinObj || pinObj ? __functor then
            pinObj { inherit pkgs; }
          else
            pinObj;
        rawOut = resolved.outPath or resolved;
      in
      if lib.isDerivation rawOut then
        rawOut.overrideAttrs (old: {
          curlOptsList = retryOpts ++ (old.curlOptsList or [ ]);
        })
      else
        rawOut
    else if builtins.isAttrs arg && arg ? url then
      let
        unpack = arg.unpack or false;
        fetcher = if unpack then pkgs.fetchzip else pkgs.fetchurl;
      in
      fetcher {
        inherit (arg) url;
        hash =
          arg.hash or arg.sha256
            or (throw "fetchWithRetry: URL '${arg.url}' 缺少 hash 或 sha256 校验码");
        name = arg.name or (baseNameOf arg.url);
        curlOptsList = retryOpts ++ (arg.curlOptsList or [ ]);
      }
    else if builtins.isString arg then
      if lib.hasPrefix "http://" arg || lib.hasPrefix "https://" arg then
        # 针对无 hash 校验码的裸 URL 字符串（如根据 release tag 动态拼接 URL 的包），
        # 回退使用 builtins.fetchurl，确保各类包均能统一通过 fetchWithRetry 调度
        builtins.fetchurl arg
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
  inherit ensureFetched makeRetryCurlOpts defaultRetries defaultRetryDelay;
}
