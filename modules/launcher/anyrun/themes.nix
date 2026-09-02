let
  palettes = {
    catppuccin-mocha = {
      accent = "#89b4fa";
      bg = "rgba(30, 30, 46, 0.88)";
      cardBg = "rgba(24, 24, 37, 0.75)";
      border = "rgba(205, 214, 244, 0.12)";
      text = "#cdd6f4";
      desc = "#a6adc8";
      selectedBg = "rgba(137, 180, 250, 0.18)";
      glow = "rgba(137, 180, 250, 0.35)";
    };
    tokyo-night = {
      accent = "#7aa2f7";
      bg = "rgba(26, 27, 38, 0.88)";
      cardBg = "rgba(22, 22, 30, 0.75)";
      border = "rgba(192, 202, 245, 0.12)";
      text = "#c0caf5";
      desc = "#9aa5ce";
      selectedBg = "rgba(122, 162, 247, 0.18)";
      glow = "rgba(122, 162, 247, 0.35)";
    };
    nord = {
      accent = "#88c0d0";
      bg = "rgba(46, 52, 64, 0.88)";
      cardBg = "rgba(36, 41, 51, 0.75)";
      border = "rgba(236, 239, 244, 0.12)";
      text = "#eceff4";
      desc = "#d8dee9";
      selectedBg = "rgba(136, 192, 208, 0.18)";
      glow = "rgba(136, 192, 208, 0.35)";
    };
  };

  generateCss = { themeName ? "catppuccin-mocha", extraCss ? "" }:
    let
      theme = palettes.${themeName} or palettes.catppuccin-mocha;
    in
    ''
      @define-color accent ${theme.accent};
      @define-color bg-color ${theme.bg};
      @define-color card-bg ${theme.cardBg};
      @define-color border-color ${theme.border};
      @define-color fg-color ${theme.text};
      @define-color desc-color ${theme.desc};
      @define-color selected-bg ${theme.selectedBg};
      @define-color glow-color ${theme.glow};

      * {
        font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Noto Sans CJK SC", sans-serif;
        transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
      }

      window {
        background: transparent;
      }

      box.main {
        padding: 12px;
        margin: 10px;
        border-radius: 18px;
        border: 1px solid @border-color;
        background-color: @bg-color;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.38);
      }

      text {
        min-height: 42px;
        padding: 8px 14px;
        border-radius: 12px;
        background-color: @card-bg;
        border: 1px solid @border-color;
        color: @fg-color;
        font-size: 15px;
        box-shadow: none;
      }

      text:focus {
        border-color: @accent;
        box-shadow: 0 0 14px @glow-color;
      }

      .matches {
        background-color: transparent;
        border-radius: 12px;
        margin-top: 8px;
      }

      box.plugin {
        margin-top: 6px;
      }

      box.plugin:first-child {
        margin-top: 0px;
      }

      box.plugin.info {
        min-width: 140px;
        padding: 4px 8px;
      }

      list.plugin {
        background-color: transparent;
      }

      label.match {
        color: @fg-color;
        font-size: 14px;
        font-weight: 500;
      }

      label.match.description {
        font-size: 12px;
        color: @desc-color;
      }

      label.plugin.info {
        font-size: 13px;
        font-weight: 600;
        color: @accent;
      }

      .match {
        padding: 8px 12px;
        border-radius: 10px;
        background: transparent;
        margin: 2px 0;
      }

      .match:hover {
        background: rgba(255, 255, 255, 0.05);
      }

      .match:selected {
        border-left: 4px solid @accent;
        background: @selected-bg;
        color: #ffffff;
      }

      ${extraCss}
    '';
in
{
  inherit palettes generateCss;
}
