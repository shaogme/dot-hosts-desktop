{ config, pkgs, lib, modulesPath, ... }:

let
  # 导入由 npins 管理的依赖源
  sources = import ./npins;
  
  # 基础库和扩展库
  dot-base = import sources.dot-base { };
  dot-exts = import sources.dot-exts { };

  # 主机基础配置信息
  hostConfig = {
    name = "laptop-8845hs";
    user = "shaog";

    auth = {
      # 你的 Hash 密码
      rootHash = "$6$o03HUIIXmYHQQlfy$cn03Aj2Dup1aKbrbyNqvQ//oJjimR66gE8krV1.ZU0k.ptFA.6FvVK.MQ4bWJiagIQKD1USvAKkEjm5VLU7Mw0";
      # SSH Keys
      sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNCU2PbTCr6HbrCdthvfbfTeXBePXNei7ER13hwotjr hi@shaog.me" ];
    };
  };

  # 文本编辑器配置信息
  editorConfig = {
    defaultEditor = "hx";
  };

  # 终端配置信息
  terminalConfig = rec {
    terminal = "rio";
    defaultTerminal = terminal;
  };
in
{
  imports = [
    # 1. 引入模块库
    dot-base.nixosModules.default
    dot-exts.nixosModules.kernel.cachyos
    dot-exts.nixosModules.hardware.disk.btrfs
    # 2. 引入 Home Manager 模块
    "${sources.home-manager}/nixos"
    # 3. 引入公共模块集合
    ../../modules/default.nix
  ];

  # ==========================================
  # 通用系统配置 (Base)
  # ==========================================
  system.stateVersion = "26.11"; 
  
  # 启用 Lix 代替默认的 CppNix
  nix.package = pkgs.lixPackageSets.git.lix;
  
  # 基础功能启用
  base.enable = true;

  # 全局默认文本编辑器环境变量
  environment.sessionVariables = {
    EDITOR = editorConfig.defaultEditor;
    VISUAL = editorConfig.defaultEditor;
  };
  
  # Hardware 配置
  base.hardware.type = "physical";
  exts.hardware.disk.btrfs = {
      enable = true;
      device = "/dev/nvme0n1";
      swapSize = 4096;
      # 显式指定基础镜像大小，用于 Disko 构建参考
      imageBaseSize = 20480; 
      partitions.root = {
        size = "100%";
        subvolumes = {
          "@" = { mountpoint = "/"; };
          "@home" = { mountpoint = "/home"; };
          "@nix" = { mountpoint = "/nix"; };
          "@log" = { mountpoint = "/var/log"; neededForBoot = true; };
        };
      };
  };

  # 图形驱动与硬件加速: 启用 AMD 核显 + NVIDIA 独显混合模式 (PRIME Offload)
  base.hardware.graphics = {
    mode = "hybrid-amd-nvidia";
    hybrid = {
      strategy = "offload";
      integratedBusId = "PCI:6:0:0";
      discreteBusId = "PCI:1:0:0";
    };
    nvidia.open = true;
  };
  
  # 性能与功耗调优 (TLP + auto-cpufreq 组合优化 - 移动端)
  desktop.tuning = {
    enable = true;
    mode = "mobile";
  };
  base.performance.tuning.profile = "none";
  base.memory.mode = "conservative";
  # 容器引擎
  base.container.podman.enable = true;
  
  # 系统自动更新与同步 (Legacy 模式)
  base.update = {
    enable = true;
    upgrade = {
      enable = true;
      timer.enable = false;
      type = "legacy";
    };
    sync = {
      enable = true;
      url = "https://github.com/shaogme/dot-hosts-desktop";
    };
    # 指定追踪 dot-hosts-desktop 仓库中的子路径
    path = "hosts/${hostConfig.name}"; 
  };

  # ==========================================
  # 桌面与图形环境 (Niri & 桌面基础设施与组件)
  # ==========================================
  desktop.windowManager.niri = {
    enable = true;
    terminal = terminalConfig.terminal;
    editor = {
      enable = true;
      command = "${terminalConfig.terminal} -e ${editorConfig.defaultEditor}";
    };
    clipboard = {
      enable = true;
      command = "cliphist-pick";
      keybind = "Ctrl+grave";
    };
  };

  desktop.audio.pipewire = {
    enable = true;
  };

  desktop.bar.waybar = {
    enable = true;
    commands = {
      terminal = terminalConfig.terminal;
      cpu = "${terminalConfig.terminal} -e btop";
      memory = "${terminalConfig.terminal} -e btop";
      network = "${terminalConfig.terminal} -e nmtui";
      netSpeed = "${terminalConfig.terminal} -e btop";
      bluetooth = "${terminalConfig.terminal} -e bluetuith";
      powerDraw = "${terminalConfig.terminal} -e btop";
    };
  };

  desktop.launcher.anyrun = {
    enable = true;
    terminal = {
      command = terminalConfig.terminal;
      args = "-e {}";
    };
  };

  desktop.launcher.fuzzel = {
    enable = true;
    terminal = "${terminalConfig.terminal} -e";
    font = {
      family = "monospace";
      size = 11;
    };
    layout = {
      width = 45;
      lines = 15;
      prompt = " ❯ ";
    };
    search.matchMode = "fzf";
    wrappers = {
      powerMenu.enable = true;
      windowSwitch.enable = true;
      dmenuWrapper.enable = true;
    };
  };

  desktop.clipboard.cliphist = {
    enable = true;
    storage = {
      text.enable = true;
      images.enable = true;
      maxItems = 1000;
    };
    selector = {
      command = "fuzzel-dmenu --with-nth 2";
      previewThumbnails = true;
    };
  };

  # 文件管理器与桌面门户 (Yazi & termfilechooser)
  desktop.fileManager.yazi = {
    enable = true;
    terminal = terminalConfig.terminal;
    editor = editorConfig.defaultEditor;
    terminalKeybind = {
      enable = true;
      command = terminalConfig.terminal;
    };
  };

  # 文本编辑器 (Helix)
  desktop.editor.helix = {
    enable = true;
    terminal = terminalConfig.terminal;
  };

  desktop.portal.termfilechooser = {
    enable = true;
    terminal = terminalConfig.terminal;
    env = {
      EDITOR = editorConfig.defaultEditor;
    };
  };

  desktop.notification.swaync = {
    enable = true;
  };

  desktop.theme = {
    enable = true;
  };

  desktop.wallpaper.awww = {
    enable = true;
    wallpaper = config.desktop.wallpaper.wallpapers.defaultWallpaper;
  };

  # 登录管理器 (tuigreet)
  desktop.loginManager.tuigreet = {
    enable = true;
    defaultSession = "niri";
    display = {
      showTime = true;
    };
    remember = {
      username = true;
      session = true;
    };
  };

  # ==========================================
  # Home Manager 配置
  # ==========================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${hostConfig.user} = { pkgs, ... }: {
      home.stateVersion = "26.11";
      home.sessionVariables = {
        EDITOR = editorConfig.defaultEditor;
        VISUAL = editorConfig.defaultEditor;
      };
    };
  };

  # ==========================================
  # 主机特有配置
  # ==========================================
  networking.hostName = hostConfig.name;
  
  # 硬件报告路径 (占位，待后续生成完整硬件报告)
  hardware.facter.reportPath = ./facter.json;

  # 内核优化: 启用 CachyOS 内核
  exts.kernel.cachyos.enable = true;

  # 内核模块: 启用 KVM 虚拟化支持 (AMD CPU)
  boot.kernelModules = [ "kvm-amd" ];

  # 内核参数: 修复机械革命 GM5HG0A (8845H) 开关屏幕/休眠唤醒时 i8042 键盘控制器超时与通信失败
  boot.kernelParams = [
    "i8042.reset=1"
    "i8042.nomux=1"
    "i8042.nopnp=1"
    "i8042.noloop=1"
  ];

  # 网络配置: 使用 NetworkManager 后端
  base.hardware.network = {
    enable = true;
    backend = "networkmanager";
  };
  
  # 认证与安全: 用户与 Root 配置
  base.auth.root = {
    mode = "default";
    initialHashedPassword = hostConfig.auth.rootHash;
    authorizedKeys = hostConfig.auth.sshKeys;
  };

  users.users.${hostConfig.user} = {
    isNormalUser = true;
    description = "Shaog";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "kvm" "libvirtd" "proxy-bypass" ];
    initialHashedPassword = hostConfig.auth.rootHash;
    openssh.authorizedKeys.keys = hostConfig.auth.sshKeys;
  };

  # ==========================================
  # 终端与 Shell 环境 (Terminal & Zsh & Starship)
  # ==========================================
  desktop.terminal.${terminalConfig.terminal} = {
    enable = true;
    editor.program = editorConfig.defaultEditor;
  };

  desktop.terminal.zsh = {
    enable = true;
  };

  desktop.terminal.starship = {
    enable = true;
  };

  # ==========================================
  # 常用软件包集合配置
  # ==========================================
  desktop.packages = {
    enable = true;
    wifi.enable = true;
  };

  # ==========================================
  # 开发工具链 (Rust)
  # ==========================================
  desktop.toolchain.rust = {
    enable = true;
  };

  # 桌面应用配置
  desktop.apps.clash-verge = {
    enable = true;
  };

  desktop.apps.v2rayn = {
    enable = true;
  };

  desktop.apps.firefox-developer-edition = {
    enable = true;
  };

  desktop.apps.wechat = {
    enable = true;
  };

  desktop.apps.qq = {
    enable = true;
  };

  desktop.apps.vscode-insiders = {
    enable = true;
  };

  # ==========================================
  # 透明代理服务 (sing-box SOCKS5 TUN)
  # ==========================================
  services.socks-tun = {
    enable = true;
    defaultPort = 10808;
  };

  # ==========================================
  # 统一字体与 Fontconfig 配置
  # ==========================================
  desktop.fonts = {
    enable = true;
  };

  # ==========================================
  # 输入法配置 (Fcitx5 + Rime 雾凇拼音)
  # ==========================================
  desktop.inputMethod.fcitx5 = {
    enable = true;
  };

  # ==========================================
  # 虚拟化与虚拟机管理 (KVM / QEMU / Libvirt)
  # ==========================================
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
  };

  # Virt-Manager 图形管理工具
  programs.virt-manager.enable = true;
  programs.dconf.enable = true;

  # 静态测试与合法性断言 (与配置同模块维护)
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.base.update.upgrade.type == "legacy";
      message = "更新模式配置错误，预期为 legacy，实际为 ${config.base.update.upgrade.type}";
    }
    {
      assertion = config.base.update.sync.url == "https://github.com/shaogme/dot-hosts-desktop";
      message = "更新同步 URL 配置错误，预期为 https://github.com/shaogme/dot-hosts-desktop，实际为 ${config.base.update.sync.url}";
    }
    {
      assertion = config.exts.kernel.cachyos.enable == true;
      message = "内核配置错误：CachyOS 内核未启用";
    }
    {
      assertion = config.desktop.tuning.enable == true;
      message = "性能调优配置错误：desktop.tuning 模块未启用";
    }
    {
      assertion = config.desktop.tuning.mode == "mobile";
      message = "性能调优配置错误：应当启用 mobile 移动端优化模式";
    }
    {
      assertion = config.services.tlp.enable == true;
      message = "性能调优配置错误：TLP 服务未启用";
    }
    {
      assertion = config.services.auto-cpufreq.enable == true;
      message = "性能调优配置错误：auto-cpufreq 服务未启用";
    }
    {
      assertion = config.base.hardware.network.backend == "networkmanager";
      message = "网络后端配置错误：应当使用 networkmanager";
    }
    {
      assertion = config.base.hardware.graphics.mode == "hybrid-amd-nvidia";
      message = "图形驱动配置错误：AMD+NVIDIA 混合显卡驱动与加速未启用";
    }
    {
      assertion = config.desktop.windowManager.niri.enable == true;
      message = "窗口管理器配置错误：Niri 未启用";
    }
    {
      assertion = config.desktop.windowManager.niri.terminal == terminalConfig.terminal;
      message = "Niri 终端命令行配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.programs.niri.enable == true;
      message = "桌面环境配置错误：Niri 未启用";
    }
    {
      assertion = config.desktop.audio.pipewire.enable == true;
      message = "音频服务配置错误：PipeWire 未启用";
    }
    {
      assertion = config.desktop.bar.waybar.enable == true;
      message = "状态栏配置错误：Waybar 未启用";
    }
    {
      assertion = config.desktop.bar.waybar.backlight.enable == true;
      message = "状态栏配置错误：Waybar 屏幕亮度模块未启用";
    }
    {
      assertion = config.desktop.windowManager.niri.osd.enable == true;
      message = "OSD 浮动指示配置错误：SwayOSD 未启用";
    }
    {
      assertion = config.desktop.bar.waybar.commands.terminal == terminalConfig.terminal;
      message = "Waybar 终端命令行配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.launcher.anyrun.enable == true;
      message = "桌面启动器配置错误：Anyrun 未启用";
    }
    {
      assertion = config.desktop.launcher.anyrun.terminal.command == terminalConfig.terminal;
      message = "Anyrun 终端命令行配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.launcher.fuzzel.enable == true;
      message = "桌面启动器配置错误：fuzzel 未启用";
    }
    {
      assertion = config.desktop.launcher.fuzzel.terminal != "";
      message = "桌面启动器配置错误：未配置 fuzzel 终端命令行";
    }
    {
      assertion = config.desktop.clipboard.cliphist.enable == true;
      message = "剪贴板服务配置错误：cliphist 未启用";
    }
    {
      assertion = config.desktop.clipboard.cliphist.selector.command != "";
      message = "剪贴板服务配置错误：未配置 cliphist 选择器交互前端";
    }
    {
      assertion = config.desktop.windowManager.niri.clipboard.enable == true;
      message = "窗口管理器配置错误：Niri 剪贴板联动未启用";
    }

    {
      assertion = config.desktop.theme.enable == true;
      message = "桌面主题配置错误：desktop.theme 未启用";
    }
    {
      assertion = config.desktop.wallpaper.awww.enable == true;
      message = "壁纸服务配置错误：awww 壁纸模块未启用";
    }
    {
      assertion = config.desktop.notification.swaync.enable == true;
      message = "通知服务配置错误：SwayNC 未启用";
    }
    {
      assertion = config.desktop.loginManager.tuigreet.enable == true;
      message = "登录管理器配置错误：tuigreet 未启用";
    }
    {
      assertion = config.desktop.loginManager.tuigreet.defaultSession == "niri";
      message = "登录管理器配置错误：tuigreet 默认会话应配置为 niri";
    }
    {
      assertion = config.base.container.podman.enable == true;
      message = "容器引擎配置错误：Podman 未启用";
    }
    {
      assertion = config.desktop.packages.enable == true;
      message = "软件包集合配置错误：desktop.packages 未启用";
    }
    {
      assertion = config.desktop.packages.wifi.enable == true;
      message = "软件包集合 Wi-Fi 配置错误：desktop.packages.wifi 未启用";
    }
    {
      assertion = config.desktop.apps.clash-verge.enable == true;
      message = "桌面应用配置错误：desktop.apps.clash-verge 未启用";
    }
    {
      assertion = config.desktop.apps.v2rayn.enable == true;
      message = "桌面应用配置错误：desktop.apps.v2rayn 未启用";
    }
    {
      assertion = config.desktop.apps.firefox-developer-edition.enable == true;
      message = "桌面应用配置错误：desktop.apps.firefox-developer-edition 未启用";
    }
    {
      assertion = config.desktop.apps.wechat.enable == true;
      message = "桌面应用配置错误：desktop.apps.wechat 未启用";
    }
    {
      assertion = config.desktop.apps.qq.enable == true;
      message = "桌面应用配置错误：desktop.apps.qq 未启用";
    }
    {
      assertion = config.desktop.apps.vscode-insiders.enable == true;
      message = "桌面应用配置错误：desktop.apps.vscode-insiders 未启用";
    }
    {
      assertion = config.desktop.fonts.enable == true;
      message = "字体配置错误：desktop.fonts 未启用";
    }
    {
      assertion = config.fonts.fontconfig.enable == true;
      message = "字体配置错误：Fontconfig 未启用";
    }
    {
      assertion = config.virtualisation.libvirtd.enable == true;
      message = "虚拟化配置错误：libvirtd 未启用";
    }
    {
      assertion = builtins.elem "kvm-amd" config.boot.kernelModules;
      message = "内核模块配置错误：kvm-amd 未启用";
    }
    {
      assertion = builtins.all (param: builtins.elem param config.boot.kernelParams) [
        "i8042.reset=1"
        "i8042.nomux=1"
        "i8042.nopnp=1"
        "i8042.noloop=1"
      ];
      message = "内核参数配置错误：i8042 键盘控制器调优参数未完全启用";
    }
    {
      assertion = builtins.elem "kvm" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 kvm 组";
    }
    {
      assertion = builtins.elem "libvirtd" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 libvirtd 组";
    }
    {
      assertion = config.programs.virt-manager.enable == true;
      message = "虚拟机管理工具配置错误：virt-manager 未启用";
    }
    {
      assertion = config.desktop.terminal.${terminalConfig.terminal}.enable == true;
      message = "终端配置错误：${terminalConfig.terminal} 未启用";
    }
    {
      assertion = config.desktop.terminal.zsh.enable == true;
      message = "终端配置错误：Zsh 未启用";
    }
    {
      assertion = config.desktop.terminal.starship.enable == true;
      message = "终端配置错误：Starship 未启用";
    }
    {
      assertion = config.programs.zsh.enable == true;
      message = "系统 Shell 配置错误：Zsh 系统级支持未启用";
    }
    {
      assertion = config.programs.starship.enable == true;
      message = "系统 Shell 配置错误：Starship 系统级支持未启用";
    }
    {
      assertion = config.users.defaultUserShell == pkgs.zsh || config.users.users.${hostConfig.user}.shell == pkgs.zsh;
      message = "默认 Shell 配置错误：用户默认 Shell 应当为 Zsh";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.enable == true;
      message = "输入法配置错误：Fcitx5 输入法未启用";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.rime.enable == true;
      message = "输入法配置错误：Rime 引擎未启用";
    }
    {
      assertion = config.desktop.inputMethod.fcitx5.rime.defaultSchema == "rime_ice";
      message = "输入法配置错误：Rime 默认方案应为 rime_ice 雾凇拼音";
    }
    {
      assertion = config.i18n.inputMethod.enable == true;
      message = "输入法配置错误：i18n.inputMethod 未启用";
    }
    {
      assertion = config.i18n.inputMethod.type == "fcitx5";
      message = "输入法配置错误：输入法框架类型应为 fcitx5";
    }
    {
      assertion = config.services.socks-tun.enable == true;
      message = "透明代理服务配置错误：services.socks-tun 未启用";
    }
    {
      assertion = builtins.elem "proxy-bypass" config.users.users.${hostConfig.user}.extraGroups;
      message = "用户组配置错误：用户 ${hostConfig.user} 未加入 proxy-bypass 组";
    }
    {
      assertion = config.desktop.fileManager.yazi.enable == true;
      message = "文件管理器配置错误：Yazi 未启用";
    }
    {
      assertion = config.desktop.portal.termfilechooser.enable == true;
      message = "桌面门户配置错误：termfilechooser 未启用";
    }
    {
      assertion = config.desktop.windowManager.niri.fileManager.enable == true;
      message = "Niri 文件管理器联动配置错误：应当启用文件管理器支持";
    }
    {
      assertion = config.desktop.windowManager.niri.portal.filechooser == "termfilechooser";
      message = "Niri 桌面门户配置错误：FileChooser 接口应当配置为 termfilechooser";
    }
    {
      assertion = config.desktop.editor.helix.enable == true;
      message = "文本编辑器配置错误：Helix 未启用";
    }
    {
      assertion = config.environment.sessionVariables.EDITOR == "hx";
      message = "环境变量 EDITOR 配置错误：应当为 hx";
    }
    {
      assertion = config.desktop.fileManager.yazi.editor == "hx";
      message = "Yazi 默认文本编辑器配置错误：应当配置为 hx";
    }
    {
      assertion = config.desktop.fileManager.yazi.terminalKeybind.enable == true;
      message = "Yazi 终端快捷键绑定未启用";
    }
    {
      assertion = config.desktop.fileManager.yazi.terminalKeybind.command == terminalConfig.terminal;
      message = "Yazi 终端快捷键绑定命令配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.fileManager.yazi.terminal == terminalConfig.terminal;
      message = "Yazi 终端配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.editor.helix.terminal == terminalConfig.terminal;
      message = "Helix 终端配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.portal.termfilechooser.terminal == terminalConfig.terminal;
      message = "桌面门户终端配置错误：应当配置为 ${terminalConfig.terminal}";
    }
    {
      assertion = config.desktop.windowManager.niri.editor.enable == true;
      message = "Niri 文本编辑器联动配置错误：应当启用文本编辑器支持";
    }
    {
      assertion = config.desktop.toolchain.rust.enable == true;
      message = "开发工具链配置错误：Rust 工具链未启用";
    }
  ];
}
