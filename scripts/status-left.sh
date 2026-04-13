#!/bin/sh

set -eu

dir_name=$(dirname "$0")
. "$dir_name/helpers.sh"

# Get the session name of the currently attached client
session_name=$(tmux list-sessions -F '#{?session_attached,#{session_name},}' | grep -v '^$' | head -1)
session_name=${session_name:-none}

if [ "$(get_width)" -gt 200 ]; then
	echo " $(hostname) #[fg=colour165]tmux:${session_name} "
else
	echo " $(hostname) ${session_name} "
fi
