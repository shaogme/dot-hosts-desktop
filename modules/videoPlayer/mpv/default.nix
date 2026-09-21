{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.videoPlayer.mpv;

  # 包装带有扩展脚本的最终 MPV 软件包
  finalPackage =
    if cfg.scripts != [ ] then
      cfg.package.override {
        scripts = cfg.scripts;
      }
    else
      cfg.package;

  # 检查是否加载了 uosc 界面增强脚本
  hasUosc = any (p: (p.pname or p.name or "") == "uosc" || hasInfix "uosc" (p.name or "")) cfg.scripts;

  # 格式化 mpv.conf 属性值
  formatValue = v:
    if isBool v then (if v then "yes" else "no")
    else toString v;

  # 将 Nix 属性集序列化为 mpv.conf 兼容的键值对配置
  toMpvConf = attrs:
    concatStringsSep "\n" (
      mapAttrsToList (k: v:
        if isList v then
          concatMapStringsSep "\n" (item: "${k}=${formatValue item}") v
        else
          "${k}=${formatValue v}"
      ) attrs
    );

  # 默认基础配置预设 (mpv.conf)
  defaultSettings = {
    # 视频与图形渲染输出 (Wayland 环境优化)
    vo = "gpu-next";
    gpu-context = "wayland";
    hwdec = "auto-safe";

    # 播放与窗口行为
    save-position-on-quit = true;
    keep-open = "yes";
    autofit = "85%x85%";

    # 音轨与字幕语言偏好 (优先简中/繁中/英文/日文)
    alang = "zh,chi,chs,sc,zho,en,eng,ja,jp,jpn";
    slang = "zh,chi,chs,sc,zho,en,eng,ja,jp,jpn";

    # OSD 与界面控制 (若启用 uosc 则由 uosc 接管，关闭原生 osc 与进度条)
    osc = !hasUosc;
    osd-bar = !hasUosc;
    osd-font = "sans-serif";
    osd-font-size = 28;
  };

  # 合并配置并追加文本片段
  mergedSettings = recursiveUpdate defaultSettings cfg.settings;
  baseMpvConf = toMpvConf mergedSettings;
  fullMpvConfText =
    if cfg.extraConfig != "" then
      "${baseMpvConf}\n${cfg.extraConfig}\n"
    else
      "${baseMpvConf}\n";

  # 快捷键绑定文本生成 (input.conf)
  baseInputConf = concatStringsSep "\n" (
    mapAttrsToList (key: cmd: "${key} ${cmd}") cfg.bindings
  );
  fullInputConfText =
    if cfg.extraInputConfig != "" then
      "${baseInputConf}\n${cfg.extraInputConfig}\n"
    else
      (if baseInputConf != "" then "${baseInputConf}\n" else "");

  # 生成 script-opts 配置文件映射
  scriptOptsFiles = mapAttrs' (name: attrs:
    nameValuePair "xdg/mpv/script-opts/${name}.conf" {
      text = toMpvConf attrs;
    }
  ) cfg.scriptOpts;

  hmScriptOptsFiles = mapAttrs' (name: attrs:
    nameValuePair "mpv/script-opts/${name}.conf" {
      text = toMpvConf attrs;
    }
  ) cfg.scriptOpts;

  # 常见多媒体与音视频 MIME 类型列表
  mediaMimeTypes = [
    "video/mp4"
    "video/mkv"
    "video/x-matroska"
    "video/webm"
    "video/x-msvideo"
    "video/quicktime"
    "video/mpeg"
    "video/x-flv"
    "video/ogg"
    "video/3gp"
    "video/3gpp"
    "video/x-ogm+ogg"
    "audio/mp3"
    "audio/mpeg"
    "audio/flac"
    "audio/ogg"
    "audio/wav"
    "audio/aac"
    "audio/m4a"
    "audio/x-m4a"
    "audio/opus"
  ];

  mimeAttrs = listToAttrs (map (mime: nameValuePair mime "mpv.desktop") mediaMimeTypes);
in
{
  imports = [
    (lib.mkAliasOptionModule [ "desktop" "mediaPlayer" "mpv" ] [ "desktop" "videoPlayer" "mpv" ])
  ];

  options.desktop.videoPlayer.mpv = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 MPV 现代多媒体与视频播放器。";
    };

    package = mkPackageOption pkgs "mpv" { };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = finalPackage;
      description = "经过扩展脚本包装后的最终 MPV 软件包。";
    };

    scripts = mkOption {
      type = types.listOf types.package;
      default = with pkgs.mpvScripts; [
        mpris
        uosc
        thumbfast
      ];
      description = "MPV 扩展脚本集合，默认包含 mpris (桌面媒体控制)、uosc (现代交互 UI) 与 thumbfast (时间轴悬浮缩略图)。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ pkgs.yt-dlp ];
      description = "注入到系统环境的多媒体辅助工具列表（默认包含 yt-dlp 网络流媒体解析）。";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "以 Nix 结构化数据编写的 mpv.conf 配置，将与默认预设深度合并。";
    };

    bindings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "以 Nix 属性键值对形式编写的 input.conf 快捷键映射（如 { \"SPACE\" = \"cycle pause\"; }）。";
    };

    scriptOpts = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = "以 Nix 结构化数据编写的 MPV 扩展脚本独立配置文件集合，生成至 script-opts/<name>.conf。";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 mpv.conf 的原生纯文本配置片段。";
    };

    extraInputConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入 input.conf 的原生纯文本快捷键配置片段。";
    };

    defaultPlayer = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 MPV 设为系统默认音视频播放器并关联常见多媒体 MIME 类型。";
    };

    niri = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动为 Niri 窗口管理器配置 MPV 窗口规则。";
      };

      openFloating = mkOption {
        type = types.bool;
        default = false;
        description = "是否在 Niri 窗口管理器中默认以浮动窗口打开 MPV。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 MPV 配置注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级软件包安装
      environment.systemPackages = [
        finalPackage
      ] ++ cfg.extraPackages;

      # 2. 系统级配置文件部署 (/etc/xdg/mpv/ 与 /etc/mpv/)
      environment.etc = {
        "xdg/mpv/mpv.conf".text = fullMpvConfText;
        "mpv/mpv.conf".text = fullMpvConfText;
      }
      // optionalAttrs (fullInputConfText != "") {
        "xdg/mpv/input.conf".text = fullInputConfText;
        "mpv/input.conf".text = fullInputConfText;
      }
      // scriptOptsFiles;

      # 3. 默认 MIME 类型关联
      xdg.mime.defaultApplications = mkIf cfg.defaultPlayer mimeAttrs;
      xdg.mime.addedAssociations = mkIf cfg.defaultPlayer mimeAttrs;

      # 4. 联动向 Niri 注册窗口规则（若设置了 openFloating）
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.niri.enable && cfg.niri.openFloating) {
        windowRules.extraRules = [
          {
            match._props = {
              app-id = "^(mpv)$";
            };
            open-floating = true;
          }
        ];
      };
    }

    # 6. Home Manager 自动联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              finalPackage
            ] ++ cfg.extraPackages;

            xdg.configFile = {
              "mpv/mpv.conf".text = fullMpvConfText;
            }
            // optionalAttrs (fullInputConfText != "") {
              "mpv/input.conf".text = fullInputConfText;
            }
            // hmScriptOptsFiles;

            xdg.mimeApps.defaultApplications = mkIf cfg.defaultPlayer mimeAttrs;
          })
        ];
      };
    })
  ]);
}
