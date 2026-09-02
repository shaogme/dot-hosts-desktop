{
  pkgs,
  lib,
  cfg,
  builtinsWallpapers,
}:

with lib;

let
  awwwPkg = cfg.package;

  # 默认壁纸检索目录列表
  defaultSearchDirs = [
    (if cfg.wallpaperDir != null then toString cfg.wallpaperDir else "")
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/wallpaper"
    "$HOME/Pictures/Wallpapers/Anime"
    "$HOME/Pictures/Wallpapers/Nature"
    "/etc/wallpapers"
    "${builtinsWallpapers.package}/share/wallpapers"
  ];
  searchDirsStr = concatStringsSep " " (filter (s: s != "") defaultSearchDirs);

  # 基础渲染参数 (缩放、锚点方位、滤镜插值、填充背景色)
  baseRenderArgs = [
    "--resize" cfg.render.resize
    "--crop-gravity" cfg.render.cropGravity
    "--filter" cfg.render.filter
    "--fill-color" (removePrefix "#" cfg.render.fillColor)
  ] ++ optionals (cfg.daemon.namespace != "") [
    "--namespace" cfg.daemon.namespace
  ];

  # 转场基础通用参数 (动画时长、刷新帧率、圆心起始位置、贝塞尔曲线、波动参数、步长与翻转)
  commonTransitionArgs = [
    "--transition-duration" (toString cfg.transition.duration)
    "--transition-fps" (toString cfg.transition.fps)
    "--transition-pos" cfg.transition.pos
    "--transition-bezier" cfg.transition.bezier
    "--transition-wave" cfg.transition.wave
  ] ++ optionals (cfg.transition.step != null) [
    "--transition-step" (toString cfg.transition.step)
  ] ++ optionals cfg.transition.invertY [
    "--invert-y"
  ];

  # 默认转场参数（包含全局设定的转场类型与角度）
  defaultTransitionArgs = [
    "--transition-type" cfg.transition.type
    "--transition-angle" (toString cfg.transition.angle)
  ] ++ commonTransitionArgs;

  # 常规命令使用的完整图像设置参数
  defaultImgArgs = baseRenderArgs ++ defaultTransitionArgs;
  defaultImgArgsStr = escapeShellArgs defaultImgArgs;

  # awww-random 专用参数（剔除 transition-type 与 transition-angle，避免 clap 重复传参报错）
  randomBaseArgs = baseRenderArgs ++ commonTransitionArgs;
  randomBaseArgsStr = escapeShellArgs randomBaseArgs;

  daemonArgs = [
    "--format" cfg.daemon.format
    "--layer" cfg.daemon.layer
  ] ++ optionals (cfg.daemon.namespace != "") [
    "--namespace" cfg.daemon.namespace
  ] ++ optionals cfg.daemon.noCache [
    "--no-cache"
  ] ++ optionals cfg.daemon.quiet [
    "--quiet"
  ] ++ cfg.daemon.extraArgs;

  daemonArgsStr = escapeShellArgs daemonArgs;

  # 1. awww-set: 设置指定壁纸或纯色
  awwwSetScript = pkgs.writeShellScriptBin "awww-set" ''
    set -e
    if [ -z "$1" ]; then
      echo "用法: awww-set <图片路径 | #RRGGBB纯色> [显示器输出名] [额外参数...]"
      exit 1
    fi

    TARGET="$1"
    OUTPUT="''${2:-}"
    NS_ARGS=(${optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}"})

    # 1. 判断是否为纯色 Hex 格式 (如 #1e1e2e 或 1e1e2e)
    if [[ "$TARGET" =~ ^#?([0-9a-fA-F]{6})$ ]]; then
      HEX="''${BASH_REMATCH[1]}"
      if [ -n "$OUTPUT" ]; then
        exec ${awwwPkg}/bin/awww clear "''${NS_ARGS[@]}" -o "$OUTPUT" "$HEX" "''${@:3}"
      else
        exec ${awwwPkg}/bin/awww clear "''${NS_ARGS[@]}" "$HEX" "''${@:3}"
      fi
    fi

    # 2. 图片文件模式
    if [ ! -f "$TARGET" ]; then
      echo "错误: 壁纸文件不存在: $TARGET" >&2
      exit 1
    fi

    if [ -n "$OUTPUT" ]; then
      exec ${awwwPkg}/bin/awww img -o "$OUTPUT" ${defaultImgArgsStr} "$TARGET" "''${@:3}"
    else
      exec ${awwwPkg}/bin/awww img ${defaultImgArgsStr} "$TARGET" "''${@:3}"
    fi
  '';

  # 2. awww-random: 随机选取壁纸并应用绚丽转场
  awwwRandomScript = pkgs.writeShellScriptBin "awww-random" ''
    set -e
    DIR="''${1:-}"
    OUTPUT="''${2:-}"

    # 收集有效搜索目录
    CANDIDATE_DIRS=()
    if [ -n "$DIR" ] && [ -d "$DIR" ]; then
      CANDIDATE_DIRS+=("$DIR")
    else
      for d in ${searchDirsStr}; do
        eval exp_d="$d"
        if [ -d "$exp_d" ]; then
          CANDIDATE_DIRS+=("$exp_d")
        fi
      done
    fi

    if [ ''${#CANDIDATE_DIRS[@]} -eq 0 ]; then
      echo "警告: 未找到有效的壁纸目录，使用系统预置壁纸" >&2
      CANDIDATE_DIRS+=("${builtinsWallpapers.package}/share/wallpapers")
    fi

    # 查找支持的图片格式文件
    MAPFILE=()
    while IFS= read -r -d $'\0' file; do
      MAPFILE+=("$file")
    done < <(${pkgs.findutils}/bin/find "''${CANDIDATE_DIRS[@]}" -type f \( \
      -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
      -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" -o \
      -iname "*.jxl" -o -iname "*.svg" -o -iname "*.bmp" -o -iname "*.tiff" \
    \) -print0 2>/dev/null)

    if [ ''${#MAPFILE[@]} -eq 0 ]; then
      echo "错误: 在指定目录中未找到任何图片文件" >&2
      exit 1
    fi

    # 随机抽取一张壁纸
    RAND_INDEX=$((${pkgs.coreutils}/bin/od -An -N2 -i /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' ') % ''${#MAPFILE[@]})
    SELECTED_IMG="''${MAPFILE[$RAND_INDEX]}"

    # 随机转场特效库
    TRANSITIONS=("fade" "wipe" "wave" "grow" "center" "outer" "any" "simple")
    RAND_TRANS_INDEX=$((${pkgs.coreutils}/bin/od -An -N2 -i /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' ') % ''${#TRANSITIONS[@]})
    RAND_TRANS="''${TRANSITIONS[$RAND_TRANS_INDEX]}"
    RAND_ANGLE=$(( (${pkgs.coreutils}/bin/od -An -N2 -i /dev/urandom | ${pkgs.coreutils}/bin/tr -d ' ') % 360 ))

    # 执行切换（使用 randomBaseArgsStr，避免重复传入 --transition-type 与 --transition-angle 导致 clap 报错）
    if [ -n "$OUTPUT" ]; then
      ${awwwPkg}/bin/awww img -o "$OUTPUT" ${randomBaseArgsStr} \
        --transition-type "$RAND_TRANS" \
        --transition-angle "$RAND_ANGLE" \
        "$SELECTED_IMG"
    else
      ${awwwPkg}/bin/awww img ${randomBaseArgsStr} \
        --transition-type "$RAND_TRANS" \
        --transition-angle "$RAND_ANGLE" \
        "$SELECTED_IMG"
    fi

    # 记录当前已选壁纸路径
    mkdir -p "''${XDG_RUNTIME_DIR:-/tmp}/awww"
    echo "$SELECTED_IMG" > "''${XDG_RUNTIME_DIR:-/tmp}/awww/current_wallpaper"

    # 若安装了 notify-send 发送通知提示
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "awww" -i "preferences-desktop-wallpaper" "桌面壁纸已更新" "$(${pkgs.coreutils}/bin/basename "$SELECTED_IMG") [特效: $RAND_TRANS]" -t 2500 || true
    fi
  '';

  # 3. awww-next: 顺序轮换下一张壁纸
  awwwNextScript = pkgs.writeShellScriptBin "awww-next" ''
    set -e
    DIR="''${1:-}"
    OUTPUT="''${2:-}"

    CANDIDATE_DIRS=()
    if [ -n "$DIR" ] && [ -d "$DIR" ]; then
      CANDIDATE_DIRS+=("$DIR")
    else
      for d in ${searchDirsStr}; do
        eval exp_d="$d"
        if [ -d "$exp_d" ]; then
          CANDIDATE_DIRS+=("$exp_d")
        fi
      done
    fi

    if [ ''${#CANDIDATE_DIRS[@]} -eq 0 ]; then
      echo "警告: 未找到有效的壁纸目录，使用系统预置壁纸" >&2
      CANDIDATE_DIRS+=("${builtinsWallpapers.package}/share/wallpapers")
    fi

    MAPFILE=()
    while IFS= read -r file; do
      [ -n "$file" ] && MAPFILE+=("$file")
    done < <(${pkgs.findutils}/bin/find "''${CANDIDATE_DIRS[@]}" -type f \( \
      -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
      -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" -o \
      -iname "*.jxl" -o -iname "*.svg" -o -iname "*.bmp" -o -iname "*.tiff" \
    \) 2>/dev/null | ${pkgs.coreutils}/bin/sort)

    TOTAL=''${#MAPFILE[@]}
    if [ "$TOTAL" -eq 0 ]; then
      echo "错误: 未找到壁纸文件" >&2
      exit 1
    fi

    STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/awww/wallpaper_index"
    mkdir -p "$(${pkgs.coreutils}/bin/dirname "$STATE_FILE")"
    CURR_IDX=0
    if [ -f "$STATE_FILE" ]; then
      CURR_IDX=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    fi

    NEXT_IDX=$(( (CURR_IDX + 1) % TOTAL ))
    echo "$NEXT_IDX" > "$STATE_FILE"
    SELECTED_IMG="''${MAPFILE[$NEXT_IDX]}"

    if [ -n "$OUTPUT" ]; then
      ${awwwPkg}/bin/awww img -o "$OUTPUT" ${defaultImgArgsStr} "$SELECTED_IMG"
    else
      ${awwwPkg}/bin/awww img ${defaultImgArgsStr} "$SELECTED_IMG"
    fi

    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "awww" -i "preferences-desktop-wallpaper" "桌面壁纸已切换" "$(${pkgs.coreutils}/bin/basename "$SELECTED_IMG") ($((NEXT_IDX+1))/$TOTAL)" -t 2000 || true
    fi
  '';

  # 4. awww-switch: Wofi 交互式壁纸选择器
  awwwSwitchScript = pkgs.writeShellScriptBin "awww-switch" ''
    set -e
    DIR="''${1:-}"

    CANDIDATE_DIRS=()
    if [ -n "$DIR" ] && [ -d "$DIR" ]; then
      CANDIDATE_DIRS+=("$DIR")
    else
      for d in ${searchDirsStr}; do
        eval exp_d="$d"
        if [ -d "$exp_d" ]; then
          CANDIDATE_DIRS+=("$exp_d")
        fi
      done
    fi

    if [ ''${#CANDIDATE_DIRS[@]} -eq 0 ]; then
      echo "警告: 未找到有效的壁纸目录，使用系统预置壁纸" >&2
      CANDIDATE_DIRS+=("${builtinsWallpapers.package}/share/wallpapers")
    fi

    FILES=$(${pkgs.findutils}/bin/find "''${CANDIDATE_DIRS[@]}" -type f \( \
      -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
      -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" -o \
      -iname "*.jxl" -o -iname "*.svg" -o -iname "*.bmp" -o -iname "*.tiff" \
    \) 2>/dev/null | ${pkgs.coreutils}/bin/sort -u)

    if [ -z "$FILES" ]; then
      echo "未找到任何壁纸！" >&2
      exit 1
    fi

    # 优先使用 anyrun 弹出选择，若无则使用 fzf 或 dmenu
    if command -v anyrun >/dev/null 2>&1; then
      CHOICE=$(echo "$FILES" | while read -r f; do
        ${pkgs.coreutils}/bin/basename "$f"
      done | anyrun --plugins libstdin.so)
      
      [ -z "$CHOICE" ] && exit 0
      
      # 匹配完整文件路径
      SELECTED_PATH=""
      while read -r f; do
        if [ "$(${pkgs.coreutils}/bin/basename "$f")" = "$CHOICE" ]; then
          SELECTED_PATH="$f"
          break
        fi
      done <<< "$FILES"
    elif command -v fzf >/dev/null 2>&1; then
      SELECTED_PATH=$(echo "$FILES" | fzf --prompt="选择壁纸 > ")
    else
      SELECTED_PATH=$(echo "$FILES" | head -n 1)
    fi

    if [ -n "$SELECTED_PATH" ] && [ -f "$SELECTED_PATH" ]; then
      ${awwwSetScript}/bin/awww-set "$SELECTED_PATH"
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "awww" -i "preferences-desktop-wallpaper" "已应用壁纸" "$(${pkgs.coreutils}/bin/basename "$SELECTED_PATH")" -t 2500 || true
      fi
    fi
  '';

  # 5. awww-restore: 快速恢复上次缓存壁纸
  awwwRestoreScript = pkgs.writeShellScriptBin "awww-restore" ''
    set -e
    OUTPUT="''${1:-}"
    NS_ARGS=(${optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}"})
    if [ -n "$OUTPUT" ]; then
      ${awwwPkg}/bin/awww restore "''${NS_ARGS[@]}" -o "$OUTPUT" || true
    else
      ${awwwPkg}/bin/awww restore "''${NS_ARGS[@]}" || true
    fi
  '';

  # 6. awww-init: 初始化守护进程与应用初始壁纸
  # 多显示器输出壁纸初始化指令生成
  outputInitCommands = concatStringsSep "\n" (mapAttrsToList (outName: outCfg:
    let
      outImg = if outCfg.wallpaper != null then toString outCfg.wallpaper else builtinsWallpapers.defaultWallpaper;
      outResize = if outCfg.resize != null then outCfg.resize else cfg.render.resize;
      outCropGrav = if outCfg.cropGravity != null then outCfg.cropGravity else cfg.render.cropGravity;
      outFilter = if outCfg.filter != null then outCfg.filter else cfg.render.filter;
      outFillColor = if outCfg.fillColor != null then removePrefix "#" outCfg.fillColor else removePrefix "#" cfg.render.fillColor;
      outTransType = if outCfg.transitionType != null then outCfg.transitionType else cfg.transition.type;
      nsArgs = optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}";
    in
    ''
      ${awwwPkg}/bin/awww img ${nsArgs} -o "${outName}" \
        --resize "${outResize}" \
        --crop-gravity "${outCropGrav}" \
        --filter "${outFilter}" \
        --fill-color "${outFillColor}" \
        --transition-type "${outTransType}" \
        --transition-duration "${toString cfg.transition.duration}" \
        --transition-fps "${toString cfg.transition.fps}" \
        "${outImg}" || true
    ''
  ) cfg.outputs);

  initWallpaperCmd =
    let
      nsArgs = optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}";
    in
    if cfg.outputs != { } then
      outputInitCommands
    else if cfg.color != null then
      "${awwwPkg}/bin/awww clear ${nsArgs} ${removePrefix "#" cfg.color} || true"
    else if cfg.wallpaper != null then
      "${awwwSetScript}/bin/awww-set \"${toString cfg.wallpaper}\" || true"
    else
      ''
        # 尝试 restore 缓存，若无缓存或恢复失败则应用默认精美 4K 矢量壁纸
        RESTORED=0
        if ${awwwPkg}/bin/awww ${nsArgs} restore 2>/dev/null; then
          if ${awwwPkg}/bin/awww ${nsArgs} query 2>/dev/null | grep -q "currently displaying: image:"; then
            RESTORED=1
          fi
        fi
        if [ "$RESTORED" -ne 1 ]; then
          ${awwwSetScript}/bin/awww-set "${builtinsWallpapers.defaultWallpaper}" || true
        fi
      '';

  awwwInitScript = pkgs.writeShellScriptBin "awww-init" ''
    set -e

    NS_ARGS=(${optionalString (cfg.daemon.namespace != "") "--namespace ${cfg.daemon.namespace}"})

    # 1. 若传入 --apply-only（例如由 systemd ExecStartPost 触发），仅执行壁纸渲染，绝不触碰守护进程生命周期
    if [ "''${1:-}" = "--apply-only" ]; then
      ${initWallpaperCmd}
      exit 0
    fi

    # 2. 检查守护进程是否已经可用（通过 awww query 进行权威的 IPC 连通性测试）
    if ! ${awwwPkg}/bin/awww "''${NS_ARGS[@]}" query >/dev/null 2>&1; then
      # 守护进程未响应，检查是否处于 systemd 用户会话且服务已启用
      if command -v systemctl >/dev/null 2>&1 && systemctl --user is-enabled awww-daemon.service >/dev/null 2>&1; then
        # 在 systemd 托管环境下，通过 systemctl 拉起服务，绝不私自启动脱管进程
        systemctl --user start awww-daemon.service || true
      else
        # 独立运行环境（无 systemd 或 systemd.enable = false）：防重拉起脱管 daemon
        if ! ${pkgs.procps}/bin/pgrep -x awww-daemon >/dev/null 2>&1; then
          ${awwwPkg}/bin/awww-daemon ${daemonArgsStr} &
        fi
      fi

      # 轮询等待 socket 响应可用（最多等待 3 秒）
      for i in $(seq 1 30); do
        if ${awwwPkg}/bin/awww "''${NS_ARGS[@]}" query >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done
    fi

    # 3. 应用初始壁纸
    ${initWallpaperCmd}
  '';
in
{
  inherit
    awwwSetScript
    awwwRandomScript
    awwwNextScript
    awwwSwitchScript
    awwwRestoreScript
    awwwInitScript
    daemonArgsStr
    defaultImgArgsStr
    ;
}
