{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.inputMethod.fcitx5;

  # 工具函数：将列表转换为 Fcitx5 INI 索引格式 (0=..., 1=...)
  listToIndexedAttrs = list:
    builtins.listToAttrs (lib.imap0 (i: v: lib.nameValuePair (toString i) v) list);

  # 规范化方案列表：确保 defaultSchema 在首位
  effectiveSchemas =
    let
      rest = filter (s: s != cfg.rime.defaultSchema) cfg.rime.schemas;
    in
    [ cfg.rime.defaultSchema ] ++ rest;

  # 1. 生成 RIME 核心补丁配置 (default.custom.yaml)
  rimeDefaultCustom = pkgs.writeTextDir "share/rime-data/default.custom.yaml" ''
    # 由 NixOS desktop.inputMethod.fcitx5 统一自动生成
    patch:
      "schema_list":
    ${concatMapStringsSep "\n" (s: "    - schema: ${s}") effectiveSchemas}
      "menu/page_size": ${toString cfg.rime.pageSize}
      "ascii_composer/good_old_caps_lock": true
      "ascii_composer/switch_key":
        Shift_L: inline_ascii
        Shift_R: commit_text
        Caps_Lock: clear
        Eisu_toggle: clear
    ${optionalString (cfg.rime.extraYaml != "") cfg.rime.extraYaml}
  '';

  # 2. 注入 RIME 补丁与词库包并重载 fcitx5-rime
  effectiveFcitx5Rime = cfg.rime.package.override {
    rimeDataPkgs =
      cfg.rime.extraDataPkgs
      ++ (optional cfg.rime.zhwiki pkgs.rime-zhwiki)
      ++ (optional cfg.rime.moegirl pkgs.rime-moegirl)
      ++ [ rimeDefaultCustom ];
  };

  # 3. 汇总所有 Fcitx5 插件 (Addons)
  allAddons =
    [ pkgs.fcitx5-gtk ]
    ++ (optional cfg.rime.enable effectiveFcitx5Rime)
    ++ (optionals cfg.chineseAddons.enable (
      [ cfg.chineseAddons.package ]
      ++ (optional cfg.chineseAddons.pinyinZhwiki pkgs.fcitx5-pinyin-zhwiki)
      ++ (optional cfg.chineseAddons.pinyinMoegirl pkgs.fcitx5-pinyin-moegirl)
    ))
    ++ (optional cfg.theme.enable cfg.theme.package)
    ++ cfg.addons;

  # 4. 全局快捷键与行为设置 (config)
  globalOptionsConfig = recursiveUpdate {
    Hotkey = {
      EnumerateWithTriggerKeys = true;
      EnumerateSkipFirst = false;
    };
    "Hotkey/TriggerKeys" = listToIndexedAttrs cfg.hotkey.triggerKeys;
    "Hotkey/PrevPage" = listToIndexedAttrs cfg.hotkey.prevPage;
    "Hotkey/NextPage" = listToIndexedAttrs cfg.hotkey.nextPage;
    "Hotkey/PrevCandidate" = listToIndexedAttrs cfg.hotkey.prevCandidate;
    "Hotkey/NextCandidate" = listToIndexedAttrs cfg.hotkey.nextCandidate;
  } cfg.hotkey.extraSettings;

  # 5. 输入法组与列表配置 (profile)
  inputMethodProfile = {
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = cfg.defaultInputMethod;
    };
    "Groups/0/Items/0" = {
      Name = "keyboard-us";
      Layout = "";
    };
  } // (optionalAttrs cfg.rime.enable {
    "Groups/0/Items/1" = {
      Name = "rime";
      Layout = "";
    };
  }) // (optionalAttrs (cfg.chineseAddons.enable && !cfg.rime.enable) {
    "Groups/0/Items/1" = {
      Name = "pinyin";
      Layout = "";
    };
  }) // {
    GroupOrder = {
      "0" = "Default";
    };
  };

  # 6. UI 主题与候选框界面配置 (conf/classicui.conf)
  classicuiConf = {
    globalSection = recursiveUpdate {
      "Vertical Candidate List" = cfg.ui.verticalCandidateList;
      PerScreenDPI = cfg.ui.perScreenDPI;
      WheelForPaging = cfg.ui.wheelForPaging;
      Font = "\"${cfg.ui.font.name} ${toString cfg.ui.font.size}\"";
      MenuFont = "\"${cfg.ui.menuFont.name} ${toString cfg.ui.menuFont.size}\"";
      TrayFont = "\"${cfg.ui.trayFont.name} ${toString cfg.ui.trayFont.size}\"";
      PreferTextIcon = cfg.ui.preferTextIcon;
      ShowLayoutNameInIcon = cfg.ui.showLayoutNameInIcon;
      UseInputMethodLanguageToDisplayText = cfg.ui.useInputMethodLanguageToDisplayText;
    } (optionalAttrs cfg.theme.enable {
      Theme = cfg.theme.name;
      DarkTheme = cfg.theme.name;
    }) // cfg.ui.extraSettings;
  };

  # 7. 附加插件配置 (conf/*.conf)
  addonsConf =
    {
      classicui = classicuiConf;
    }
    // (optionalAttrs (cfg.chineseAddons.enable && cfg.chineseAddons.cloudPinyin.enable) {
      cloudpinyin = {
        globalSection = {
          Backend = cfg.chineseAddons.cloudPinyin.backend;
          MinimumPinyinLength = cfg.chineseAddons.cloudPinyin.minimumPinyinLength;
        };
      };
    })
    // (optionalAttrs cfg.chineseAddons.enable {
      pinyin = {
        globalSection = {
          EmojiEnabled = cfg.chineseAddons.pinyin.emoji;
          Chaizi = cfg.chineseAddons.pinyin.chaizi;
        };
      };
    })
    // (optionalAttrs cfg.rime.enable {
      rime = {
        globalSection = {
          PreeditInApplication = true;
        };
      };
    });
