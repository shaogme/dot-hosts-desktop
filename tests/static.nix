{ pkgs, configuration, name }:

let
  # 评估 configuration.nix
  eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [
      configuration
      # 注入测试专用覆盖，避免评估时因缺少某些物理环境属性而报错
      {
        # 如果需要可以在这里添加覆盖
      }
    ];
    inherit pkgs;
  };
  
  cfg = eval.config;

  # 只过滤出失败的断言，避免评估已通过断言的 message 导致惰性求值报错
  failedAssertions = pkgs.lib.filter (x: !x.assertion) cfg.assertions;

  # 将失败的断言转换为 Bash 报错语句
  generateFailure = index: assertionObj: ''
    echo "错误: [${name}] 静态断言未通过 - ${assertionObj.message}"
  '';

  failuresBash = pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap0 generateFailure failedAssertions);
  failedCount = builtins.length failedAssertions;
in
pkgs.runCommand "${name}-static-check" {
  # 增加元数据输出，方便调试
  passthru = { inherit eval; };
} ''
  echo "--- 正在执行静态检查 [${name}] ---"

  ${if failedCount > 0 then ''
    ${failuresBash}
    exit 1
  '' else ''
    echo "[${name}] 所有静态断言检查通过！"
  ''}

  echo "静态检查通过！"
  touch $out
''
