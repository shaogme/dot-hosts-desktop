# 输入法（Input Method）模块指南

本模块负责在 NixOS 桌面环境与 Home Manager 中构建现代化、高颜值且开箱即用的中文输入法环境。以 **Fcitx5** 框架为核心，默认搭载 **Rime（中州韵输入法引擎）与雾凇拼音（rime-ice）**，并支持深度外观主题、词库拓展与沙箱环境隔离适配。

---

## 核心特性

- **开箱即用 雾凇拼音（rime-ice）**：默认启用优质开源全拼词库与拼音方案，支持双拼（小鹤双拼、微软双拼、自然码等）一键切换。
- **深度主题与 UI 定制**：内建支持 Catppuccin（Mocha / Macchiato / Frappe / Latte）、TokyoNight、Nord、Material-Color 等精致主题，横排/竖排候选框自由定制。
- **大词库与云拼音增强**：集成 `rime-zhwiki` 维基词库、`fcitx5-pinyin-zhwiki` 与百度云拼音增强联想。
- **Wayland / Hyprland 深度融合**：默认启用 Wayland 原生输入法前端（text-input 协议），自动优化会话环境变量（`XMODIFIERS`, `QT_IM_MODULE`, `SDL_IM_MODULE`, `GLFW_IM_MODULE`，并在 Wayland 下按官方规范不设置 `GTK_IM_MODULE` 避免桌面诊断告警），支持 Hyprland 自动启动与配置窗口居中浮动规则。
- **Bubblewrap 沙箱无缝穿透**：底层沙箱工具库（`mk-sandboxed-app` 与 `profiles.nix`）自动穿透输入法套接字通道，保障 QQ、微信、VSCode、Firefox 等隔离应用即开即打。
- **系统与 Home Manager 双重联动**：全局声明式统一部署，自动同步至用户级别。

---

## 快速上手

### 基础启用（默认开启 Rime 雾凇拼音）

在主机配置（如 `hosts/home-7950x/configuration.nix`）中添加：

```nix
desktop.inputMethod.fcitx5 = {
  enable = true;
};
```

无需任何额外配置，系统将默认应用：

- 默认输入法：Rime（雾凇拼音 `rime_ice`）
- 默认快捷键：`Ctrl + Space` / `Shift_L` 激活与切换
- 默认候选词：横排显示，每页 5 个词
- 默认主题：`catppuccin-mocha-mauve`

---

## 深度自定义配置示例

### 1. 切换双拼方案（如小鹤双拼）与调整候选词数量

```nix
desktop.inputMethod.fcitx5 = {
  enable = true;

  rime = {
    enable = true;
    defaultSchema = "double_pinyin_flypy"; # 默认设为小鹤双拼
    schemas = [
      "double_pinyin_flypy"
      "rime_ice"
      "double_pinyin"
      "luna_pinyin_simp"
    ];
    pageSize = 7; # 候选词每页显示 7 个
  };
};
```

### 2. 定制主题外观与字体

```nix
desktop.inputMethod.fcitx5 = {
  enable = true;

  theme = {
    enable = true;
    name = "catppuccin-mocha-blue"; # 或 Nord-Dark, Tokyonight-Storm, Material-Color-deepPurple
    package = pkgs.catppuccin-fcitx5; # 或 pkgs.fcitx5-nord, pkgs.fcitx5-tokyonight, pkgs.fcitx5-material-color
  };

  ui = {
    verticalCandidateList = true; # 开启竖排候选框
    pageSize = 5;
    font = {
      name = "Geist, TsangerJinKai04, Noto Sans CJK SC, sans-serif";
      size = 12;
    };
  };
};
```

### 3. 追加 Rime 原生补丁 (YAML)

你可以通过 `rime.extraYaml` 直接向 RIME 的 `default.custom.yaml` 注入任何自定义的 YAML 补丁代码：

```nix
desktop.inputMethod.fcitx5 = {
  enable = true;

  rime = {
    enable = true;
    extraYaml = ''
      "ascii_composer/switch_key/Shift_L": commit_code
      "recognizer/patterns/punct": "^/([0-9]0?|[A-Za-z]+)$"
    '';
  };
};
```

---

## 配置选项速查表

