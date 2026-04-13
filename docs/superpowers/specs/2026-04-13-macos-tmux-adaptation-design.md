---
name: macOS tmux adaptation
description: 将 Linux 专属 tmux 配置改造为纯 macOS 使用，C 资源工具替换为 shell 脚本
type: project
---

# macOS tmux 适配设计

## 目标

将现有 Linux 专属 tmux 配置改造为纯 macOS 使用。核心变更：移除 C 语言资源监控工具（依赖 `/proc/stat` 和 `/proc/meminfo`），改用 macOS shell 命令替代。

## 范围

### 需要修改

- `src/` + `tests/` + `Makefile` → 移除
- 新建 `scripts/resource-usage.sh` → macOS 资源采集脚本（替代 `bin/resource_usage`）
- `tmux.conf` → 状态栏调用路径适配 macOS
- `scripts/status-right.sh` → 调用路径调整
- `scripts/status-left.sh` → 调用路径调整
- `CLAUDE.md` → 更新架构说明
- `README.md` → 更新 Requirements 和 Installation

### 保持不变

- 键绑定（prefix、窗口切换、pane 操作等）
- 窗口重命名逻辑
- 状态栏颜色方案（colourX 格式通用）
- 显示格式（宽屏/窄屏逻辑）
- 测试策略（shell 脚本测试替代 C 单元测试）

## macOS 资源采集方案

### CPU

使用 `top -l 2 -s 0.5 -F -R -o cpu -stats cpu` 获取 CPU 利用率：

- 第一次输出为历史数据（丢弃）
- 第二次输出为最近 0.5s 的实时数据
- 从 `CPU usage: X.XX% user, Y.YY% sys, Z.ZZ% idle` 解析

差值计算：首次调用需等待 0.5s 获取第二个样本，之后每次调用缓存上次的第二个样本作为"旧数据"，本次的第二个样本作为"新数据"，计算差值。

缓存：`/tmp/tmux-resource.cpu.${USER}.dat` 存储上次采集的原始 `top` 输出。

**问题**：`top -l 2` 每次都要等待 1s（两次 0.5s 采样），作为 tmux `status-right` 脚本（每秒调用）太慢。

**实际方案**：用脚本自身做差值，每次采集一次 `top -l 1` 数据，与上次缓存做比较：

```bash
# 每次 top -l 1 -F -R -s 0 -stats cpu 返回一个瞬时样本
# 与上次缓存的样本比较，计算 delta
```

`top -l 1` 返回的是自启动以来的平均值，不是区间值。这会导致每次显示的是"历史累计"而非"最近 0.5s"。

**最终方案**：使用 `top -l 2 -s 0.5 -F -R -o cpu -stats cpu` 但只取第二次样本。首次运行延迟 0.5s，之后每次读取缓存的上一次样本值，与本次样本做差值。脚本本身不做阻塞等待——如果缓存中已有数据，立即返回差值结果；如果没有，启动后台 `top -l 2 -s 0.5` 采集并缓存，本次返回零值。

实际上，`top -l 2` 的问题在于它是阻塞的。换一种思路：

**使用 `ps` + 时间差方案**：

macOS 下最可靠的区间 CPU 采集方式是读取两次 `top` 输出的差值。在 tmux status bar 场景下，脚本每秒执行一次。我们可以让脚本在后台持续运行 `top`，将结果写入临时文件，主进程只读取缓存。

但这增加了复杂性。回到最简单方案：

**单样本 top + 差值缓存**：

每次调用 `top -l 1 -F -R -s 0 -stats cpu`，得到一行 `CPU usage: X% user, Y% sys, Z% idle`。这是自系统启动以来的平均值。两次调用之间取差值没有意义（都是累计平均）。

所以必须用 `top -l 2 -s 0.5`。但作为每秒调用的 status-right 脚本，阻塞 1s 不可接受。

**最终确定的方案**：

