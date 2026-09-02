{ cfg, lib }:

let
  inline = lib.generators.mkLuaInline;
in
[
  # 常用核心应用快捷键 (终端、文件管理器)
  { _args = [ (inline ''"SUPER + Return"'') (inline ''hl.dsp.exec_cmd("${cfg.terminal}")'') ]; }
]
++ lib.optional (cfg ? fileManager && cfg.fileManager.enable && cfg.fileManager.keybind != "") {
  _args = [ (inline ''"${cfg.fileManager.keybind}"'') (inline ''hl.dsp.exec_cmd("${cfg.fileManager.command}")'') ];
}
++ [
  { _args = [ (inline ''"SUPER + Q"'') (inline ''hl.dsp.window.close()'') ]; }
  { _args = [ (inline ''"SUPER + V"'') (inline ''hl.dsp.window.float({ action = "toggle" })'') ]; }
  { _args = [ (inline ''"SUPER + F"'') (inline ''hl.dsp.window.fullscreen()'') ]; }

  # 窗口焦点移动
  { _args = [ (inline ''"SUPER + left"'') (inline ''hl.dsp.focus({ direction = "left" })'') ]; }
  { _args = [ (inline ''"SUPER + right"'') (inline ''hl.dsp.focus({ direction = "right" })'') ]; }
  { _args = [ (inline ''"SUPER + up"'') (inline ''hl.dsp.focus({ direction = "up" })'') ]; }
  { _args = [ (inline ''"SUPER + down"'') (inline ''hl.dsp.focus({ direction = "down" })'') ]; }
  { _args = [ (inline ''"SUPER + h"'') (inline ''hl.dsp.focus({ direction = "left" })'') ]; }
  { _args = [ (inline ''"SUPER + l"'') (inline ''hl.dsp.focus({ direction = "right" })'') ]; }
  { _args = [ (inline ''"SUPER + k"'') (inline ''hl.dsp.focus({ direction = "up" })'') ]; }
  { _args = [ (inline ''"SUPER + j"'') (inline ''hl.dsp.focus({ direction = "down" })'') ]; }

  # 工作区切换 (1-9)
  { _args = [ (inline ''"SUPER + 1"'') (inline ''hl.dsp.focus({ workspace = 1 })'') ]; }
  { _args = [ (inline ''"SUPER + 2"'') (inline ''hl.dsp.focus({ workspace = 2 })'') ]; }
  { _args = [ (inline ''"SUPER + 3"'') (inline ''hl.dsp.focus({ workspace = 3 })'') ]; }
  { _args = [ (inline ''"SUPER + 4"'') (inline ''hl.dsp.focus({ workspace = 4 })'') ]; }
  { _args = [ (inline ''"SUPER + 5"'') (inline ''hl.dsp.focus({ workspace = 5 })'') ]; }
  { _args = [ (inline ''"SUPER + 6"'') (inline ''hl.dsp.focus({ workspace = 6 })'') ]; }
  { _args = [ (inline ''"SUPER + 7"'') (inline ''hl.dsp.focus({ workspace = 7 })'') ]; }
  { _args = [ (inline ''"SUPER + 8"'') (inline ''hl.dsp.focus({ workspace = 8 })'') ]; }
  { _args = [ (inline ''"SUPER + 9"'') (inline ''hl.dsp.focus({ workspace = 9 })'') ]; }

  # 移动活动窗口至工作区
  { _args = [ (inline ''"SUPER + SHIFT + 1"'') (inline ''hl.dsp.window.move({ workspace = 1 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 2"'') (inline ''hl.dsp.window.move({ workspace = 2 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 3"'') (inline ''hl.dsp.window.move({ workspace = 3 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 4"'') (inline ''hl.dsp.window.move({ workspace = 4 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 5"'') (inline ''hl.dsp.window.move({ workspace = 5 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 6"'') (inline ''hl.dsp.window.move({ workspace = 6 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 7"'') (inline ''hl.dsp.window.move({ workspace = 7 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 8"'') (inline ''hl.dsp.window.move({ workspace = 8 })'') ]; }
  { _args = [ (inline ''"SUPER + SHIFT + 9"'') (inline ''hl.dsp.window.move({ workspace = 9 })'') ]; }

  # 鼠标拖动与调整大小
  { _args = [ (inline ''"SUPER + mouse:272"'') (inline ''hl.dsp.window.drag()'') { mouse = true; } ]; }
  { _args = [ (inline ''"SUPER + mouse:273"'') (inline ''hl.dsp.window.resize()'') { mouse = true; } ]; }
]
