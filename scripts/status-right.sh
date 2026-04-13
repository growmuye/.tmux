#!/bin/sh

set -eu

dir_name=$(dirname "$0")
. "$dir_name/helpers.sh"

resource_bar=$("$dir_name/resource-usage.sh")

if [ "$(get_width)" -gt 200 ]; then
    time_bar="#[bg=colour235,fg=colour250] $(date +'%a %Y/%m/%d %H:%M:%S') "
else
    time_bar="#[bg=colour235,fg=colour250] $(date +'%m/%d %H:%M:%S') "
fi

echo "${resource_bar}${time_bar}"
