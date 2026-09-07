# 自定义跨用户存储管理模块 (desktop.storage)

本模块旨在为 NixOS 桌面环境提供开箱即用的跨用户（普通用户与 `root` 用户）自定义路径存储管理。

由于桌面应用默认在 Bubblewrap 沙箱与 FHS 容器隔离环境中运行，且应用开启了 HOME 目录隔离（`isolatedHome = true`），应用的实际家目录指向 `~/.sandboxes/<app>`，各应用与用户之间无法直接共享个人目录中的数据。

`desktop.storage` 模块通过声明式 `systemd-tmpfiles` 与 POSIX ACL，管理系统级跨用户持久化存储路径（默认为 `/data`），并协同 Bubblewrap 沙箱参数生成器，使所有沙箱应用均可自由读写该路径。

## 核心特性

1. **多用户与 Root 共享**：
   - 默认所属组为 `users`（普通用户所在默认组），所有者为 `root`；
   - 默认目录权限模式为 `2775`（启用 `setgid` 标志位），在目录下创建的任何子目录与文件自动继承父目录的 `users` 组；
   - 默认启用 POSIX 继承 ACL（`d:u::rwx,d:g::rwx,d:m::rwx,d:o::r-x`），确保 `root` 或普通用户创建的任何文件/目录均具备同组可读写权限。

2. **沙箱全自动化直通**：
   - 配合 `modules/apps/lib/mk-sandboxed-app/sandbox.nix` 与 `types.nix`，所有基于 Bubblewrap 的应用默认开启 `shareData = true`；
   - 自动生成 `--bind-try /data /data` 沙箱挂载参数，使沙箱内的应用（如 Firefox, WeChat, QQ, VSCode, Clash Verge 等）均可无缝读写 `/data`。

## 配置示例

在主机配置中（如 `hosts/home-7950x/configuration.nix`）：

```nix
desktop.storage = {
  enable = true;
  paths = {
    "/data" = {
      user = "root";
      group = "users";
      mode = "2775";
      acl.enable = true;
    };
  };
};
```
