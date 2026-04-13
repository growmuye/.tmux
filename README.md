# 我的 tmux 配置

## Feature

- 使用 Alt+F 来代替 Ctrl+B 作为全局功能前缀，靠左手大姆指与食指来按，更方便、快捷
- 增加了基于 Alt 快捷键的窗口新建、切换等操作，操作更快捷
- 自定制了底部状态栏，增加了系统资源实时利用率等

## Installation

```bash
git clone https://github.com/growmuye/.tmux.git ~/.tmux
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
```

### 开发环境

`~/.tmux.conf` 已软链接到本项目，修改配置后 `tmux source-file ~/.tmux.conf` 即可生效。

`~/.tmux/scripts/` 是独立的 scripts 目录（不是本项目的软链接），在本地其他目录修改了脚本后，需要同步：

```bash
cp scripts/*.sh ~/.tmux/scripts/
```

重新加载配置：

```bash
tmux source-file ~/.tmux.conf
```

## Requirements

- tmux >= 2.0
- macOS

## 状态栏

状态栏左侧显示 CPU/内存利用率 + 时间，颜色根据利用率动态变化：
- < 60%: green (`colour119`)
- < 85%: yellow (`colour208`)
- >= 85%: red (`colour204`)
- 背景统一为 `colour235`

资源采集由 `scripts/resource-usage.sh` 实现（macOS 原生命令 `top` + `vm_stat`）。
