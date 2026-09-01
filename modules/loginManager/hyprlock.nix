{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.desktop.loginManager.hyprlock;

  toHyprconf =
    if lib ? hm && lib.hm ? generators && lib.hm.generators ? toHyprconf then
      lib.hm.generators.toHyprconf
    else
      {
        attrs,
        indentLevel ? 0,
        importantPrefixes ? [ "$" ],
      }:
      let
        initialIndent = concatStrings (replicate indentLevel "  ");

        toHyprconf' =
          indent: attrs:
          let
            isImportantField = n: _: any (prev: hasPrefix prev n) importantPrefixes;
            importantFields = filterAttrs isImportantField attrs;
            withoutImportantFields = fields: removeAttrs fields (attrNames importantFields);

            allSections = filterAttrs (_n: v: isAttrs v || isList v) attrs;
            sections = withoutImportantFields allSections;

            mkSection =
              n: attrs:
              if isList attrs then
                let
                  separator = if all isAttrs attrs then "\n" else "";
                in
                (concatMapStringsSep separator (a: mkSection n a) attrs)
              else if isAttrs attrs then
                ''
                  ${indent}${n} {
                  ${toHyprconf' "  ${indent}" attrs}${indent}}
                ''
              else
                toHyprconf' indent { ${n} = attrs; };

            mkFields = generators.toKeyValue {
              listsAsDuplicateKeys = true;
              inherit indent;
            };

            allFields = filterAttrs (_n: v: !(isAttrs v || isList v)) attrs;
            fields = withoutImportantFields allFields;
          in
          mkFields importantFields
          + concatStringsSep "\n" (mapAttrsToList mkSection sections)
          + mkFields fields;
      in
      toHyprconf' initialIndent attrs;
in
{
  options.desktop.loginManager.hyprlock = {
    enable = mkEnableOption "hyprlock 现代化 GPU 加速锁屏工具与会话锁定管理器";

    package = mkPackageOption pkgs "hyprlock" { nullable = true; };

    settings = mkOption {
      type =
        with types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Hyprlock configuration value";
            };
        in
        valueType;
      default = { };
      example = literalExpression ''
        {
          general = {
            hide_cursor = true;
            ignore_empty_input = true;
          };

          animations = {
            enabled = true;
            fade_in = {
              duration = 300;
              bezier = "easeOutQuint";
            };
            fade_out = {
              duration = 300;
              bezier = "easeOutQuint";
            };
          };

          background = [
            {
              path = "screenshot";
              blur_passes = 3;
              blur_size = 8;
            }
          ];

          "input-field" = [
            {
              size = "200, 50";
              position = "0, -80";
              monitor = "";
              dots_center = true;
              fade_on_empty = false;
              font_color = "rgb(202, 211, 245)";
              inner_color = "rgb(91, 96, 120)";
              outer_color = "rgb(24, 25, 38)";
              outline_thickness = 5;
              placeholder_text = \'\'<span foreground="##cad3f5">Password...</span>\'\';
              shadow_passes = 2;
            }
          ];
        }
      '';
      description = ''
        以 Nix 结构化数据编写的 Hyprlock 配置。
        具有相同键名的重复区块（例如 background、input-field、label、image、shape 等）应声明为列表。
        变量和颜色名称应使用字符串或引号包裹。
        详细配置语法与示例请参阅 <https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/>。
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "追加写入到 hyprlock.conf 的额外原生配置文本。";
    };

    sourceFirst = mkOption {
      type = types.bool;
      default = true;
      description = "是否将 source 配置文件语句置于生成的配置内容最顶端。";
    };

    importantPrefixes = mkOption {
      type = with types; listOf str;
      default = [
        "$"
        "bezier"
        "monitor"
        "size"
      ];
      description = "在配置生成时置于各层级顶部的属性名前缀列表。";
    };
  };

  config = mkIf cfg.enable {
    # 1. 确保 PAM 认证服务已启用（hyprlock 解锁必需）
    security.pam.services.hyprlock = { };

    # 2. 将 hyprlock 软件包添加到系统环境中
    environment.systemPackages = mkIf (cfg.package != null) [
      cfg.package
    ];

    # 3. 部署系统级 hyprlock 配置文件
    environment.etc =
      let
        shouldGenerate = cfg.extraConfig != "" || cfg.settings != { };
        generatedText =
          optionalString (cfg.settings != { }) (
            toHyprconf {
              attrs = cfg.settings;
              importantPrefixes = cfg.importantPrefixes ++ optional cfg.sourceFirst "source";
            }
          )
          + optionalString (cfg.extraConfig != "") cfg.extraConfig;
      in
      mkIf shouldGenerate {
        "hypr/hyprlock.conf".text = generatedText;
        "xdg/hypr/hyprlock.conf".text = generatedText;
      };
  };
}
