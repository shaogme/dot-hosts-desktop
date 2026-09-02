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
        background-color: @bg-color;
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
        background-color: @card-bg;
        border: 1px solid @border-color;
        color: @fg-color;
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
        color: @fg-color;
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
        color: @desc-color;
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
        transition: background-color 0.15s ease;
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
