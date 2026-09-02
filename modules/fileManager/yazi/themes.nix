{
  # 预设主题配置集合
  presets = {
    "default" = { };

    "catppuccin-mocha" = {
      mgr = {
        cwd = { fg = "#94e2d5"; };
        hovered = { fg = "#1e1e2e"; bg = "#cba6f7"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#f9e2af"; italic = true; };
        find_position = { fg = "#f5c2e7"; italic = true; };
        marker_selected = { fg = "#a6e3a1"; bg = "#a6e3a1"; };
        marker_copied = { fg = "#f9e2af"; bg = "#f9e2af"; };
        marker_cut = { fg = "#f38ba8"; bg = "#f38ba8"; };
        tab_active = { fg = "#1e1e2e"; bg = "#89b4fa"; };
        tab_inactive = { fg = "#cdd6f4"; bg = "#313244"; };
        border_symbol = "│";
        border_style = { fg = "#585b70"; };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#313244"; bg = "#313244"; };
        mode_normal = { fg = "#1e1e2e"; bg = "#89b4fa"; bold = true; };
        mode_select = { fg = "#1e1e2e"; bg = "#a6e3a1"; bold = true; };
        mode_unset = { fg = "#1e1e2e"; bg = "#f38ba8"; bold = true; };
        progress_label = { fg = "#ffffff"; bold = true; };
        progress_normal = { fg = "#89b4fa"; bg = "#313244"; };
        progress_error = { fg = "#f38ba8"; bg = "#313244"; };
        permissions_t = { fg = "#89b4fa"; };
        permissions_r = { fg = "#f9e2af"; };
        permissions_w = { fg = "#f38ba8"; };
        permissions_x = { fg = "#a6e3a1"; };
        permissions_s = { fg = "#6c7086"; };
      };
      filetype = {
        rules = [
          { fg = "#7ad9e5"; mime = "image/*"; }
          { fg = "#f3d398"; mime = "video/*"; }
          { fg = "#f3d398"; mime = "audio/*"; }
          { fg = "#cd9efc"; mime = "application/zip"; }
          { fg = "#cd9efc"; mime = "application/x-tar"; }
          { fg = "#cd9efc"; mime = "application/x-bzip*"; }
          { fg = "#cd9efc"; mime = "application/x-7z-compressed"; }
          { fg = "#cd9efc"; mime = "application/x-rar"; }
          { fg = "#a6e3a1"; mime = "application/pdf"; }
          { fg = "#89b4fa"; mime = "application/x-sh"; }
        ];
      };
    };

    "tokyo-night" = {
      mgr = {
        cwd = { fg = "#7dcfff"; };
        hovered = { fg = "#1a1b26"; bg = "#bb9af7"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#e0af68"; italic = true; };
        find_position = { fg = "#bb9af7"; italic = true; };
        marker_selected = { fg = "#9ece6a"; bg = "#9ece6a"; };
        marker_copied = { fg = "#e0af68"; bg = "#e0af68"; };
        marker_cut = { fg = "#f7768e"; bg = "#f7768e"; };
        tab_active = { fg = "#1a1b26"; bg = "#7aa2f7"; };
        tab_inactive = { fg = "#a9b1d6"; bg = "#24283b"; };
        border_symbol = "│";
        border_style = { fg = "#414868"; };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#24283b"; bg = "#24283b"; };
        mode_normal = { fg = "#1a1b26"; bg = "#7aa2f7"; bold = true; };
        mode_select = { fg = "#1a1b26"; bg = "#9ece6a"; bold = true; };
        mode_unset = { fg = "#1a1b26"; bg = "#f7768e"; bold = true; };
        progress_label = { fg = "#c0caf5"; bold = true; };
        progress_normal = { fg = "#7aa2f7"; bg = "#24283b"; };
        progress_error = { fg = "#f7768e"; bg = "#24283b"; };
        permissions_t = { fg = "#7aa2f7"; };
        permissions_r = { fg = "#e0af68"; };
        permissions_w = { fg = "#f7768e"; };
        permissions_x = { fg = "#9ece6a"; };
        permissions_s = { fg = "#565f89"; };
      };
      filetype = {
        rules = [
          { fg = "#7dcfff"; mime = "image/*"; }
          { fg = "#e0af68"; mime = "video/*"; }
          { fg = "#e0af68"; mime = "audio/*"; }
          { fg = "#bb9af7"; mime = "application/zip"; }
          { fg = "#bb9af7"; mime = "application/x-tar"; }
          { fg = "#9ece6a"; mime = "application/pdf"; }
          { fg = "#7aa2f7"; mime = "application/x-sh"; }
        ];
      };
    };

    "nord" = {
      mgr = {
        cwd = { fg = "#88c0d0"; };
        hovered = { fg = "#2e3440"; bg = "#81a1c1"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#ebcb8b"; italic = true; };
        find_position = { fg = "#b48ead"; italic = true; };
        marker_selected = { fg = "#a3be8c"; bg = "#a3be8c"; };
        marker_copied = { fg = "#ebcb8b"; bg = "#ebcb8b"; };
        marker_cut = { fg = "#bf616a"; bg = "#bf616a"; };
        tab_active = { fg = "#2e3440"; bg = "#88c0d0"; };
        tab_inactive = { fg = "#d8dee9"; bg = "#3b4252"; };
        border_symbol = "│";
        border_style = { fg = "#4c566a"; };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#3b4252"; bg = "#3b4252"; };
        mode_normal = { fg = "#2e3440"; bg = "#88c0d0"; bold = true; };
        mode_select = { fg = "#2e3440"; bg = "#a3be8c"; bold = true; };
        mode_unset = { fg = "#2e3440"; bg = "#bf616a"; bold = true; };
        progress_label = { fg = "#eceff4"; bold = true; };
        progress_normal = { fg = "#88c0d0"; bg = "#3b4252"; };
        progress_error = { fg = "#bf616a"; bg = "#3b4252"; };
        permissions_t = { fg = "#88c0d0"; };
        permissions_r = { fg = "#ebcb8b"; };
        permissions_w = { fg = "#bf616a"; };
        permissions_x = { fg = "#a3be8c"; };
        permissions_s = { fg = "#4c566a"; };
      };
      filetype = {
        rules = [
          { fg = "#88c0d0"; mime = "image/*"; }
          { fg = "#ebcb8b"; mime = "video/*"; }
          { fg = "#ebcb8b"; mime = "audio/*"; }
          { fg = "#b48ead"; mime = "application/zip"; }
          { fg = "#a3be8c"; mime = "application/pdf"; }
          { fg = "#81a1c1"; mime = "application/x-sh"; }
        ];
      };
    };
  };
}
