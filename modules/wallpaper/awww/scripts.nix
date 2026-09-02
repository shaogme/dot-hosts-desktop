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

  # 构造默认转场与渲染参数
  defaultImgArgs = [
    "--resize" cfg.render.resize
    "--crop-gravity" cfg.render.cropGravity
    "--filter" cfg.render.filter
    "--fill-color" (removePrefix "#" cfg.render.fillColor)
    "--transition-type" cfg.transition.type
    "--transition-duration" (toString cfg.transition.duration)
    "--transition-fps" (toString cfg.transition.fps)
    "--transition-angle" (toString cfg.transition.angle)
    "--transition-pos" cfg.transition.pos
    "--transition-bezier" cfg.transition.bezier
    "--transition-wave" cfg.transition.wave
  ] ++ optionals (cfg.transition.step != null) [
    "--transition-step" (toString cfg.transition.step)
  ] ++ optionals cfg.transition.invertY [
    "--invert-y" "true"
  ] ++ optionals (cfg.daemon.namespace != "") [
    "--namespace" cfg.daemon.namespace
  ];

  defaultImgArgsStr = escapeShellArgs defaultImgArgs;

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

    # 1. 判断是否为纯色 Hex 格式 (如 #1e1e2e 或 1e1e2e)
    if [[ "$TARGET" =~ ^#?([0-9a-fA-F]{6})$ ]]; then
      HEX="''${BASH_REMATCH[1]}"
      if [ -n "$OUTPUT" ]; then
        exec ${awwwPkg}/bin/awww clear -o "$OUTPUT" "$HEX" "''${@:3}"
      else
        exec ${awwwPkg}/bin/awww clear "$HEX" "''${@:3}"
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

    # 执行切换
    if [ -n "$OUTPUT" ]; then
      ${awwwPkg}/bin/awww img -o "$OUTPUT" ${defaultImgArgsStr} \
        --transition-type "$RAND_TRANS" \
        --transition-angle "$RAND_ANGLE" \
        "$SELECTED_IMG"
    else
      ${awwwPkg}/bin/awww img ${defaultImgArgsStr} \
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

    FILES=$(${pkgs.findutils}/bin/find "''${CANDIDATE_DIRS[@]}" -type f \( \
      -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
      -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" -o \
      -iname "*.jxl" -o -iname "*.svg" -o -iname "*.bmp" -o -iname "*.tiff" \
    \) 2>/dev/null | ${pkgs.coreutils}/bin/sort -u)

    if [ -z "$FILES" ]; then
      echo "未找到任何壁纸！" >&2
      exit 1
    fi

    # 优先使用 wofi 弹出选择，若无则使用 fzf 或 dmenu
    if command -v wofi >/dev/null 2>&1; then
      CHOICE=$(echo "$FILES" | while read -r f; do
        printf "%s\0info\x1f%s\n" "$(${pkgs.coreutils}/bin/basename "$f")" "$f"
      done | wofi --dmenu --prompt "选择桌面壁纸" --insensitive --allow-images --width 600 --height 450)
      
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
    if [ -n "$OUTPUT" ]; then
      ${awwwPkg}/bin/awww restore -o "$OUTPUT" || true
    else
      ${awwwPkg}/bin/awww restore || true
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
    in
    ''
      ${awwwPkg}/bin/awww img -o "${outName}" \
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
    if cfg.outputs != { } then
      outputInitCommands
    else if cfg.color != null then
      "${awwwPkg}/bin/awww clear ${removePrefix "#" cfg.color} || true"
    else if cfg.wallpaper != null then
      "${awwwSetScript}/bin/awww-set \"${toString cfg.wallpaper}\" || true"
    else
      ''
        # 尝试 restore 缓存，如果失败则应用默认精美 4K 矢量壁纸
        if ! ${awwwPkg}/bin/awww restore 2>/dev/null; then
          ${awwwSetScript}/bin/awww-set "${builtinsWallpapers.defaultWallpaper}" || true
        fi
      '';

  awwwInitScript = pkgs.writeShellScriptBin "awww-init" ''
    # 1. 确保 awww-daemon 运行
    if ! ${pkgs.procps}/bin/pgrep -x awww-daemon >/dev/null 2>&1; then
      ${awwwPkg}/bin/awww-daemon ${daemonArgsStr} &
    fi

    # 2. 等待 socket 响应可用
    for i in $(seq 1 30); do
      if ${awwwPkg}/bin/awww query >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done

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
