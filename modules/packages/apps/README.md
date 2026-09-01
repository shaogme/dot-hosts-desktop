# 桌面应用（Apps）模块开发指南

本文档指导如何在 `modules/packages/apps/` 下为桌面环境打包、沙箱隔离并添加新的应用程序。

---

## 统一工具抽象体系

为消除各 App 在 FHS 依赖、Bubblewrap 沙箱隔离、包装脚本与 Desktop 快捷方式创建中的样板代码，仓库在 [`modules/packages/apps/lib/`](./lib/) 下提供了统一的抽象工具库：

- **[`lib/mk-sandboxed-app.nix`](./lib/mk-sandboxed-app.nix)**: 统一沙箱应用构建器（整合解包、FHS、bwrap、Launcher/Wrapper 生成、Desktop Item 与图标提取）。
- **[`lib/mk-app-module.nix`](./lib/mk-app-module.nix)**: 统一 NixOS 模块生成器（自动生成 `options.desktop.apps.<name>`、别名支持与系统环境集成）。
- **[`lib/profiles.nix`](./lib/profiles.nix)**: 预置依赖 Profile 库（`desktop-gui`, `gtk3`, `webkitgtk`, `dotnet`, `media` 等）与沙箱规则生成器。
- **[`lib/unpackers.nix`](./lib/unpackers.nix)**: 通用解包引擎（支持 `deb`、`tarball` 及多系统架构自动适配）。

---

## 目录结构规范

每个应用作为独立子目录维护在 `modules/packages/apps/<app-name>/` 下，标准结构如下：

``` txt
modules/packages/apps/<app-name>/
├── default.nix       # NixOS 模块定义（调用 mkAppModule，通常仅 5~10 行）
├── package.nix       # 声明式沙箱构建规范（调用 mkSandboxedApp，通常仅 20~30 行）
└── npins/            # 由 npins 依赖管理器维护的版本与哈希
    ├── default.nix   # npins 工具自动生成（禁止手动修改）
    └── sources.json  # 锁定的版本、下载源与 SHA-256（禁止手动编写）
```

> [!TIP]
> **自动发现机制**：[`modules/packages/apps/default.nix`](./default.nix) 会自动扫描并引入 `modules/packages/apps/` 下所有包含 `default.nix` 的应用子目录（自动忽略 `lib/` 工具库），**无需在上层手动注册路径**。

---

## 应用打包与隔离开发流程（4 步法）

### 步骤 1：通过 npins 锁定依赖版本

遵循项目的依赖管理规范（见 [AGENTS.md](../../../AGENTS.md)），禁止在 Nix 表达式中手写 Hash。

1. **初始化 npins 目录**：

   ```bash
   mkdir -p modules/packages/apps/<app-name>/npins
   npins -d modules/packages/apps/<app-name>/npins init --bare
   ```

2. **添加上游依赖（以 GitHub Release 为例）**：

   ```bash
   npins -d modules/packages/apps/<app-name>/npins add github --at v1.0.0 <owner> <repo>
   ```

---

### 步骤 2：编写软件包与沙箱声明 (`package.nix`)

创建 `modules/packages/apps/<app-name>/package.nix`：

```nix
{ pkgs, lib ? pkgs.lib, mkSandboxedApp ? pkgs.callPackage ../lib/mk-sandboxed-app.nix { inherit lib; } }:

let
  sources = import ./npins;
  rawVersion = sources.<pin-name>.version;
  version = lib.removePrefix "v" rawVersion;
  debUrl = "https://github.com/<owner>/<repo>/releases/download/v${version}/<app>_${version}_amd64.deb";
in
mkSandboxedApp {
  pname = "<app-name>";
  inherit version;
  src = builtins.fetchurl debUrl;
  srcType = "deb";
  execPath = "bin/<executable>";

  # 依赖 Profile 组合 (如 desktop-gui, webkitgtk, dotnet, media 等)
  profiles = [ "desktop-gui" "webkitgtk" ];
  hostDirs = [ ".config/<app-name>" ];

  desktop = {
    desktopName = "<App Display Name>";
    genericName = "<Category Name>";
    comment = "<Description>";
    categories = [ "Network" "Utility" ];
    icon = "<app-name>";
  };
}
```

