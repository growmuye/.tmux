# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

macOS tmux 自定义配置和资源监控工具。包含：
- tmux 配置文件（`tmux.conf`）
- Shell 脚本：CPU/内存利用率监控 + 状态栏拼接

## 常用命令

```bash
# 无需编译，直接生效
tmux source-file ~/.tmux.conf
```

## 代码架构

### 目录结构

- `scripts/` - Shell 脚本
  - `resource-usage.sh` - macOS 资源采集脚本（替代 Linux 的 C 工具）
    - CPU：`top -l 1` 读取累计平均利用率
    - 内存：`vm_stat` + `sysctl hw.memsize` 实时计算
  - `status-left.sh` - 状态栏左侧（资源栏 + 时间栏拼接）
  - `status-right.sh` - 状态栏右侧（主机名 + session）
  - `helpers.sh` - 辅助函数

### 核心脚本

**resource-usage.sh**：
- 用法：`resource-usage.sh [narrow]`
- 输出 tmux 格式状态栏字符串（带 `#[bg=colourX]` 颜色代码）
- CPU 显示 📊 emoji，无单核显示（macOS `top -l 1` 不提供单核数据）
- 内存显示 ㎇ 符号 + 用量/总量

### 测试策略

无需编译测试，直接观察状态栏输出：
```bash
~/.tmux/scripts/resource-usage.sh      # 宽屏模式
~/.tmux/scripts/resource-usage.sh narrow  # 窄屏模式
```

### 显示逻辑

状态栏颜色根据利用率动态变化（`color_code_for_rate` 函数）：
- < 60%: green (`colour10`)
- < 85%: yellow (`colour3`)
- >= 85%: red (`colour1`)

### 输出格式

**宽屏模式**（>200 字符）：
```
 📊CPU% ㎇used/total  Mon 2026/04/06 09:00:00 
```

**窄屏模式**（≤200 字符）：
```
CPU%|used/total 04/06 09:00:00 
```
