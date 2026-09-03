{ cfg, lib }:

let
  inherit (lib) optionalAttrs listToAttrs;

  workspaceFocusBinds = listToAttrs (map (i: {
    name = "Mod+${toString i}";
    value = { focus-workspace = [ i ]; };
  }) [ 1 2 3 4 5 6 7 8 9 ]);

  workspaceMoveBinds = listToAttrs (map (i: {
    name = "Mod+Ctrl+${toString i}";
    value = { move-column-to-workspace = [ i ]; };
  }) [ 1 2 3 4 5 6 7 8 9 ]);

  workspaceShiftMoveBinds = listToAttrs (map (i: {
    name = "Mod+Shift+${toString i}";
    value = { move-column-to-workspace = [ i ]; };
  }) [ 1 2 3 4 5 6 7 8 9 ]);
in
{
  "Mod+Return" = {
    _props.hotkey-overlay-title = "Open a Terminal: ${cfg.terminal}";
    spawn = [ cfg.terminal ];
  };
  "Mod+T" = {
    _props.hotkey-overlay-title = "Open a Terminal: ${cfg.terminal}";
    spawn = [ cfg.terminal ];
  };

  "Mod+Q" = {
    _props.repeat = false;
    close-window = { };
  };

  "Mod+F" = { maximize-column = { }; };
  "Mod+Shift+F" = { fullscreen-window = { }; };
  "Mod+V" = { toggle-window-floating = { }; };
  "Mod+Shift+V" = { switch-focus-between-floating-and-tiling = { }; };
  "Mod+C" = { center-column = { }; };
  "Mod+Ctrl+C" = { center-visible-columns = { }; };

  "Mod+Left" = { focus-column-left = { }; };
  "Mod+Right" = { focus-column-right = { }; };
  "Mod+Up" = { focus-window-up = { }; };
  "Mod+Down" = { focus-window-down = { }; };
  "Mod+H" = { focus-column-left = { }; };
  "Mod+L" = { focus-column-right = { }; };
  "Mod+K" = { focus-window-up = { }; };
  "Mod+J" = { focus-window-down = { }; };

  "Mod+Ctrl+Left" = { move-column-left = { }; };
  "Mod+Ctrl+Right" = { move-column-right = { }; };
  "Mod+Ctrl+Up" = { move-window-up = { }; };
  "Mod+Ctrl+Down" = { move-window-down = { }; };
  "Mod+Ctrl+H" = { move-column-left = { }; };
  "Mod+Ctrl+L" = { move-column-right = { }; };
  "Mod+Ctrl+K" = { move-window-up = { }; };
  "Mod+Ctrl+J" = { move-window-down = { }; };

  "Mod+R" = { switch-preset-column-width = { }; };
  "Mod+Shift+R" = { switch-preset-column-width-back = { }; };
  "Mod+Minus" = { set-column-width = [ "-10%" ]; };
  "Mod+Equal" = { set-column-width = [ "+10%" ]; };
  "Mod+W" = { toggle-column-tabbed-display = { }; };

  "Mod+BracketLeft" = { consume-or-expel-window-left = { }; };
  "Mod+BracketRight" = { consume-or-expel-window-right = { }; };

  "Mod+O" = {
    _props.repeat = false;
    toggle-overview = { };
  };

  "Mod+Shift+Slash" = { show-hotkey-overlay = { }; };
  "Mod+Shift+E" = { quit = { }; };
  "Mod+Escape" = {
    _props.allow-inhibiting = false;
    toggle-keyboard-shortcuts-inhibit = { };
  };

  "Print" = { screenshot = { }; };
  "Ctrl+Print" = { screenshot-screen = { }; };
  "Alt+Print" = { screenshot-window = { }; };

  "Mod+WheelScrollDown" = {
    _props.cooldown-ms = 150;
    focus-workspace-down = { };
  };
  "Mod+WheelScrollUp" = {
    _props.cooldown-ms = 150;
    focus-workspace-up = { };
  };
  "Mod+Ctrl+WheelScrollDown" = {
    _props.cooldown-ms = 150;
    move-column-to-workspace-down = { };
  };
  "Mod+Ctrl+WheelScrollUp" = {
    _props.cooldown-ms = 150;
    move-column-to-workspace-up = { };
  };
  "Mod+WheelScrollRight" = { focus-column-right = { }; };
  "Mod+WheelScrollLeft" = { focus-column-left = { }; };
  "Mod+Ctrl+WheelScrollRight" = { move-column-right = { }; };
  "Mod+Ctrl+WheelScrollLeft" = { move-column-left = { }; };

  "XF86AudioRaiseVolume" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0" ];
  };
  "XF86AudioLowerVolume" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" ];
  };
  "XF86AudioMute" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ];
  };
  "XF86AudioMicMute" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" ];
  };
  "XF86AudioPlay" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "playerctl play-pause" ];
  };
  "XF86AudioNext" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "playerctl next" ];
  };
  "XF86AudioPrev" = {
    _props.allow-when-locked = true;
    spawn-sh = [ "playerctl previous" ];
  };
  "XF86MonBrightnessUp" = {
    _props.allow-when-locked = true;
    spawn = [ "brightnessctl" "--class=backlight" "set" "+10%" ];
  };
  "XF86MonBrightnessDown" = {
    _props.allow-when-locked = true;
    spawn = [ "brightnessctl" "--class=backlight" "set" "10%-" ];
  };
}
// workspaceFocusBinds
// workspaceMoveBinds
// workspaceShiftMoveBinds
// (optionalAttrs (cfg.fileManager.enable && cfg.fileManager.keybind != "" && cfg.fileManager.command != "") {
  "${cfg.fileManager.keybind}" = {
    _props.hotkey-overlay-title = "Open File Manager";
    spawn-sh = [ cfg.fileManager.command ];
  };
})