in
{
  options.desktop.inputMethod.fcitx5 = {
    enable = mkEnableOption "Fcitx5 现代化下一代输入法框架（默认集成 Rime 雾凇拼音）";

    defaultInputMethod = mkOption {
      type = types.str;
      default = "rime";
      description = "默认首选输入法标识（如 rime 或 pinyin）。";
    };

    waylandFrontend = mkOption {
      type = types.bool;
      default = false;
      description = "是否仅使用 Wayland 原生输入法前端协议（默认为 false 以同时导出环境变量，确保各类 XWayland / GTK / Qt / Electron 应用无缝兼容）。";
    };

    theme = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Fcitx5 皮肤与主题支持。";
      };

      name = mkOption {
        type = types.str;
        default = "catppuccin-mocha-mauve";
        description = "Fcitx5 皮肤主题名称（支持 catppuccin-mocha-*、Tokyonight-*、Nord-*、Material-Color-* 等）。";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.catppuccin-fcitx5;
        defaultText = literalExpression "pkgs.catppuccin-fcitx5";
        description = "提供主题的软件包。";
      };
    };

    ui = {
      verticalCandidateList = mkOption {
        type = types.bool;
        default = false;
        description = "候选词列表是否使用竖排显示（false 为横向紧凑排列，true 为垂直排列）。";
      };

      pageSize = mkOption {
        type = types.int;
        default = 5;
        description = "候选词每页显示个数。";
      };

      font = {
        name = mkOption {
          type = types.str;
          default = "Geist, TsangerJinKai04, Noto Sans CJK SC, sans-serif";
          description = "输入框主候选文字字体族。";
        };
        size = mkOption {
          type = types.int;
          default = 11;
          description = "输入框主候选文字字体大小。";
        };
      };

      menuFont = {
        name = mkOption {
          type = types.str;
          default = "Geist, TsangerJinKai04, Noto Sans CJK SC, sans-serif";
          description = "右键菜单字体族。";
        };
        size = mkOption {
          type = types.int;
          default = 10;
          description = "右键菜单字体大小。";
        };
      };

      trayFont = {
        name = mkOption {
          type = types.str;
          default = "Geist Bold, TsangerJinKai04, sans-serif";
          description = "托盘图标文字字体族。";
        };
        size = mkOption {
          type = types.int;
          default = 10;
          description = "托盘图标文字字体大小。";
        };
      };

      perScreenDPI = mkOption {
        type = types.bool;
        default = true;
        description = "是否按屏幕独立适配高分屏 DPI 缩放。";
      };

      wheelForPaging = mkOption {
        type = types.bool;
        default = true;
        description = "是否允许鼠标滚轮在候选词列表中翻页。";
      };

      preferTextIcon = mkOption {
        type = types.bool;
        default = false;
        description = "是否优先使用纯文本托盘图标。";
      };

      showLayoutNameInIcon = mkOption {
        type = types.bool;
        default = true;
        description = "是否在托盘图标中显示当前键盘布局名称。";
      };

      useInputMethodLanguageToDisplayText = mkOption {
        type = types.bool;
        default = true;
        description = "是否根据输入法语言显示当前状态文本。";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "追加到 conf/classicui.conf 的自定义参数。";
      };
    };

    rime = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 Rime 中州韵输入法引擎（默认开启并优先预置雾凇拼音方案）。";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.fcitx5-rime;
        defaultText = literalExpression "pkgs.fcitx5-rime";
        description = "fcitx5-rime 基础软件包。";
      };

      defaultSchema = mkOption {
        type = types.str;
        default = "rime_ice";
        description = "Rime 默认启用的输入方案（默认 rime_ice 雾凇拼音全拼，亦可设定为 double_pinyin_flypy 等双拼方案）。";
      };

      schemas = mkOption {
        type = types.listOf types.str;
        default = [
          "rime_ice"
          "double_pinyin_flypy"
          "double_pinyin"
          "luna_pinyin_simp"
        ];
        description = "Rime 启用的方案列表（首项为默认方案，按 F4 或快捷键可在方案间自由切换）。";
      };

      pageSize = mkOption {
        type = types.int;
        default = 5;
        description = "Rime 引擎候选词数量（写入 default.custom.yaml）。";
      };

      extraDataPkgs = mkOption {
        type = types.listOf types.package;
        default = with pkgs; [
          rime-ice
          rime-data
        ];
        defaultText = literalExpression "with pkgs; [ rime-ice rime-data ]";
        description = "注入到 fcitx5-rime 的基础 RIME 数据与词库包列表。";
      };

      zhwiki = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动集成中文维基百科词库（rime-zhwiki）。";
      };

      moegirl = mkOption {
        type = types.bool;
        default = false;
        description = "是否自动集成萌娘百科词库（rime-moegirl，需允许 unfree 许可）。";
      };

      extraYaml = mkOption {
        type = types.lines;
        default = "";
        description = "追加写入 default.custom.yaml 的原生 YAML 补丁文本。";
      };
    };

    chineseAddons = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用 fcitx5-chinese-addons（包含拼音、双拼、云拼音等拓展）。";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.qt6Packages.fcitx5-chinese-addons;
        defaultText = literalExpression "pkgs.qt6Packages.fcitx5-chinese-addons";
        description = "fcitx5-chinese-addons 软件包。";
      };

      pinyinZhwiki = mkOption {
        type = types.bool;
        default = true;
        description = "是否在原生拼音中自动挂载维基词库（fcitx5-pinyin-zhwiki）。";
      };

      pinyinMoegirl = mkOption {
        type = types.bool;
        default = false;
        description = "是否在原生拼音中自动挂载萌娘词库（fcitx5-pinyin-moegirl，需 allowUnfree）。";
      };

      cloudPinyin = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用云拼音候选增强。";
        };

        backend = mkOption {
          type = types.enum [ "Baidu" "Google" ];
          default = "Baidu";
          description = "云拼音搜索引擎后端。";
        };

        minimumPinyinLength = mkOption {
          type = types.int;
          default = 3;
          description = "触发云拼音的最短拼音字符长度。";
        };
      };

      pinyin = {
        emoji = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用拼音 Emoji 表情候选联想。";
        };

        chaizi = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用拆字输入支持（u 模式）。";
        };
      };
    };

    quickPhrase = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否启用快捷短语与常用表情符号拓展。";
      };

      phrases = mkOption {
        type = types.attrsOf types.str;
        default = {
          smile = "（・∀・）";
          happy = "(≧∇≦)/";
          love = "(｡♥‿♥｡)";
          shrug = "¯\\_(ツ)_/¯";
          cry = "(╥﹏╥)";
          cheer = "＼(＾O＾)／";
          dianzan = "👍";
          heart = "❤️";
          fire = "🔥";
          party = "🎉";
          rocket = "🚀";
          star = "⭐";
        };
        description = "快捷短语词典（触发词 -> 展开内容）。";
      };
    };

    hotkey = {
      triggerKeys = mkOption {
        type = types.listOf types.str;
        default = [ "Control+Space" "Shift_L" ];
        description = "激活与切换输入法的热键列表。";
      };

      prevPage = mkOption {
        type = types.listOf types.str;
        default = [ "Up" "Page_Up" "minus" ];
        description = "上一页候选词热键。";
      };

      nextPage = mkOption {
        type = types.listOf types.str;
        default = [ "Down" "Page_Down" "equal" ];
        description = "下一页候选词热键。";
      };

      prevCandidate = mkOption {
        type = types.listOf types.str;
        default = [ "Shift+Tab" ];
        description = "上一个候选词热键。";
      };

      nextCandidate = mkOption {
        type = types.listOf types.str;
        default = [ "Tab" ];
        description = "下一个候选词热键。";
      };

      extraSettings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "追加到全局 config 文件的快捷键与高级参数。";
      };
    };

    addons = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "用户自定义附加安装的 Fcitx5 插件包列表。";
    };

    hyprland = {
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "是否在 Hyprland 启动时自动启动 Fcitx5 后台守护进程。";
      };

      windowRules = mkOption {
        type = types.bool;
        default = true;
        description = "是否自动向 Hyprland 注册 Fcitx5 配置界面的浮动与居中窗口规则。";
      };
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否将 Fcitx5 配置与 RIME 词库自动同步应用到 Home Manager 用户环境。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. 启用 NixOS 官方 i18n.inputMethod 模块集成
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          addons = allAddons;
          waylandFrontend = cfg.waylandFrontend;
          quickPhrase = mkIf cfg.quickPhrase.enable cfg.quickPhrase.phrases;
          settings = {
            globalOptions = globalOptionsConfig;
            inputMethod = inputMethodProfile;
            addons = addonsConf;
          };
        };
      };

      # 2. 系统环境软件包（提供 GUI 配置工具与控制命令）
      environment.systemPackages = [
        pkgs.fcitx5
        pkgs.qt6Packages.fcitx5-configtool
      ];

      # 3. 会话环境变量（确保 X11 / Wayland / GTK / Qt / SDL / Electron / Java 全平台中文输入就绪）
      environment.sessionVariables = {
        XMODIFIERS = "@im=fcitx";
        QT_IM_MODULE = "fcitx";
        GTK_IM_MODULE = "fcitx";
        SDL_IM_MODULE = "fcitx";
        GLFW_IM_MODULE = "ibus";
      };

      # 4. Hyprland 桌面联动（自启动与窗口浮动规则）
      desktop.windowManager.hyprland = mkIf config.desktop.windowManager.hyprland.enable {
        extraExecOnce = mkIf cfg.hyprland.autostart [
          "fcitx5 -d --replace"
        ];
        settings = mkIf cfg.hyprland.windowRules {
          windowrulev2 = [
            "float, class:^(org.fcitx.fcitx5-config-qt)$"
            "center, class:^(org.fcitx.fcitx5-config-qt)$"
            "size 800 600, class:^(org.fcitx.fcitx5-config-qt)$"
          ];
        };
      };
    }

    # 5. Home Manager 用户环境联动
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            i18n.inputMethod = {
              enable = true;
              type = "fcitx5";
              fcitx5 = {
                addons = allAddons;
                quickPhrase = mkIf cfg.quickPhrase.enable cfg.quickPhrase.phrases;
                settings = {
                  globalOptions = globalOptionsConfig;
                  inputMethod = inputMethodProfile;
                  addons = addonsConf;
                };
              };
            };
          })
        ];
      };
    })
  ]);
}
