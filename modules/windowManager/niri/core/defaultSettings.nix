{ cfg, lib }:

let
  inherit (lib)
    optionalAttrs
    mapAttrsToList
    isAttrs
    isList
    isString
    ;

  binds = import ./binds.nix { inherit cfg lib; };

  # 将用户配置的 outputs 映射为 KDL output 节点
  outputsNodes = mapAttrsToList (name: outCfg: {
    output = {
      _args = [ name ];
    }
    // (optionalAttrs (!outCfg.enable) { off = { }; })
    // (optionalAttrs (outCfg.enable && outCfg.mode != null) { mode = outCfg.mode; })
    // (optionalAttrs (outCfg.enable && outCfg.scale != null) { scale = outCfg.scale; })
    // (optionalAttrs (outCfg.enable && outCfg.transform != "normal") { transform = outCfg.transform; })
    // (optionalAttrs (outCfg.enable && outCfg.position != null) {
      position = {
        _props = {
          x = outCfg.position.x;
          y = outCfg.position.y;
        };
      };
    });
  }) cfg.outputs;

  # 将 autostart / extraSpawn 转换为 spawn-at-startup / spawn-sh-at-startup 节点
  autostartNodes = map (cmd:
    if isList cmd then
      { spawn-at-startup._args = cmd; }
    else if isString cmd then
      if lib.hasInfix " " cmd || lib.hasInfix "|" cmd || lib.hasInfix ";" cmd || lib.hasInfix "&" cmd then
        { spawn-sh-at-startup._args = [ cmd ]; }
      else
        { spawn-at-startup._args = [ cmd ]; }
    else
      throw "niri autostart: expected string or list of strings"
  ) (lib.unique (cfg.autostart ++ cfg.extraSpawn));

in
{
  screenshot-path = if cfg.screenshotPath != null then cfg.screenshotPath else { _args = [ null ]; };
}
// (optionalAttrs cfg.preferNoCsd { prefer-no-csd = { }; })
// (optionalAttrs cfg.hotkeyOverlay.skipAtStartup {
  hotkey-overlay.skip-at-startup = { };
})
// (optionalAttrs cfg.virtualization.enable {
  debug.disable-cursor-plane = { };
})
// {
  input = {
    keyboard = {
      xkb = cfg.input.keyboard.xkb;
    } // (optionalAttrs cfg.input.keyboard.numlock {
      numlock = { };
    });

    touchpad = { }
      // (optionalAttrs cfg.input.touchpad.tap { tap = { }; })
      // (optionalAttrs cfg.input.touchpad.naturalScroll { natural-scroll = { }; })
      // (optionalAttrs (cfg.input.touchpad.accelSpeed != null) {
        accel-speed = cfg.input.touchpad.accelSpeed;
      })
      // (optionalAttrs (cfg.input.touchpad.accelProfile != null) {
        accel-profile = cfg.input.touchpad.accelProfile;
      });

    mouse = { }
      // (optionalAttrs cfg.input.mouse.naturalScroll { natural-scroll = { }; })
      // (optionalAttrs (cfg.input.mouse.accelSpeed != null) {
        accel-speed = cfg.input.mouse.accelSpeed;
      })
      // (optionalAttrs (cfg.input.mouse.accelProfile != null) {
        accel-profile = cfg.input.mouse.accelProfile;
      });
  }
  // (optionalAttrs cfg.input.warpMouseToFocus { warp-mouse-to-focus = { }; })
  // (optionalAttrs cfg.input.focusFollowsMouse.enable {
    focus-follows-mouse._props.max-scroll-amount = cfg.input.focusFollowsMouse.maxScrollAmount;
  });

  layout = {
    gaps = cfg.layout.gaps;
    center-focused-column = cfg.layout.centerFocusedColumn;
    preset-column-widths._children = map (p: { proportion = p; }) cfg.layout.presetColumnWidths;
    default-column-width = cfg.layout.defaultColumnWidth;

    focus-ring = if cfg.layout.focusRing.enable then {
      width = cfg.layout.focusRing.width;
      active-color = cfg.layout.focusRing.activeColor;
      inactive-color = cfg.layout.focusRing.inactiveColor;
    } else {
      off = { };
    };

    border = if cfg.layout.border.enable then {
      width = cfg.layout.border.width;
      active-color = cfg.layout.border.activeColor;
      inactive-color = cfg.layout.border.inactiveColor;
    } else {
      off = { };
    };

    shadow = if cfg.layout.shadow.enable then {
      softness = cfg.layout.shadow.softness;
      spread = cfg.layout.shadow.spread;
      offset._props = {
        x = cfg.layout.shadow.offset.x;
        y = cfg.layout.shadow.offset.y;
      };
      color = cfg.layout.shadow.color;
    } else {
      off = { };
    };
  };

  animations = if cfg.animations.enable then (
    optionalAttrs (cfg.animations.slowdown != null) {
      slowdown = cfg.animations.slowdown;
    }
  ) else {
    off = { };
  };

  cursor = {
    xcursor-theme = cfg.cursor.theme;
    xcursor-size = cfg.cursor.size;
  };

  xwayland-satellite = if cfg.xwayland.enable then (
    optionalAttrs (cfg.xwayland.package != null) {
      path = "${cfg.xwayland.package}/bin/xwayland-satellite";
    }
  ) else {
    off = { };
  };

  binds = binds;

  _children = outputsNodes ++ autostartNodes;
}