---

### 步骤 3：编写 NixOS 模块入口 (`default.nix`)

创建 `modules/packages/apps/<app-name>/default.nix`：

```nix
import ../lib/mk-app-module.nix {
  name = "<app-name>";
  description = "<App Display Name> 桌面应用程序";
  package = ./package.nix;
  # 可选：提供别名 (如 aliases = [ "app-alias" ];)
}
```

---

### 步骤 4：启用与验证

1. **在主机配置中启用**（例如 [`hosts/home-7950x/configuration.nix`](../../../hosts/home-7950x/configuration.nix)）：

   ```nix
   desktop.apps.<app-name> = {
     enable = true;
   };
   ```

2. **运行静态断言与构建检查**：

   ```bash
   nix-build tests -A "home-7950x.staticCheck" --check
   ```

3. **依赖更新检查**：

   ```bash
   bash scripts/update-npins.sh -n
   ```

---

## 常用 Profile 清单

| Profile 名称 | 包含组件与适用场景 |
| :--- | :--- |
| **`desktop-gui`** | 通用桌面 GUI 元 Profile：整合基础 C 运行时、X11、Wayland、GPU 加速、PipeWire 音频、Fontconfig 字体及 GTK3 |
| **`electron`** | Electron / Chromium 基础运行环境（at-spi2-core、expat、libsecret、libnotify、NSS、NSPR、systemd 等，如 QQ、VSCode） |
| **`xcb`** | XCB / Qt 附加图形环境（xcbutilimage、xcbutilkeysyms、xcbutilwm 等，如微信 WeChat Universal） |
| **`webkitgtk`** | WebKitGTK 4.1 与 libsoup3 支持（如 Clash Verge Rev、Tauri 应用） |
| **`dotnet`** | .NET CoreCLR / Avalonia UI 运行时依赖（ICU、SQLite 原生库等，如 v2rayN） |
| **`media`** | 完整多媒体与安全编解码库（FFmpeg、libvpx、NSS、NSPR 等，如 Firefox） |

---

## 安全与沙箱规范摘要

| 隔离维度 | 实现方式 | 说明 |
| :--- | :--- | :--- |
| **宿主机 $HOME 保护** | `--tmpfs $HOME` | 容器无法接触宿主机 `~/.ssh`、`~/.gnupg`、工作文档与浏览器 Cookies |
| **数据持久化路径** | `--bind $SANDBOX_HOME $HOME` | 映射至 `~/.sandboxes/<app-name>`，重启或升级配置不丢失 |
| **图形显示** | `--ro-bind-try $WAYLAND_DISPLAY` / `/tmp/.X11-unix` | 仅只读穿透 Wayland / X11 显示协议通道 |
| **音频服务** | `--ro-bind-try $XDG_RUNTIME_DIR/pipewire-0` | 仅只读穿透 PipeWire / PulseAudio Socket |
| **网络通道** | `--share-net` | 允许正常的网络通信 |

---

## 参考样例

- [`modules/packages/apps/clash-verge/package.nix`](./clash-verge/package.nix)
- [`modules/packages/apps/clash-verge/default.nix`](./clash-verge/default.nix)
- [`modules/packages/apps/firefox/package.nix`](./firefox/package.nix)
- [`modules/packages/apps/firefox/default.nix`](./firefox/default.nix)
- [`modules/packages/apps/firefox-developer-edition/package.nix`](./firefox-developer-edition/package.nix)
- [`modules/packages/apps/qq/package.nix`](./qq/package.nix)
- [`modules/packages/apps/qq/default.nix`](./qq/default.nix)
- [`modules/packages/apps/v2rayn/package.nix`](./v2rayn/package.nix)
- [`modules/packages/apps/v2rayn/default.nix`](./v2rayn/default.nix)
- [`modules/packages/apps/wechat/package.nix`](./wechat/package.nix)
- [`modules/packages/apps/wechat/default.nix`](./wechat/default.nix)
