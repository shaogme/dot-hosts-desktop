{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.socks-tun;

  singboxConfigTemplate = {
    log = {
      level = "warn";
      timestamp = true;
    };
    dns = {
      servers = [
        {
          type = "local";
          tag = "dns-local";
        }
        {
          type = "fakeip";
          tag = "dns-fakeip";
          inet4_range = "198.18.0.0/15";
          inet6_range = "fc00::/18";
        }
      ];
      rules = [
        {
          query_type = [ "A" "AAAA" ];
          server = "dns-fakeip";
        }
        {
          query_type = [ "HTTPS" ];
          action = "reject";
        }
      ];
      strategy = "prefer_ipv4";
    };
    inbounds = [
      {
        type = "tun";
        tag = "tun-in";
        interface_name = "tun0";
        address = [ "172.19.0.1/30" ];
        auto_route = true;
        strict_route = true;
        stack = "system";
      }
    ];
    outbounds = [
      {
        type = "socks";
        tag = "socks-out";
        server = "127.0.0.1";
        server_port = 10808;
        version = "5";
      }
      {
        type = "direct";
        tag = "direct";
      }
    ];
    route = {
      default_domain_resolver = "dns-local";
      rules = [
        {
          port = [ 53 ];
          action = "hijack-dns";
        }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
        {
          inbound = "tun-in";
          action = "sniff";
        }
        {
          ip_is_private = true;
          outbound = "direct";
        }
      ];
      auto_detect_interface = true;
    };
  };

  proxyCtlScript = pkgs.writeShellScriptBin "proxy-ctl" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.iproute2 pkgs.systemd pkgs.gnused pkgs.gnugrep pkgs.curl ]}:$PATH"

    RUN_DIR="/run/socks-tun"
    CONFIG_FILE="$RUN_DIR/config.json"
    TEMPLATE_FILE="/etc/socks-tun/config.template.json"
    DEFAULT_PORT=${toString cfg.defaultPort}

    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
      SUDO="sudo"
    fi

    usage() {
      cat <<HELP
Usage: proxy-ctl <command> [arguments]

Commands:
  tun on [port]       开启 TUN 全局透明代理 (默认端口: $DEFAULT_PORT)
  tun off             关闭 TUN 全局透明代理
  env on [port]       开启当前 Shell / 系统级代理环境变量
  env off             关闭代理环境变量
  status              查看当前透明代理与上游 SOCKS5 状态
  test                测试代理连通性
HELP
    }

    check_port() {
      local port="$1"
      if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
        exec 3<&-
        exec 3>&-
        return 0
      fi
      return 1
    }

    cmd_tun_on() {
      local port="''${1:-$DEFAULT_PORT}"
      echo "正在启动 TUN 透明代理 (上游 SOCKS5: 127.0.0.1:$port)..."

      # 1. 检查本地 SOCKS5 端口存活性预警
      if ! check_port "$port"; then
        echo "警告: 检测到 127.0.0.1:$port 当前未处于监听状态，请确保 v2rayN 或 Clash 已启动！"
      fi

      # 2. 动态生成配置文件
      $SUDO mkdir -p "$RUN_DIR"
      $SUDO sed "s/10808/$port/g" "$TEMPLATE_FILE" | $SUDO tee "$CONFIG_FILE" >/dev/null
      $SUDO chown -R sing-box:sing-box "$RUN_DIR"
      $SUDO chmod 775 "$RUN_DIR"
      $SUDO chmod 664 "$CONFIG_FILE"

      # 3. 补充系统策略路由规则 (确保带有 0x55 标记的豁免流量走 main 表)
      if ! ip rule list | grep -qw "0x55"; then
        $SUDO ip rule add fwmark 0x55 table main priority 100
      fi

      # 4. 启动 / 重启 systemd 服务
      $SUDO systemctl restart socks-tun.service
      echo "TUN 透明代理已成功启动！"
    }

    cmd_tun_off() {
      echo "正在关闭 TUN 透明代理..."
      $SUDO systemctl stop socks-tun.service
      $SUDO ip rule del fwmark 0x55 table main 2>/dev/null || true
      echo "TUN 透明代理已关闭，网络已恢复直连。"
    }

    cmd_env_on() {
      local port="''${1:-$DEFAULT_PORT}"
      cat <<EXPORT_ENV
export http_proxy="http://127.0.0.1:$port"
export https_proxy="http://127.0.0.1:$port"
export all_proxy="socks5h://127.0.0.1:$port"
export HTTP_PROXY="http://127.0.0.1:$port"
export HTTPS_PROXY="http://127.0.0.1:$port"
export ALL_PROXY="socks5h://127.0.0.1:$port"
EXPORT_ENV
      >&2 echo "提示: 请使用 'eval \$(proxy-ctl env on $port)' 使环境变量在当前 Shell 生效。"
    }

    cmd_env_off() {
      cat <<UNSET_ENV
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
UNSET_ENV
      >&2 echo "提示: 请使用 'eval \$(proxy-ctl env off)' 在当前 Shell 清除环境变量。"
    }

    cmd_status() {
      echo "=== SOCKS-TUN 服务状态 ==="
      systemctl status socks-tun.service --no-pager || true
      echo ""
      echo "=== TUN 网卡与策略路由 ==="
      ip addr show tun0 2>/dev/null || echo "tun0 网卡: 未激活"
      ip rule list | grep "0x55" || echo "豁免策略路由: 未加载"
      echo ""
      echo "=== 上游配置与端口检测 ==="
      if [ -f "$CONFIG_FILE" ]; then
        configured_port=$(grep -o '"server_port": [0-9]*' "$CONFIG_FILE" | head -n 1 | awk '{print $2}')
        echo "当前配置上游端口: ''${configured_port:-未知}"
        if [ -n "$configured_port" ]; then
          if check_port "$configured_port"; then
            echo "上游 SOCKS5 127.0.0.1:$configured_port: 监听中 (正常)"
          else
            echo "上游 SOCKS5 127.0.0.1:$configured_port: 未监听 (异常)"
          fi
        fi
      else
        echo "当前未生成 /run/socks-tun/config.json 配置文件"
      fi
    }

    cmd_test() {
      echo "=== 正在测试网络连通性与代理状态 ==="
      echo "1. 测试 DNS 解析 (Fake-IP 响应)..."
      if command -v getent >/dev/null 2>&1; then
        getent hosts cp.cloudflare.com || true
      fi

      echo "2. 测试 HTTP 连通性 (Cloudflare trace)..."
      curl -m 5 -s https://cloudflare.com/cdn-cgi/trace || echo "无法直连/通过代理访问外部网络"
      echo ""
      echo "3. 测试公网出站 IP..."
      curl -m 5 -s https://icanhazip.com || true
    }

    case "''${1:-}" in
      tun)
        subcmd="''${2:-}"
        case "$subcmd" in
          on)
            cmd_tun_on "''${3:-}"
            ;;
          off)
            cmd_tun_off
            ;;
          *)
            usage
            exit 1
            ;;
        esac
        ;;
      env)
        subcmd="''${2:-}"
        case "$subcmd" in
          on)
            cmd_env_on "''${3:-}"
            ;;
          off)
            cmd_env_off
            ;;
          *)
            usage
            exit 1
            ;;
        esac
        ;;
      status)
        cmd_status
        ;;
      test)
        cmd_test
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  '';

  proxyCtlPkg = pkgs.runCommand "proxy-ctl-bundle" {} ''
    mkdir -p $out/bin
    ln -s ${proxyCtlScript}/bin/proxy-ctl $out/bin/proxy-ctl
    ln -s ${proxyCtlScript}/bin/proxy-ctl $out/bin/socks-tun
  '';
