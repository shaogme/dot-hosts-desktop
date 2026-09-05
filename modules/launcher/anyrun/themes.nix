{
  pkgs ? null,
  lib,
  config,
  ...
}:

with lib;

let
  cfg = config.desktop.launcher.anyrun;
  paletteLib = import ../../theme/palette.nix { inherit lib; };
  # 优先使用用户通过 desktop.theme.palette 配置的调色板，回退至 palette.nix 默认
  paletteDark = (config.desktop.theme.palette.dark or paletteLib.palettes.dark);
  fallbackCss = paletteLib.toCss paletteDark;

  baseCssRules = ''
    * {
      font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Symbols Nerd Font", sans-serif;
    }

    window {
      background: transparent;
    }

    box.main,
    #main {
      padding: 10px 12px;
      margin: 0px;
      border-radius: 16px;
      border: 1px solid @border-color;
      background-color: @background;
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.15),
        inset 0 -1px 0 rgba(0, 0, 0, 0.2),
        0 0 0 1px rgba(255, 255, 255, 0.05),
        0 4px 16px rgba(0, 0, 0, 0.2),
        0 12px 32px rgba(0, 0, 0, 0.35),
        0 24px 64px rgba(0, 0, 0, 0.5);
    }

    text,
    entry {
      min-height: 40px;
      padding: 8px 14px;
      border-radius: 12px;
      background-color: @background-card;
      border: 1px solid @border-color;
      color: @foreground;
      font-size: 14px;
      box-shadow: none;
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }

    text:focus,
    entry:focus {
      border-color: @accent;
      box-shadow: 0 0 12px @glow-color;
    }

    .matches,
    box.matches,
    list.matches {
      background-color: transparent;
      border-radius: 12px;
      margin-top: 6px;
    }

    box.plugin {
      margin-top: 4px;
    }

    box.plugin:first-child {
      margin-top: 0px;
    }

    box.plugin.info {
      min-width: 100px;
      padding: 2px 6px;
    }

    list.plugin {
      background-color: transparent;
    }

    /* 重置内部容器多余间距，防止 Anyrun 嵌套类名叠加 padding/margin */
    box.match,
    box.text-fields,
    image.match {
      padding: 0px;
      margin: 0px;
    }

    label.match.title,
    label.title {
      color: @foreground;
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 1px;
      padding: 0px;
    }

    label.match.description,
    label.match.desc,
    label.description,
    label.desc {
      font-size: 11px;
      color: @foreground-muted;
      padding: 0px;
    }

    label.plugin.info {
      font-size: 12px;
      font-weight: 700;
      color: @accent;
    }

    /* 仅在 ListBoxRow 层面施加单层 padding/margin 与交互动画 */
    row.match,
    list.plugin > row,
    list.matches > row {
      padding: 6px 10px;
      border-radius: 10px;
      background: transparent;
      margin: 1px 0;
      border: 1px solid transparent;
      min-height: 38px;
      transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
    }

    row.match:hover,
    list.plugin > row:hover,
    list.matches > row:hover {
      background: @hover-bg;
    }

    row.match:selected,
    list.plugin > row:selected,
    list.matches > row:selected,
    row.match:focus {
      border-left: 3px solid @accent;
      background: @selected-bg;
      color: #ffffff;
    }

    row.match:selected label.match,
    list.plugin > row:selected label.match,
    row.match:selected label.title,
    list.plugin > row:selected label.title {
      color: #ffffff;
    }

    row.match:selected label.match.description,
    list.plugin > row:selected label.match.description,
    row.match:selected label.desc,
    list.plugin > row:selected label.desc {
      color: @foreground;
    }

    scrollbar {
      background-color: transparent;
    }

    scrollbar slider {
      background-color: rgba(255, 255, 255, 0.1);
      border-radius: 6px;
      min-width: 6px;
      min-height: 6px;
      transition: background-color 0.15s ease;
    }

    scrollbar slider:hover {
      background-color: rgba(255, 255, 255, 0.2);
    }
  '';

  defaultTheme = {
    style = ''
      /* 统一调色板 fallback (palette.dark)：由 modules/theme/palette.nix 提供 */
      ${fallbackCss}
      /* 动态覆盖：由 desktop.theme 在 $XDG_RUNTIME_DIR/desktop-theme/colors.css 及 $XDG_CONFIG_HOME/anyrun/colors.css 生成，Anyrun 守护进程重启生效 */
      /* 若 colors.css 存在则覆盖上方 fallback；缺失则静默回退 */
      @import "colors.css";

      ${baseCssRules}
    '';
    extraPackages = [ ];
  };

  # 静态独立预设（脱离全局切换锁定特定配色的场景）
  presetPalettes = {
    catppuccin-mocha = {
      accent = "#89b4fa";
      background = "rgba(20, 20, 28, 0.85)";
      backgroundCard = "rgba(30, 30, 42, 0.88)";
      border = "rgba(255, 255, 255, 0.08)";
      foreground = "#cdd6f4";
      foregroundMuted = "#a6adc8";
      foregroundDim = "#6c7086";
      selectedBg = "rgba(137, 180, 250, 0.15)";
      activeBorder = "#89b4fa";
      glow = "rgba(137, 180, 250, 0.35)";
      hoverBg = "rgba(255, 255, 255, 0.08)";
      hoverBgLight = "rgba(255, 255, 255, 0.12)";
      warning = "#f9e2af";
      critical = "#f38ba8";
    };
    tokyo-night = {
      accent = "#7aa2f7";
      background = "rgba(26, 27, 38, 0.88)";
      backgroundCard = "rgba(22, 22, 30, 0.75)";
      border = "rgba(192, 202, 245, 0.12)";
      foreground = "#c0caf5";
      foregroundMuted = "#9aa5ce";
      foregroundDim = "#565f89";
      selectedBg = "rgba(122, 162, 247, 0.18)";
      activeBorder = "#7aa2f7";
      glow = "rgba(122, 162, 247, 0.35)";
      hoverBg = "rgba(255, 255, 255, 0.08)";
      hoverBgLight = "rgba(255, 255, 255, 0.12)";
      warning = "#e0af68";
      critical = "#f7768e";
    };
    nord = {
      accent = "#88c0d0";
      background = "rgba(46, 52, 64, 0.88)";
      backgroundCard = "rgba(36, 41, 51, 0.75)";
      border = "rgba(236, 239, 244, 0.12)";
      foreground = "#eceff4";
      foregroundMuted = "#d8dee9";
      foregroundDim = "#4c566a";
      selectedBg = "rgba(136, 192, 208, 0.18)";
      activeBorder = "#88c0d0";
      glow = "rgba(136, 192, 208, 0.35)";
      hoverBg = "rgba(255, 255, 255, 0.08)";
      hoverBgLight = "rgba(255, 255, 255, 0.12)";
      warning = "#ebcb8b";
      critical = "#bf616a";
    };
  };

  makePresetTheme = p: {
    style = ''
      ${paletteLib.toCss p}
      ${baseCssRules}
    '';
    extraPackages = [ ];
  };

  themes = {
    default-theme = defaultTheme;
    default = defaultTheme;
    catppuccin-mocha = makePresetTheme presetPalettes.catppuccin-mocha;
    tokyo-night = makePresetTheme presetPalettes.tokyo-night;
    nord = makePresetTheme presetPalettes.nord;
  };
in
themes // {
  inherit defaultTheme presetPalettes;
  palettes = presetPalettes // { default-theme = presetPalettes.catppuccin-mocha; };
  generateCss = { themeName ? "default-theme", extraCss ? "" }:
    let
      themeObj = themes.${themeName} or themes.default-theme;
    in
    themeObj.style + optionalString (extraCss != "") "\n${extraCss}";
}
