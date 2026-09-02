{
  # 预设主题配置集合
  presets = {
    "default" = { };

    "catppuccin-mocha" = {
      mgr = {
        cwd = { fg = "#94e2d5"; };
        find_keyword = { fg = "#f9e2af"; italic = true; };
        find_position = { fg = "#f5c2e7"; italic = true; };
        marker_selected = { fg = "#a6e3a1"; bg = "#a6e3a1"; };
        marker_copied = { fg = "#f9e2af"; bg = "#f9e2af"; };
        marker_cut = { fg = "#f38ba8"; bg = "#f38ba8"; };
        border_symbol = "│";
        border_style = { fg = "#585b70"; };
      };
      tabs = {
        active = { fg = "#1e1e2e"; bg = "#89b4fa"; };
        inactive = { fg = "#cdd6f4"; bg = "#313244"; };
      };
      mode = {
        normal_main = { fg = "#1e1e2e"; bg = "#89b4fa"; bold = true; };
        normal_alt = { fg = "#89b4fa"; bg = "#313244"; };
        select_main = { fg = "#1e1e2e"; bg = "#a6e3a1"; bold = true; };
        select_alt = { fg = "#a6e3a1"; bg = "#313244"; };
        unset_main = { fg = "#1e1e2e"; bg = "#f38ba8"; bold = true; };
        unset_alt = { fg = "#f38ba8"; bg = "#313244"; };
      };
      indicator = {
        current = { fg = "#1e1e2e"; bg = "#cba6f7"; };
        preview = { underline = true; };
      };
      status = {
        sep_left = { open = ""; close = ""; };
        sep_right = { open = ""; close = ""; };
        progress_label = { fg = "#ffffff"; bold = true; };
        progress_normal = { fg = "#89b4fa"; bg = "#313244"; };
        progress_error = { fg = "#f38ba8"; bg = "#313244"; };
        perm_type = { fg = "#89b4fa"; };
        perm_read = { fg = "#f9e2af"; };
        perm_write = { fg = "#f38ba8"; };
        perm_exec = { fg = "#a6e3a1"; };
        perm_sep = { fg = "#6c7086"; };
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
        find_keyword = { fg = "#e0af68"; italic = true; };
        find_position = { fg = "#bb9af7"; italic = true; };
        marker_selected = { fg = "#9ece6a"; bg = "#9ece6a"; };
        marker_copied = { fg = "#e0af68"; bg = "#e0af68"; };
        marker_cut = { fg = "#f7768e"; bg = "#f7768e"; };
        border_symbol = "│";
        border_style = { fg = "#414868"; };
      };
      tabs = {
        active = { fg = "#1a1b26"; bg = "#7aa2f7"; };
        inactive = { fg = "#a9b1d6"; bg = "#24283b"; };
      };
      mode = {
        normal_main = { fg = "#1a1b26"; bg = "#7aa2f7"; bold = true; };
        normal_alt = { fg = "#7aa2f7"; bg = "#24283b"; };
        select_main = { fg = "#1a1b26"; bg = "#9ece6a"; bold = true; };
        select_alt = { fg = "#9ece6a"; bg = "#24283b"; };
        unset_main = { fg = "#1a1b26"; bg = "#f7768e"; bold = true; };
        unset_alt = { fg = "#f7768e"; bg = "#24283b"; };
      };
      indicator = {
        current = { fg = "#1a1b26"; bg = "#bb9af7"; };
        preview = { underline = true; };
      };
      status = {
        sep_left = { open = ""; close = ""; };
        sep_right = { open = ""; close = ""; };
        progress_label = { fg = "#c0caf5"; bold = true; };
        progress_normal = { fg = "#7aa2f7"; bg = "#24283b"; };
        progress_error = { fg = "#f7768e"; bg = "#24283b"; };
        perm_type = { fg = "#7aa2f7"; };
        perm_read = { fg = "#e0af68"; };
        perm_write = { fg = "#f7768e"; };
        perm_exec = { fg = "#9ece6a"; };
        perm_sep = { fg = "#565f89"; };
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
        find_keyword = { fg = "#ebcb8b"; italic = true; };
        find_position = { fg = "#b48ead"; italic = true; };
        marker_selected = { fg = "#a3be8c"; bg = "#a3be8c"; };
        marker_copied = { fg = "#ebcb8b"; bg = "#ebcb8b"; };
        marker_cut = { fg = "#bf616a"; bg = "#bf616a"; };
        border_symbol = "│";
        border_style = { fg = "#4c566a"; };
      };
      tabs = {
        active = { fg = "#2e3440"; bg = "#88c0d0"; };
        inactive = { fg = "#d8dee9"; bg = "#3b4252"; };
      };
      mode = {
        normal_main = { fg = "#2e3440"; bg = "#88c0d0"; bold = true; };
        normal_alt = { fg = "#88c0d0"; bg = "#3b4252"; };
        select_main = { fg = "#2e3440"; bg = "#a3be8c"; bold = true; };
        select_alt = { fg = "#a3be8c"; bg = "#3b4252"; };
        unset_main = { fg = "#2e3440"; bg = "#bf616a"; bold = true; };
        unset_alt = { fg = "#bf616a"; bg = "#3b4252"; };
      };
      indicator = {
        current = { fg = "#2e3440"; bg = "#81a1c1"; };
        preview = { underline = true; };
      };
      status = {
        sep_left = { open = ""; close = ""; };
        sep_right = { open = ""; close = ""; };
        progress_label = { fg = "#eceff4"; bold = true; };
        progress_normal = { fg = "#88c0d0"; bg = "#3b4252"; };
        progress_error = { fg = "#bf616a"; bg = "#3b4252"; };
        perm_type = { fg = "#88c0d0"; };
        perm_read = { fg = "#ebcb8b"; };
        perm_write = { fg = "#bf616a"; };
        perm_exec = { fg = "#a3be8c"; };
        perm_sep = { fg = "#4c566a"; };
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