| 选项路径 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `desktop.inputMethod.fcitx5.enable` | `bool` | `false` | 是否启用 Fcitx5 输入法模块 |
| `desktop.inputMethod.fcitx5.waylandFrontend` | `bool` | `true` | 是否启用 Wayland 原生输入法前端（text-input，推荐保持 true 以避免 GTK_IM_MODULE 告警） |
| `desktop.inputMethod.fcitx5.defaultInputMethod` | `str` | `"rime"` | 默认首选输入法标识（`"rime"` / `"pinyin"`） |
| `desktop.inputMethod.fcitx5.theme.enable` | `bool` | `true` | 是否启用皮肤与主题支持 |
| `desktop.inputMethod.fcitx5.theme.name` | `str` | `"catppuccin-mocha-mauve"` | 主题名称（支持 Catppuccin、Nord、Tokyonight、Material-Color） |
| `desktop.inputMethod.fcitx5.theme.package` | `package` | `pkgs.catppuccin-fcitx5` | 主题软件包 |
| `desktop.inputMethod.fcitx5.ui.verticalCandidateList` | `bool` | `false` | 候选词是否竖排显示（`false` 为横排） |
| `desktop.inputMethod.fcitx5.ui.pageSize` | `int` | `5` | 候选词每页显示个数 |
| `desktop.inputMethod.fcitx5.ui.font.name` | `str` | `"Geist, TsangerJinKai04, ..."` | 候选框字体族 |
| `desktop.inputMethod.fcitx5.ui.font.size` | `int` | `11` | 候选框字体大小 |
| `desktop.inputMethod.fcitx5.rime.enable` | `bool` | `true` | 是否启用 Rime 中州韵输入法引擎 |
| `desktop.inputMethod.fcitx5.rime.defaultSchema` | `str` | `"rime_ice"` | Rime 默认方案（`rime_ice` 雾凇拼音） |
| `desktop.inputMethod.fcitx5.rime.schemas` | `listOf str` | `[ "rime_ice" "double_pinyin_flypy" ... ]` | 激活的方案列表 |
| `desktop.inputMethod.fcitx5.rime.zhwiki` | `bool` | `true` | 是否自动挂载中文维基百科词库 |
| `desktop.inputMethod.fcitx5.rime.extraYaml` | `lines` | `""` | 注入 `default.custom.yaml` 的原生 YAML 补丁 |
| `desktop.inputMethod.fcitx5.chineseAddons.enable` | `bool` | `true` | 是否启用拼音/双拼/云拼音等官方中文拓展 |
| `desktop.inputMethod.fcitx5.chineseAddons.cloudPinyin.enable` | `bool` | `true` | 是否启用云拼音候选增强 |
| `desktop.inputMethod.fcitx5.chineseAddons.cloudPinyin.backend` | `enum` | `"Baidu"` | 云拼音后端（`"Baidu"` / `"Google"`） |
| `desktop.inputMethod.fcitx5.quickPhrase.enable` | `bool` | `true` | 是否启用快捷短语与表情符号 |
| `desktop.inputMethod.fcitx5.hotkey.triggerKeys` | `listOf str` | `[ "Control+Space" "Shift_L" ]` | 输入法切换激活热键 |
| `desktop.inputMethod.fcitx5.niri.autostart` | `bool` | `true` | 是否在 Niri 启动时自启 Fcitx5 |
| `desktop.inputMethod.fcitx5.niri.windowRules` | `bool` | `true` | 是否注册 Fcitx5 配置界面的浮动与居中规则 |
| `desktop.inputMethod.fcitx5.homeManager.enable` | `bool` | `true` | 是否同步配置至 Home Manager |

---

## 沙箱应用（Bubblewrap）输入法适配

在 [`modules/apps/lib/profiles.nix`](../apps/lib/profiles.nix) 与 [`modules/apps/lib/mk-sandboxed-app.nix`](../apps/lib/mk-sandboxed-app.nix) 中：

1. **套接字穿透**：默认通过 `--ro-bind-try $XDG_RUNTIME_DIR/fcitx5` 与 `$XDG_RUNTIME_DIR/bus` 穿透至沙箱内部。
2. **环境变量自动注入**：沙箱内部启动脚本自动校验并导出 `XMODIFIERS`、`QT_IM_MODULE`、`SDL_IM_MODULE` 与 `GLFW_IM_MODULE`，在 Wayland 模式下自动取消 `GTK_IM_MODULE` 以优先使用原生 Wayland text-input 协议。
3. **支持的应用**：已在 QQ NT、WeChat Universal、VSCode Insiders、Firefox Developer Edition、v2rayN 等所有沙箱应用中验证正常输入。
