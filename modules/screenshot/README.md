# 截屏软件模块 (desktop.screenshot)

本模块旨在为 NixOS 系统提供现代化、高效且深度集成 Wayland 桌面环境的屏幕截取与标注方案。

## 为什么需要截屏模块？

在 Wayland 与平铺窗口管理器（如 Niri）环境中，截图往往由多个组件协作完成：
1. **底层像素捕获**：通过 `grim` 从 Wayland 合成器捕获原始像素。
2. **交互式选区**：通过 `slurp` 提供流畅的选区交互。
3. **图像标注与修饰**：通过现代化标注工具（如 **Satty**）进行裁剪、涂鸦、箭头、模糊马赛克、高亮与文字说明。
4. **窗口管理器按键绑定联动**：将 Print / Mod+P 等按键无缝映射到截图工具，同时将标注界面配置为浮动窗口。

`desktop.screenshot` 模块封装了这一整套链路，首发搭载基于 Rust + GTK 的现代化截屏标注利器 **Satty**。

---

## 子模块列表

### 1. `satty` (desktop.screenshot.satty)

[Satty](https://github.com/gabm/satty) 是一款受 Swappy 和 Flameshot 启发的高颜值现代截屏标注工具，专为 Wayland 原生设计。

#### 核心特性与优势

- **严格对齐源码的深度配置能力**：
  Satty 的 TOML 配置具有严格的反序列化校验（未知字段会导致退出）。本模块严格依据 Satty 源码的配置定义，完整抽象了 `[general]`、`[keybinds]`、`[font]`、`[color-palette]` 各项段落，并在构建期通过 Satty 二进制执行语法校验 (`checkConfig`)。
- **强大的包装工具 (`satty-screenshot`)**：
  - `satty-screenshot --area`：交互式区域框选截屏（默认）。
  - `satty-screenshot --screen`：一键捕捉全屏。
  - `satty-screenshot --window`：窗口截屏。若处于 Niri 会话中，优先调用 `niri msg action screenshot-window` 快速且精确截取活动窗口，并直通 Satty 标注。
- **Niri 窗口管理器深度整合**：
  - 自动向 Niri 注册浮动窗口规则 (`open-floating = true`)，避免标注窗口被误平铺。
  - 自动将 `satty-screenshot` 绑定到 Niri 的截图快捷键（Print, Mod+P, Ctrl+Print, Alt+Print 等）。
- **统一部署与覆盖**：
  配置文件不仅落盘至 `/etc/xdg/satty/config.toml`，还完整支持 Home Manager 用户级联动，并允许通过 `settings` 深度合并或 `extraConfig` 追写原生 TOML 内容。

---

## 配置示例

### 1. 基础启用

```nix
desktop.screenshot.satty = {
  enable = true;
};
```

### 2. 深度自定义 Satty 标注行为

```nix
desktop.screenshot.satty = {
  enable = true;

  general = {
    initialTool = "brush";            # 启动时默认选中画笔 (支持 pointer, crop, line, arrow, rectangle, ellipse, text, marker, blur, highlight, brush)
    earlyExit = [ "all" ];            # 完成复制或保存后自动退出
    cornerRoundness = 12;             # 矩形圆角弧度
    copyCommand = "wl-copy";          # 复制命令
    outputFilename = "~/Pictures/Screenshots/Satty_%Y-%m-%d_%H:%M:%S.png"; # 保存路径模板
    defaultFillShapes = false;        # 绘制几何图形时不填充内部
    primaryHighlighter = "block";     # 块状高亮
  };

  # 自定义快捷工具键
  keybinds = {
    brush = "b";
    rectangle = "r";
    text = "t";
    blur = "u";
  };

  # 自定义调色板
  colorPalette.palette = [
    "#f0932bff"
    "#eb4d4bff"
    "#6ab04cff"
    "#22a6b3ff"
    "#130f40FF"
  ];
};
```

### 3. Niri 联动与按键定制

```nix
desktop.screenshot.satty = {
  enable = true;
  niri = {
    enable = true;
    openFloating = true;              # 标注窗口自动浮动
    bindScreenshots = true;           # 自动接管 Niri 截屏快捷键
    keybind = "Print";                # 主选区截屏按键
    altKeybind = "Mod+P";             # 备用选区截屏按键
    screenKeybind = "Ctrl+Print";     # 全屏截屏按键
    windowKeybind = "Alt+Print";      # 活动窗口截屏按键
  };
};
```
