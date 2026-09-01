# 桌面应用（Apps）模块开发指南

本文档指导如何在 `modules/packages/apps/` 下为桌面环境打包、沙箱隔离并添加新的应用程序。

---

## 目录结构规范

每个应用应作为独立子目录维护在 `modules/packages/apps/<app-name>/` 下，标准结构如下：

``` txt
modules/packages/apps/<app-name>/
├── default.nix       # NixOS 模块定义（提供 options.desktop.apps.<app-name>）
├── package.nix       # 软件包构建与 Bubblewrap/FHS 沙箱隔离定义
└── npins/            # 由 npins 依赖管理器维护的版本与哈希
    ├── default.nix   # npins 工具自动生成（禁止手动修改）
    └── sources.json  # 锁定的版本、下载源与 SHA-256（禁止手动编写）
```

> [!TIP]
> **自动发现机制**：[`modules/packages/apps/default.nix`](./default.nix) 会自动扫描并引入 `modules/packages/apps/` 下所有包含 `default.nix` 的子目录，**无需在上层手动注册路径**。

---

## 应用打包与隔离开发流程（4 步法）

### 步骤 1：通过 npins 锁定依赖版本

遵循项目的依赖管理规范（见 [AGENTS.md](../../AGENTS.md)），禁止在 Nix 表达式中手写 Hash。

1. **初始化 npins 目录**：

   ```bash
   mkdir -p modules/packages/apps/<app-name>/npins
   npins -d modules/packages/apps/<app-name>/npins init --bare
   ```

2. **添加上游 GitHub Release 依赖**：

   ```bash
   # 追踪指定 Tag 并自动计算 Hash
   npins -d modules/packages/apps/<app-name>/npins add github --at v1.0.0 <owner> <repo>
   ```

---

### 步骤 2：编写软件包与沙箱隔离逻辑 (`package.nix`)

创建 `modules/packages/apps/<app-name>/package.nix`：

- 从 `npins` 中动态读取版本号，禁止在代码中硬编码版本。
- 使用 `pkgs.buildFHSEnv` 提供运行时动态链接库（解决二进制在 NixOS 上缺失 FHS 路径的问题）。
- 配置 Bubblewrap 规则，实现 **宿主机家目录屏蔽** + **独立沙箱家目录持久化**。

```nix
{ pkgs, lib ? pkgs.lib, ... }:

let
  sources = import ./npins;

  # 1. 动态从 npins 中获取版本（如 "v1.0.0" -> "1.0.0"）
  rawVersion = sources.<pin-name>.version;
  version = lib.removePrefix "v" rawVersion;

  # 2. 根据版本动态获取官方 Release 二进制
  debUrl = "https://github.com/<owner>/<repo>/releases/download/v${version}/<app>_${version}_amd64.deb";
  debSrc = builtins.fetchurl debUrl;

  # 3. 解包二进制文件
  unpacked = pkgs.stdenv.mkDerivation {
    pname = "<app-name>-raw";
    inherit version;
    src = debSrc;

    nativeBuildInputs = [ pkgs.dpkg ];
    dontBuild = true;
    dontConfigure = true;

    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/
    '';
  };

  # 4. Bubblewrap + FHS 隔离运行环境
  fhs = pkgs.buildFHSEnv {
    name = "<app-name>-fhs";

    targetPkgs = pkgs: with pkgs; [
      # 根据应用实际依赖补充（如 GTK3 / WebKitGTK / Qt 等）
      gtk3
      glib
      openssl
      libxkbcommon
      wayland
      libx11
      libGL
      mesa
      pipewire
      alsa-lib
    ];

    extraBwrapArgs = [
      # 核心隔离：屏蔽宿主机真实家目录，防止访问 ~/.ssh, ~/.gnupg 等
      "--tmpfs" "$HOME"

      # 独立持久化：将专属沙箱目录挂载为容器内的 $HOME
      "--bind" "\${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/<app-name>" "$HOME"

      # 图形与音频穿透通道
      "--ro-bind-try" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0"
      "--ro-bind-try" "/tmp/.X11-unix" "/tmp/.X11-unix"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"
      "--ro-bind-try" "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"
      "--share-net"
    ];

    runScript = pkgs.writeShellScript "<app-name>-launcher" ''
      if [ -n "$WAYLAND_DISPLAY" ]; then
        export GDK_BACKEND=wayland,x11
      fi
      exec ${unpacked}/bin/<executable> "$@"
    '';
  };

  # 5. 宿主机包装器：自动创建专属持久化目录并启动容器
  wrapper = pkgs.writeShellScriptBin "<executable>" ''
    SANDBOX_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/sandboxes/<app-name>"
    mkdir -p "$SANDBOX_HOME"

    exec ${fhs}/bin/<app-name>-fhs "$@"
  '';

  # 6. 生成 Desktop Entry 快捷方式
  desktopItem = pkgs.makeDesktopItem {
    name = "<app-name>";
    desktopName = "<App Display Name>";
    genericName = "<Category Name>";
    comment = "<Description>";
    exec = "<executable> %U";
    icon = "<app-name>";
    terminal = false;
    type = "Application";
    categories = [ "Network" "Utility" ];
  };
in
pkgs.symlinkJoin {
  name = "<app-name>";
  paths = [
    wrapper
    desktopItem
  ];
  postBuild = ''
    mkdir -p $out/share/icons/hicolor
    if [ -d "${unpacked}/share/icons/hicolor" ]; then
      cp -r ${unpacked}/share/icons/hicolor/* $out/share/icons/hicolor/
    fi
  '';
}
```

