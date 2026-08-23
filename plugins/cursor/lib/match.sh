#!/bin/bash
set -euo pipefail

is_agents_window_title() {
	local trimmed="$1"
	trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
	trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
	local lower
	lower=$(printf '%s' "$trimmed" | /usr/bin/tr '[:upper:]' '[:lower:]')
	[[ "$lower" == agents ]] && return 0
	printf '%s\n' "$trimmed" | /usr/bin/grep -qiF -- "Cursor Agents" && return 0
	printf '%s\n' "$trimmed" | /usr/bin/grep -qiF -- "Agents Window" && return 0
	return 1
}

if [[ "$(basename "$0")" == match.sh ]]; then
	case "${1-}" in
	is-agents)
		is_agents_window_title "${2-}"
		;;
	*)
		printf '%s\n' "usage: match.sh is-agents <title>" >&2
		exit 2
		;;
	esac
fi
