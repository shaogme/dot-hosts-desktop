{ config, pkgs, lib, options, ... }:

with lib;

let
  cfg = config.desktop.fonts;
  sources = import ./npins;

  tsangerJinKaiPackage =
    let
      rawVersion = sources.tsanger-jinkai.version;
      version = lib.removePrefix "v" (lib.removePrefix "tsanger-jinkai/" rawVersion);
      encodedVersion = lib.replaceStrings [ "/" ] [ "%2F" ] rawVersion;
      fontUrl = "https://github.com/shaogme/fonts/releases/download/${encodedVersion}/TsangerJinKai04-W04.ttf";
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "tsanger-jinkai";
      inherit version;
      src = builtins.fetchurl fontUrl;
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        install -Dm644 $src $out/share/fonts/truetype/TsangerJinKai04-W04.ttf
        runHook postInstall
      '';
      meta = with lib; {
        description = "Tsanger JinKai 04 font";
        homepage = "https://github.com/shaogme/fonts";
        platforms = platforms.all;
      };
    };
in
{
  options.desktop.fonts = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用桌面系统与用户统一字体及 Fontconfig 配置模块。";
    };

    fontDir = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 /run/current-system/sw/share/X11/fonts 中创建所有字体软链接。";
      };
    };

    # 主无衬线字体（Geist Sans）配置
    sansSerif = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Geist（Geist Sans）作为系统默认主无衬线字体。";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.geist-font;
        description = "Geist Sans 软件包。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "Geist"
          "Geist Sans"
        ];
        description = "无衬线字体优先族名称列表。";
      };
    };

    # 主衬线字体（Alegreya）配置
    serif = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Alegreya 作为系统默认主衬线字体。";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.alegreya;
        description = "Alegreya 软件包。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "Alegreya"
        ];
        description = "衬线字体优先族名称列表。";
      };
    };

    # 中文字体（仓耳今楷）配置
    cjk = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用仓耳今楷（Tsanger JinKai）作为系统默认中文字体。";
      };
      package = mkOption {
        type = types.package;
        default = tsangerJinKaiPackage;
        description = "仓耳今楷软件包。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "TsangerJinKai04"
          "仓耳今楷04"
          "TsangerJinKai04 W04"
          "仓耳今楷04 W04"
        ];
        description = "中文字体优先族名称列表。";
      };
      monoFamilies = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "中文等宽字体优先族名称列表。";
      };
    };

    # 等宽字体（Maple Mono）配置
    monospace = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Maple Mono 等宽字体。";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.maple-mono.NF-CN;
        description = "Maple Mono 软件包（默认自带 NF 符号与中文字形）。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "Maple Mono NF CN"
          "Maple Mono NF"
          "Maple Mono"
        ];
        description = "等宽字体优先族名称列表。";
      };
    };

    # Nerd Font 符号与图标字体配置
    nerdFonts = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否引入 Nerd Font 符号与图标字体（如 Symbols Nerd Font）。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = [
          pkgs.nerd-fonts.symbols-only
        ];
        description = "Nerd Fonts 符号包列表。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "Symbols Nerd Font Mono"
          "Symbols Nerd Font"
        ];
        description = "Nerd Font 优先族名称列表。";
      };
    };

    # Emoji 字体配置
    emoji = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用现代 Emoji 彩色表情字体。";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.noto-fonts-color-emoji;
        description = "Emoji 软件包。";
      };
      families = mkOption {
        type = types.listOf types.str;
        default = [
          "Noto Color Emoji"
        ];
        description = "Emoji 优先族名称列表。";
      };
    };

    # 通用后备与西文/CJK字体
    fallback = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否安装 Noto Fonts、Noto CJK 与 DejaVu 等通用后备西文与中日韩字体包。";
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          dejavu_fonts
        ];
        description = "通用后备字体软件包列表。";
      };
    };

    # 自定义附加字体
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "用户自定义附加安装的字体包列表。";
    };

    # 汇总计算出的全部字体包列表
    packages = mkOption {
      type = types.listOf types.package;
      default =
        (optional cfg.sansSerif.enable cfg.sansSerif.package)
        ++ (optional cfg.serif.enable cfg.serif.package)
        ++ (optional cfg.cjk.enable cfg.cjk.package)
        ++ (optional cfg.monospace.enable cfg.monospace.package)
        ++ (optionals cfg.nerdFonts.enable cfg.nerdFonts.packages)
        ++ (optional cfg.emoji.enable cfg.emoji.package)
        ++ (optionals cfg.fallback.enable cfg.fallback.packages)
        ++ cfg.extraPackages;
      defaultText = literalExpression "汇总后的全部启用字体包";
      description = "系统安装的字体包集合。";
    };

    # Fontconfig 渲染与默认字体设置
    fontconfig = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否配置 Fontconfig 系统级字体规则。";
      };

      defaultFonts = {
        serif = mkOption {
          type = types.listOf types.str;
          default =
            (optionals cfg.serif.enable cfg.serif.families)
            ++ (optionals cfg.cjk.enable cfg.cjk.families)
            ++ [
              "Noto Serif CJK SC"
              "Noto Serif CJK TC"
              "Noto Serif"
              "DejaVu Serif"
            ];
          description = "Serif 默认首选字体族列表。";
        };

        sansSerif = mkOption {
          type = types.listOf types.str;
          default =
            (optionals cfg.sansSerif.enable cfg.sansSerif.families)
            ++ (optionals cfg.cjk.enable cfg.cjk.families)
            ++ [
              "Noto Sans CJK SC"
              "Noto Sans CJK TC"
              "Noto Sans"
              "DejaVu Sans"
            ];
          description = "Sans-Serif 默认首选字体族列表。";
        };

        monospace = mkOption {
          type = types.listOf types.str;
          default =
            (optionals cfg.monospace.enable cfg.monospace.families)
            ++ (optionals cfg.cjk.enable cfg.cjk.monoFamilies)
            ++ (optionals cfg.nerdFonts.enable cfg.nerdFonts.families)
            ++ [
              "DejaVu Sans Mono"
            ];
          description = "Monospace 默认首选等宽字体族列表。";
        };

        emoji = mkOption {
          type = types.listOf types.str;
          default =
            (optionals cfg.emoji.enable cfg.emoji.families)
            ++ (optionals cfg.nerdFonts.enable [ "Symbols Nerd Font" ]);
          description = "Emoji 默认首选表情字体族列表。";
        };
      };

      hinting = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用字体微调（Hinting）。";
        };
        style = mkOption {
          type = types.enum [ "none" "slight" "medium" "full" ];
          default = "slight";
          description = "字体微调级别。";
        };
        autohint = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 FreeType autohinter。";
        };
      };

      subpixel = {
        rgba = mkOption {
          type = types.enum [ "rgb" "bgr" "vrgb" "vbgr" "none" ];
          default = "rgb";
          description = "子像素排列方式（一般 LCD 为 rgb）。";
        };
        lcdfilter = mkOption {
          type = types.enum [ "none" "default" "light" "legacy" ];
          default = "default";
          description = "LCD 渲染过滤算法。";
        };
      };

      allowBitmaps = mkOption {
        type = types.bool;
        default = false;
        description = "是否允许点阵位图字体（禁用可避免点阵字体造成的模糊或粗糙渲染）。";
      };

      useEmbeddedBitmaps = mkOption {
        type = types.bool;
        default = true;
        description = "是否使用嵌入在矢量字体中的位图（如某些中文字体中的点阵字形）。";
      };
    };

    # Home Manager 联动
    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否将统一字体与 Fontconfig 规则同步应用到 Home Manager 用户环境。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. NixOS 系统级字体配置
      fonts = {
        enableDefaultPackages = true;
        fontDir.enable = cfg.fontDir.enable;
        packages = cfg.packages;
        fontconfig = mkIf cfg.fontconfig.enable {
          enable = true;
          defaultFonts = {
            serif = cfg.fontconfig.defaultFonts.serif;
            sansSerif = cfg.fontconfig.defaultFonts.sansSerif;
            monospace = cfg.fontconfig.defaultFonts.monospace;
            emoji = cfg.fontconfig.defaultFonts.emoji;
          };
          hinting = {
            enable = cfg.fontconfig.hinting.enable;
            style = cfg.fontconfig.hinting.style;
            autohint = cfg.fontconfig.hinting.autohint;
          };
          subpixel = {
            rgba = cfg.fontconfig.subpixel.rgba;
            lcdfilter = cfg.fontconfig.subpixel.lcdfilter;
          };
          allowBitmaps = cfg.fontconfig.allowBitmaps;
          useEmbeddedBitmaps = cfg.fontconfig.useEmbeddedBitmaps;
        };
      };
    }

    # 2. Home Manager 用户级字体配置联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            fonts.fontconfig = mkIf cfg.fontconfig.enable {
              enable = true;
              defaultFonts = {
                serif = cfg.fontconfig.defaultFonts.serif;
                sansSerif = cfg.fontconfig.defaultFonts.sansSerif;
                monospace = cfg.fontconfig.defaultFonts.monospace;
                emoji = cfg.fontconfig.defaultFonts.emoji;
              };
            };
            home.packages = cfg.packages;
          })
        ];
      };
    })
  ]);
}
