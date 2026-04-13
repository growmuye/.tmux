#!/bin/sh
# macOS 资源监控脚本 — 替代 Linux 下的 bin/resource_usage (C 二进制)
# 用法: resource-usage.sh [narrow]
# 输出: tmux 格式状态栏字符串（带 #[bg=colourX] 颜色代码）
#
# CPU：top -l 1 (即时返回，返回自启动以来的平均 CPU 利用率)
# 内存：vm_stat + sysctl hw.memsize (实时)

NARROW=0
if [ "${1:-}" = "narrow" ]; then
    NARROW=1
fi

# ==================== 颜色函数 ====================

color_code_for_rate() {
    rate_int=$1
    if [ "$rate_int" -ge 8500 ]; then
        echo "#[bg=colour1,fg=colour255]"
    elif [ "$rate_int" -ge 6000 ]; then
        echo "#[bg=colour3,fg=colour255]"
    else
        echo "#[bg=colour10,fg=colour255]"
    fi
}

# ==================== CPU 采集 ====================

get_cpu_data() {
    # top -l 1 即时返回
    top_output=$(top -l 1 -stats cpu -R 2>/dev/null)
    cpu_line=$(echo "$top_output" | grep 'CPU usage:' | head -1)

    if [ -z "$cpu_line" ]; then
        echo "0 1"
        return
    fi

    # 解析: CPU usage: X.XX% user, Y.YY% sys, Z.ZZ% idle
    # busy = user + sys (整数 * 100)
    busy_int=$(echo "$cpu_line" | awk '{
        for(i=1;i<=NF;i++) {
            if ($i == "usage:") { gsub(/%/,"",$(i+1)); user=$(i+1)+0 }
            if ($i == "user,") { gsub(/%/,"",$(i+1)); sys=$(i+1)+0 }
        }
        printf "%d", (user + sys) * 100
    }')

    echo "$busy_int"
}

# ==================== 内存采集 ====================

get_mem_data() {
    vm_output=$(vm_stat 2>/dev/null)
    if [ -z "$vm_output" ]; then
        echo "0 0"
        return
    fi

    page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)

    if [ "$total_bytes" -eq 0 ]; then
        echo "0 0"
        return
    fi

    # 解析 vm_stat — 移除句点
    pages_active=$(echo "$vm_output" | awk '/^Pages active:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    pages_inactive=$(echo "$vm_output" | awk '/^Pages inactive:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    pages_speculative=$(echo "$vm_output" | awk '/^Pages speculative:/ {gsub(/[^0-9]/,"",$3); print $3+0}')
    pages_wired=$(echo "$vm_output" | awk '/^Pages wired down:/ {gsub(/[^0-9]/,"",$4); print $4+0}')

    # used = active + inactive + speculative + wired
    used_pages=$(( pages_active + pages_inactive + pages_speculative + pages_wired ))
    used_bytes=$(( used_pages * page_size ))

    # rate * 10000 (整数)
    rate_int=$(( used_bytes * 10000 / total_bytes ))

    echo "$rate_int $total_bytes"
}

# ==================== 格式化输出 ====================

format_cpu_segment() {
    emoji=$1
    rate_int=$2
    is_narrow=$3

    color=$(color_code_for_rate "$rate_int")
    reset_color="#[bg=colour10,fg=colour255]"
    rate_str=$(awk "BEGIN { printf \"%3.1f\", $rate_int / 100.0 }")

    if [ "$is_narrow" -eq 1 ]; then
        printf '%s%s%s%%|%s' "$color" "$emoji" "$rate_str" "$reset_color"
    else
        printf '%s %s%s%s%%%s' "$reset_color" "$color" "$emoji" "$rate_str" "$reset_color"
    fi
}

format_mem_segment() {
    rate_int=$1
    total_bytes=$2

    if [ "$total_bytes" -eq 0 ]; then
        return
    fi

    color=$(color_code_for_rate "$rate_int")
    reset_color="#[bg=colour10,fg=colour255]"

    total_gb=$(awk "BEGIN { printf \"%.1f\", $total_bytes / 1073741824.0 }")
    in_use_gb=$(awk "BEGIN { printf \"%.1f\", $total_bytes / 1073741824.0 * $rate_int / 10000.0 }")

    if [ "$NARROW" -eq 1 ]; then
        printf '%s㎇%s/%s' "$color" "$in_use_gb" "$total_gb"
    else
        printf '%s %s㎇%s/%s%s ' "$reset_color" "$color" "$in_use_gb" "$total_gb" "$reset_color"
    fi
}

# ==================== 主流程 ====================

# 1. CPU 采集
cpu_data=$(get_cpu_data)
cpu_busy_int=$cpu_data
core_count=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
cpu_busy_int=${cpu_busy_int:-0}

# 2. 内存采集
mem_data=$(get_mem_data)
mem_rate_int=$(echo "$mem_data" | awk '{print $1}')
mem_total_bytes=$(echo "$mem_data" | awk '{print $2}')
mem_rate_int=${mem_rate_int:-0}
mem_total_bytes=${mem_total_bytes:-0}

# 3. 格式化输出
output=""

cpu_segment=$(format_cpu_segment "📊" "$cpu_busy_int" "$NARROW")
output="${output}${cpu_segment}"

mem_segment=$(format_mem_segment "$mem_rate_int" "$mem_total_bytes")
output="${output}${mem_segment}"

printf '%s' "$output"
