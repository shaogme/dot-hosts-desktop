# 回收站与安全删除模块 (desktop.trash)

本模块旨在为 NixOS 系统提供现代化、符合人体工程学且具备安全防护的回收站与文件删除管理方案。

## 为什么需要回收站模块？

传统的 UNIX `rm` 命令是一项不可逆操作：一旦执行，文件与目录将被直接解链接并不经确认地丢失。尤其在复杂开发环境或日常桌面使用中，手滑执行 `rm -rf` 会造成无法挽回的后果。

`desktop.trash` 模块引入了以 `rip2` 为代表的现代化命令行回收站工具作为 `rm` 的安全替代品。

## 子模块列表

### 1. `rip2` (desktop.trash.rip2)

[rip2](https://github.com/MilesCranmer/rip2) 是使用 Rust 编写的高性能、直观易用的命令行删除与恢复工具，具备以下核心优势：

- **坟场（Graveyard）归档机制**：删除的文件会被安全移动至“坟场”目录，完整保留其原始绝对路径层级，杜绝直接擦除数据；
- **重名冲突自动消解**：若多次删除同名同路径文件，`rip2` 会自动添加 `~1`, `~2` 编号备份，绝不覆盖旧数据；
- **极速撤销恢复**：通过 `rip -u`（unbury）即可一键将被删除的文件完好无损地送回原位置；
- **目录递归无需 `-rf`**：删除目录与删除单个文件一样自然，无需记忆易引发灾难的 `-rf` 危险参数；
- **跨 Shell 原生别名防护**：默认自动为 Bash、Zsh、Fish 与 Nushell 注入 `rm -> rip` 别名映射，无缝拦截误操作；
- **深度多用户与 Home Manager 联动**：自动为全局及各用户配置环境与 Shell 别名。

## 配置示例

在主机配置中启用：

```nix
desktop.trash.rip2 = {
  enable = true;
  # 可选：自定义回收站存放目录（默认为遵循 XDG 规范的 $XDG_DATA_HOME/graveyard 或 /tmp/graveyard-$USER）
  # graveyard = "/data/graveyard";
  # 可选：是否为 Shell 设置 rm -> rip 快捷别名（默认为 true）
  # enableAliases = true;
};
```

## 常用 CLI 操作指南

- **删除文件或目录**：
  ```bash
  rip myfile.txt
  rip my_directory/
  ```
- **撤销上次删除（还原文件）**：
  ```bash
  rip -u
  ```
- **查看当前目录下曾被删除的文件**：
  ```bash
  rip -s
  ```
- **还原当前目录下所有已删除文件**：
  ```bash
  rip -su
  ```
- **查看当前回收站（Graveyard）真实物理路径**：
  ```bash
  rip graveyard
  ```
- **彻底清空回收站**：
  ```bash
  rip -d
  ```