---

### 步骤 3：编写 NixOS 模块入口 (`default.nix`)

创建 `modules/packages/apps/<app-name>/default.nix`：

- 提供 `desktop.apps.<app-name>.enable` 配置项。
- 允许用户覆盖 `desktop.apps.<app-name>.package`。

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.desktop.apps.<app-name>;
in
{
  options.desktop.apps.<app-name> = {
    enable = mkEnableOption "<App Name> 桌面应用程序（基于 Bubblewrap 沙箱隔离）";

    package = mkOption {
      type = types.package;
      default = import ./package.nix { inherit pkgs lib; };
      defaultText = literalExpression "import ./package.nix { inherit pkgs lib; }";
      description = "使用的 <App Name> 软件包实例。";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
```

---

### 步骤 4：启用与验证

1. **在主机配置中启用**（例如 [`hosts/home-7950x/configuration.nix`](../../hosts/home-7950x/configuration.nix)）：

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

## 安全与沙箱规范摘要

| 隔离维度 | 实现方式 | 说明 |
| :--- | :--- | :--- |
| **宿主机 $HOME 保护** | `--tmpfs $HOME` | 容器无法接触宿主机 `~/.ssh`、`~/.gnupg`、工作文档与浏览器 Cookies |
| **数据持久化路径** | `--bind $SANDBOX_HOME $HOME` | 映射至 `~/.local/share/sandboxes/<app-name>`，重启或升级配置不丢失 |
| **图形显示** | `--ro-bind-try $WAYLAND_DISPLAY` / `/tmp/.X11-unix` | 仅只读穿透 Wayland / X11 显示协议通道 |
| **音频服务** | `--ro-bind-try $XDG_RUNTIME_DIR/pipewire-0` | 仅只读穿透 PipeWire / PulseAudio Socket |
| **网络通道** | `--share-net` | 允许正常的网络通信 |

---

## 参考样例

请直接查阅生产环境成熟示例：

- [`modules/packages/apps/clash-verge/package.nix`](./clash-verge/package.nix)
- [`modules/packages/apps/clash-verge/default.nix`](./clash-verge/default.nix)
- [`modules/packages/apps/clash-verge/npins/sources.json`](./clash-verge/npins/sources.json)
- [`modules/packages/apps/v2rayn/package.nix`](./v2rayn/package.nix)
- [`modules/packages/apps/v2rayn/default.nix`](./v2rayn/default.nix)
- [`modules/packages/apps/v2rayn/npins/sources.json`](./v2rayn/npins/sources.json)
