{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.screenRecorder.obs;

  # 包装带有扩展插件的最终 OBS Studio 软件包
  finalPackage =
    if cfg.plugins != [ ] then
      (pkgs.wrapOBS.override {
        obs-studio = cfg.package;
      }) {
        inherit (cfg) plugins;
      }
    else
      cfg.package;
in
{
  imports = [
    (lib.mkAliasOptionModule [ "desktop" "screenRecording" "obs" ] [ "desktop" "screenRecorder" "obs" ])
    (lib.mkAliasOptionModule [ "desktop" "recorder" "obs" ] [ "desktop" "screenRecorder" "obs" ])
  ];

  options.desktop.screenRecorder.obs = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 OBS Studio 专业屏幕录制与流媒体推流工具。";
    };

    package = mkPackageOption pkgs "obs-studio" { };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = finalPackage;
      description = "经过插件扩展包装后的最终 OBS Studio 软件包。";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-pipewire-audio-capture
        obs-vaapi
        obs-vkcapture
        obs-gstreamer
      ];
      description = "OBS Studio 扩展插件集合，默认包含 Wayland 录屏 (wlrobs)、PipeWire 音频采集、VA-API 硬件编解码加速、Vulkan 游戏捕获与 GStreamer 管道集成。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "注入到系统环境的多媒体辅助工具列表。";
    };

    enableVirtualCamera = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 v4l2loopback 虚拟摄像头内核驱动支持（允许将 OBS 输出画面虚拟为摄像头设备）。";
    };

    niri = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动为 Niri 窗口管理器配置 OBS 窗口规则。";
      };

      openFloating = mkOption {
        type = types.bool;
        default = false;
        description = "是否在 Niri 窗口管理器中默认以浮动窗口打开 OBS Studio。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "若系统中启用了 Home Manager，是否自动将 OBS Studio 软件包注入到所有 Home Manager 用户中。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级软件包安装
      environment.systemPackages = [
        finalPackage
      ] ++ cfg.extraPackages;

      # 2. 虚拟摄像头 (v4l2loopback) 支持
      boot = mkIf cfg.enableVirtualCamera {
        kernelModules = [ "v4l2loopback" ];
        extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
        extraModprobeConfig = ''
          options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
        '';
      };

      security.polkit.enable = mkIf cfg.enableVirtualCamera true;

      # 3. 联动向 Niri 注册窗口规则（若设置了 openFloating）
      desktop.windowManager.niri = mkIf (config ? desktop && config.desktop ? windowManager && config.desktop.windowManager ? niri && config.desktop.windowManager.niri.enable && cfg.niri.enable && cfg.niri.openFloating) {
        windowRules.extraRules = [
          {
            match._props = {
              app-id = "^(com\\.obsproject\\.Studio|obs)$";
            };
            open-floating = true;
          }
        ];
      };
    }

    # 4. Home Manager 深度联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [
              finalPackage
            ] ++ cfg.extraPackages;
          })
        ];
      };
    })
  ]);
}
