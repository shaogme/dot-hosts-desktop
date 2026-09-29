# 录屏软件模块 (desktop.screenRecorder)

本模块旨在为 NixOS 系统提供现代化、功能强大且深度集成 Wayland 桌面环境的屏幕录制与流媒体推流方案。

## 为什么需要录屏软件模块？

在 Wayland 与 PipeWire 现代化桌面环境中，传统的 X11 抓屏工具不再适用。为了提供流畅、低延迟且支持硬件编解码加速的录屏与直播体验，需要针对 Wayland（特别是 Niri 等现代平铺式窗口管理器）及 PipeWire 音频体系进行专门的插件打包与权限配置。

`desktop.screenRecorder` 模块提供了结构化、高度可定制的录屏方案，首发支持业界标杆 **OBS Studio**。

---

## 子模块列表

### 1. `obs` (desktop.screenRecorder.obs)

[OBS Studio](https://obsproject.com/) 是一款开源免费的跨平台屏幕录像与视频直播软件。

#### 核心特性与优势

- **Wayland / PipeWire 深度集成**：内置并默认启用 `wlrobs`（Wayland 原生屏幕捕获）与 `obs-pipewire-audio-capture`（精确到单独应用程序的 PipeWire 音频流捕获）。
- **硬件加速编解码支持**：默认集成 `obs-vaapi`，无缝利用 Intel / AMD 显卡硬件编解码器降低 CPU 占用。
- **游戏抓取与高级流媒体**：默认搭载 `obs-vkcapture`（Vulkan / OpenGL 游戏画面捕获）与 `obs-gstreamer`（GStreamer 复杂管道支持）。
- **虚拟摄像头支持**：提供一键开启 `v4l2loopback` 内核模块选项，方便将 OBS 渲染画面实时输出给腾讯会议、Zoom、浏览器等外部应用。
- **窗口管理器与 Home Manager 联动**：自动为 Niri 提供窗口规则适配，并在启用 Home Manager 时自动同步用户环境。

---

## 配置示例

### 1. 基础启用 (默认已在 config/screenRecorder/default.nix 中开启)

```nix
desktop.screenRecorder.obs = {
  enable = true;
};
```

### 2. 启用虚拟摄像头 (Virtual Camera)

若需要使用 OBS 的“启动虚拟摄像机”功能输出给会议或网课软件：

```nix
desktop.screenRecorder.obs = {
  enable = true;
  enableVirtualCamera = true; # 自动加载 v4l2loopback 驱动并配置 polkit 权限
};
```

### 3. 自定义插件集合

```nix
desktop.screenRecorder.obs = {
  enable = true;
  plugins = with pkgs.obs-studio-plugins; [
    wlrobs
    obs-pipewire-audio-capture
    obs-vaapi
    obs-vkcapture
    obs-gstreamer
    # 可追加其他插件，例如背景虚化:
    obs-backgroundremoval
  ];
};
```

### 4. Niri 浮动窗口规则

```nix
desktop.screenRecorder.obs = {
  enable = true;
  niri = {
    enable = true;
    openFloating = true; # OBS 打开时默认以浮动窗口展示
  };
};
```
