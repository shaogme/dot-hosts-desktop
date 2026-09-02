let
  palettes = {
    default-theme = {
      accent = "#89b4fa";
      bg = "rgba(20, 20, 28, 0.85)";
      cardBg = "rgba(30, 30, 42, 0.88)";
      border = "rgba(255, 255, 255, 0.08)";
      text = "#cdd6f4";
      desc = "#a6adc8";
      selectedBg = "rgba(137, 180, 250, 0.15)";
      glow = "rgba(137, 180, 250, 0.35)";
      hoverBg = "rgba(255, 255, 255, 0.08)";
      warning = "#f9e2af";
      critical = "#f38ba8";
    };
    catppuccin-mocha = {
      accent = "#89b4fa";
      bg = "rgba(20, 20, 28, 0.85)";
      cardBg = "rgba(30, 30, 42, 0.88)";
      border = "rgba(255, 255, 255, 0.08)";
      text = "#cdd6f4";
      desc = "#a6adc8";
      selectedBg = "rgba(137, 180, 250, 0.15)";
      glow = "rgba(137, 180, 250, 0.35)";
      hoverBg = "rgba(255, 255, 255, 0.08)";
      warning = "#f9e2af";
      critical = "#f38ba8";
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
      hoverBg = "rgba(255, 255, 255, 0.08)";
      warning = "#e0af68";
      critical = "#f7768e";
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
      hoverBg = "rgba(255, 255, 255, 0.08)";
      warning = "#ebcb8b";
      critical = "#bf616a";
    };
  };

  generateCss = { themeName ? "default-theme", extraCss ? "" }:
    let
      theme = palettes.${themeName} or palettes.default-theme or palettes.catppuccin-mocha;
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
      @define-color hover-bg ${theme.hoverBg};
      @define-color warning ${theme.warning};
      @define-color critical ${theme.critical};

      * {
        font-family: "Geist", "TsangerJinKai04", "Maple Mono NF CN", "Symbols Nerd Font", sans-serif;
        transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
      }

      window {
        background: transparent;
      }

      box.main,
      #main {
        padding: 12px;
        margin: 10px;
        border-radius: 16px;
        border: 1px solid @border-color;
        background-color: @bg-color;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.45);
      }

      text,
      entry {
        min-height: 42px;
        padding: 8px 14px;
        border-radius: 12px;
        background-color: @card-bg;
        border: 1px solid @border-color;
        color: @fg-color;
        font-size: 14px;
        box-shadow: none;
      }

      text:focus,
      entry:focus {
        border-color: @accent;
        box-shadow: 0 0 12px @glow-color;
      }

      .matches,
      list.matches {
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
        min-width: 130px;
        padding: 4px 8px;
      }

      list.plugin {
        background-color: transparent;
      }

      label.match {
        color: @fg-color;
        font-size: 13px;
        font-weight: 600;
      }

      label.match.description,
      label.match.desc {
        font-size: 11px;
        color: @desc-color;
      }

      label.plugin.info {
        font-size: 12px;
        font-weight: 700;
        color: @accent;
      }

      .match,
      row.match,
      list.match {
        padding: 8px 12px;
        border-radius: 10px;
        background: transparent;
        margin: 2px 0;
        border: 1px solid transparent;
      }

      .match:hover,
      row.match:hover {
        background: @hover-bg;
      }

      .match:selected,
      row.match:selected,
      .match:focus {
        border-left: 3px solid @accent;
        background: @selected-bg;
        color: #ffffff;
      }

      .match:selected label.match,
      row.match:selected label.match {
        color: #ffffff;
      }

      .match:selected label.match.description,
      row.match:selected label.match.description {
        color: @fg-color;
      }

      scrollbar {
        background-color: transparent;
      }

      scrollbar slider {
        background-color: rgba(255, 255, 255, 0.1);
        border-radius: 6px;
        min-width: 6px;
        min-height: 6px;
      }

      scrollbar slider:hover {
        background-color: rgba(255, 255, 255, 0.2);
      }

      ${extraCss}
    '';
in
{
  inherit palettes generateCss;
}
