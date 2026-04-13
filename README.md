# 我的 tmux 配置

## Feature

- 使用 Alt+F 来代替 Ctrl+B 作为全局功能前缀，靠左手大姆指与食指来按，更方便、快捷
- 增加了基于 Alt 快捷键的窗口新建、切换等操作，操作更快捷
- 自定制了底部状态栏，增加了系统资源实时利用率等

## Installation

```bash
git clone https://github.com/nicky-zs/.tmux.git ~/.tmux
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
```

## Usage

重新进入 tmux 或者重新加载配置：

```bash
tmux source-file ~/.tmux.conf
```

## Requirements

- tmux >= 2.0
- macOS

## 状态栏

状态栏左侧显示 CPU/内存利用率 + 时间，颜色根据利用率动态变化：
- < 60%: green (`#00FF00`)
- < 85%: yellow (`#FFFF00`)
- >= 85%: red (`#FF0000`)

资源采集由 `scripts/resource-usage.sh` 实现（macOS 原生命令 `top` + `vm_stat`）。
