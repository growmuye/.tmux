#!/bin/sh

set -eu

dir_name=$(dirname "$0")
. "$dir_name/helpers.sh"

if [ "$(get_width)" -gt 200 ]; then
	echo " $(hostname) #[fg=colour165]tmux:$(tmux display-message -p '#{session_name}') "
else
	echo " $(hostname) $(tmux display-message -p '#{session_name}') "
fi
