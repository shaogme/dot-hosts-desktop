{
  config,
  pkgs,
  lib,
  options,
  ...
}:

with lib;

let
  cfg = config.desktop.toolchain.rust;
  sources = import ./npins;
  rustOverlay = import "${sources.rust-overlay}/default.nix";

  # 获取包含 rust-bin 的 pkgs 实例（若尚未注入 overlay 则通过 extend 动态补齐）
  effectivePkgs = if pkgs ? rust-bin then pkgs else pkgs.extend rustOverlay;
  rustBin = effectivePkgs.rust-bin;

  # 根据 channel / profile / extensions / targets 构造目标 Rust 工具链软件包
  resolvedRustPackage =
    if cfg.channel == "stable" then
      rustBin.stable.latest.${cfg.profile}.override {
        extensions = cfg.extensions;
        targets = cfg.targets;
      }
    else if cfg.channel == "beta" then
      rustBin.beta.latest.${cfg.profile}.override {
        extensions = cfg.extensions;
        targets = cfg.targets;
      }
    else if cfg.channel == "nightly" then
      rustBin.nightly.latest.${cfg.profile}.override {
        extensions = cfg.extensions;
        targets = cfg.targets;
      }
    else
      rustBin.fromRustupToolchain {
        channel = cfg.channel;
        profile = cfg.profile;
        components = cfg.extensions;
        targets = cfg.targets;
      };
in
{
  imports = [
    (mkAliasOptionModule [ "toolchain" "rust" ] [ "desktop" "toolchain" "rust" ])
    (mkAliasOptionModule [ "desktop" "toolchains" "rust" ] [ "desktop" "toolchain" "rust" ])
  ];

  options.desktop.toolchain.rust = {
    enable = mkEnableOption "Rust 开发工具链（基于 oxalica/rust-overlay 管理）";

    channel = mkOption {
      type = types.str;
      default = "stable";
      example = "nightly";
      description = "Rust 发布通道（如 'stable'、'beta'、'nightly' 或固定版本号如 '1.85.0'）。";
    };

    profile = mkOption {
      type = types.enum [ "default" "minimal" "complete" ];
      default = "default";
      description = "Rustup 组件预设 Profile（default, minimal, complete）。";
    };

    extensions = mkOption {
      type = types.listOf types.str;
      default = [
        "rust-src"
        "rust-analyzer"
        "clippy"
        "rustfmt"
      ];
      example = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" "llvm-tools-preview" ];
      description = "附加安装的 Rust 官方组件扩展列表。";
    };

    targets = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "wasm32-unknown-unknown" "x86_64-unknown-linux-musl" ];
      description = "交叉编译目标架构 Target 列表。";
    };

    package = mkOption {
      type = types.package;
      default = resolvedRustPackage;
      defaultText = literalExpression "pkgs.rust-bin.\${cfg.channel}.latest.\${cfg.profile}.override { ... }";
      description = "最终安装的 Rust 工具链软件包。";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "with pkgs; [ cargo-edit cargo-watch ]";
      description = "附加安装的 Rust 生态相关开发工具。";
    };

    setSrcPath = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动设置 RUST_SRC_PATH 环境变量指向 rust-src 源码路径。";
    };

    homeManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "是否将 Rust 工具链与环境变量同步导出至 Home Manager 用户环境。";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # 1. 注入 oxalica/rust-overlay 到 Nixpkgs
      nixpkgs.overlays = [ rustOverlay ];

      # 2. 系统级安装 Rust 工具链与附加工具
      environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;

      # 3. 配置系统会话环境变量 (RUST_SRC_PATH)
      environment.sessionVariables = mkIf cfg.setSrcPath {
        RUST_SRC_PATH = "${cfg.package}/lib/rustlib/src/rust/library";
      };
    }

    # 4. 同步集成至 Home Manager
    (optionalAttrs (options ? home-manager) {
      home-manager = mkIf cfg.homeManager.enable {
        sharedModules = [
          ({ ... }: {
            home.packages = [ cfg.package ] ++ cfg.extraPackages;
            home.sessionVariables = mkIf cfg.setSrcPath {
              RUST_SRC_PATH = "${cfg.package}/lib/rustlib/src/rust/library";
            };
          })
        ];
      };
    })
  ]);
}
