#!/bin/sh

set -eu

dir_name=$(dirname "$0")
. "$dir_name/helpers.sh"

if [ "$(get_width)" -gt 200 ]; then
	echo "$($dir_name/resource-usage.sh)#[bg=colour235] $(date +'%a %Y/%m/%d %H:%M:%S') "
else
	echo "$($dir_name/resource-usage.sh narrow)#[bg=colour235] $(date +'%m/%d %H:%M:%S') "
fi