1. 首次调用：启动后台 `top -l 2 -s 0.5` 进程，PID 存入缓存，立即返回零值
2. 后台进程完成后将两行输出写入临时文件
3. 后续调用：读取临时文件中上次保存的"新样本"（即第 2 行），启动新的后台采集，返回 `上次新样本 - 上次旧样本` 的差值
4. 这样 status-right 脚本始终在 <10ms 内返回

### 内存

`vm_stat` 返回以 pages 为单位的统计：

```
Pages free:       XXXXX
Pages active:     XXXXX
Pages inactive:   XXXXX
Pages speculative: XXXXX
Pages wired down: XXXXX
```

计算公式：
```
page_size = $(pagesize)  # 通常 4096
total_memory = $(sysctl -n hw.memsize)  # 字节
used_pages = active + inactive + speculative + wired
used_memory = used_pages * page_size
usage_rate = used_memory / total_memory
```

`vm_stat` 是实时读取，无延迟，直接调用即可。

## 输出格式

`resource-usage.sh` 输出与现有 C 工具完全一致的 tmux 状态栏格式：

**宽屏**（`status-right.sh` 检测到 window_width > 200）：
```
📊XX.X% 📈XX.X% ㎇XX.X/XX.X
```

**窄屏**（window_width <= 200）：
```
XX.X%|XX.X%|XX.X/XX.X
```

颜色代码（`#[bg=colourX,fg=colourY]`）保持不变，由 `resource-usage.sh` 内联生成。

## 架构

```
tmux.conf
├── 公共配置（键绑定、窗口、面板等）
├── status-left → scripts/status-left.sh
└── status-right → scripts/status-right.sh
                      ├── 调用 scripts/resource-usage.sh (替代 bin/resource_usage)
                      └── 拼接时间栏

scripts/resource-usage.sh
├── CPU 采集：top -l 2 -s 0.5 (后台) + 差值缓存 (/tmp/tmux-resource.cpu.$USER.dat)
├── 内存采集：vm_stat + sysctl hw.memsize (实时)
├── 颜色计算：< 50% green, < 75% yellow, >= 85% red
└── 输出：tmux 格式状态栏字符串（带 #[bg=colourX] 代码）
```

## 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 删除 | `src/cpu.c` | Linux /proc/stat 读取 |
| 删除 | `src/mem.c` | Linux /proc/meminfo 读取 |
| 删除 | `src/resource-usage.c` | 显示格式化 + 主入口 |
| 删除 | `src/resource-usage.h` | 头文件 |
| 删除 | `src/main.c` | 程序入口 |
| 删除 | `tests/test_cpu.c` | CPU 单元测试 |
| 删除 | `tests/test_mem.c` | 内存单元测试 |
| 删除 | `tests/test_display.c` | 显示格式化测试 |
| 删除 | `tests/test_status_line.c` | 状态行穷举测试 |
| 删除 | `tests/test_harness.h` | 测试框架 |
| 删除 | `Makefile` | 编译配置 |
| 新建 | `scripts/resource-usage.sh` | macOS 资源采集脚本 |
| 修改 | `tmux.conf` | 如有 macOS 特定调整 |
| 修改 | `scripts/status-right.sh` | 调用路径调整（如需要） |
| 修改 | `scripts/status-left.sh` | 调用路径调整（如需要） |
| 修改 | `CLAUDE.md` | 更新架构说明 |
| 修改 | `README.md` | 更新 Requirements 和 Installation |

## 风险

1. **CPU 采样延迟**：首次调用 `top` 需要后台启动，返回 0 值。用户体验为首次打开 tmux 时 CPU 显示为 0，后续正常。可接受。
2. **`top` 命令残留**：如果 tmux session 被 kill 而后台 `top` 仍在运行，会留下僵尸进程。清理策略：脚本启动时检查并清理上次遗留的 PID。
3. **性能**：`vm_stat` + `top` 每次调用约 5-10ms，status-right 每 1s 调用一次，对系统负载影响极小。