in
{
  options.services.socks-tun = {
    enable = mkEnableOption "sing-box SOCKS5 动态 TUN 透明代理服务";

    defaultPort = mkOption {
      type = types.port;
      default = 10808;
      description = "默认上游 SOCKS5 代理端口 (如 v2rayN 为 10808, Clash 为 7890)";
    };

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "是否在系统启动时自动启动 socks-tun 服务 (默认 false，由 proxy-ctl tun on 按需启动)";
    };

    bypassUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "自动加入 proxy-bypass 组的用户列表";
    };
  };

  config = mkIf cfg.enable {
    # 1. 内核模块与必要参数
    boot.kernelModules = [ "tun" ];
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # 2. 放宽防火墙反向路径过滤 (避免多网卡与策略路由丢包)
    networking.firewall.checkReversePath = "loose";

    # 3. 创建专用系统组
    users.groups.proxy-bypass = {
      gid = 1992;
      members = cfg.bypassUsers;
    };

    # 4. 创建专用非特权运行用户
    users.users.sing-box = {
      isSystemUser = true;
      group = "sing-box";
      uid = 991;
      extraGroups = [ "proxy-bypass" ];
      description = "sing-box SOCKS-TUN daemon user";
    };
    users.groups.sing-box = {
      gid = 991;
    };

    # 5. 部署静态配置文件模板
    environment.etc."socks-tun/config.template.json".text =
      builtins.toJSON singboxConfigTemplate;

    # 6. systemd 守护进程服务
    systemd.services.socks-tun = {
      description = "sing-box SOCKS5 TUN Gateway Service";
      after = [ "network.target" ];
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
      serviceConfig = {
        ExecStartPre = [
          "+${pkgs.bash}/bin/bash -c 'if [ ! -f /run/socks-tun/config.json ] || [ /etc/socks-tun/config.template.json -nt /run/socks-tun/config.json ]; then ${pkgs.gnused}/bin/sed \"s/10808/${toString cfg.defaultPort}/g\" /etc/socks-tun/config.template.json > /run/socks-tun/config.json && chown sing-box:sing-box /run/socks-tun/config.json && chmod 664 /run/socks-tun/config.json; fi'"
          "+${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip rule show | ${pkgs.gnugrep}/bin/grep -qw \"0x55\" || ${pkgs.iproute2}/bin/ip rule add fwmark 0x55 table main priority 100'"
        ];
        ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /run/socks-tun/config.json";
        ExecStopPost = [
          "+${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip rule del fwmark 0x55 table main 2>/dev/null || true'"
        ];
        RuntimeDirectory = "socks-tun";
        RuntimeDirectoryMode = "0775";
        User = "sing-box";
        Group = "sing-box";
        SupplementaryGroups = [ "proxy-bypass" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        LimitNOFILE = 1048576;
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    # 7. nftables 豁免与防回环策略路由标记
    networking.nftables = {
      enable = mkDefault true;
      tables.socks_tun_bypass = {
        family = "inet";
        content = ''
          chain output {
            type route hook output priority -150;
            meta skgid 1992 meta mark set 0x55 accept;
            meta skuid 991 meta mark set 0x55 accept;
            ip daddr 127.0.0.0/8 accept;
          }
        '';
      };
    };

    # 8. 安装 CLI 工具并支持交互式 Shell 函数
    environment.systemPackages = [
      pkgs.sing-box
      proxyCtlPkg
    ];

    environment.interactiveShellInit = ''
      proxy-ctl() {
        if [ "''${1:-}" = "env" ]; then
          if [ "''${2:-}" = "on" ]; then
            local port="''${3:-${toString cfg.defaultPort}}"
            export http_proxy="http://127.0.0.1:$port"
            export https_proxy="http://127.0.0.1:$port"
            export all_proxy="socks5h://127.0.0.1:$port"
            export HTTP_PROXY="$http_proxy"
            export HTTPS_PROXY="$https_proxy"
            export ALL_PROXY="$all_proxy"
            echo "已设置当前 Shell 代理环境变量 (127.0.0.1:$port)"
          elif [ "''${2:-}" = "off" ]; then
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            echo "已清除当前 Shell 代理环境变量"
          else
            command proxy-ctl "$@"
          fi
        else
          command proxy-ctl "$@"
        fi
      }
      socks-tun() {
        proxy-ctl "$@"
      }
    '';

    # 9. 允许用户免密管理 socks-tun 服务及路由表
    security.sudo.extraRules = [
      {
        groups = [ "wheel" "proxy-bypass" ];
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl start socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl stop socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl restart socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl status socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.iproute2}/bin/ip rule *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl start socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl status socks-tun.service";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/ip rule *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
