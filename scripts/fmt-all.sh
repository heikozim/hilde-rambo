#!/usr/bin/env bash
# Runs on the workstation: brings every .hiq and .hih of rambo and of the Wolly
# modules in scripts/wolly-modules.txt into Hilde's one form (scripts/fmt.sh).
#
#     bash scripts/fmt-all.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 3 ] || { echo "ABORT: bash too old"; exit 9; }
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
wolly=${WOLLY_TREE:-$(dirname "$here")/wolly}
files=()
while read -r m; do
	case "$m" in ''|'#'*) continue ;; esac
	for e in hih hiq test.hiq; do
		[ -e "$wolly/src/Wolly/$m.$e" ] && files+=("../wolly/src/Wolly/$m.$e")
	done
done < "$here/scripts/wolly-modules.txt"
while read -r f; do
	files+=("$f")
done < <(cd "$here" && find src cmd -name '*.hi[qh]' 2> /dev/null | sort)
[ ${#files[@]} -gt 0 ] || { echo "ABORT: no file"; exit 9; }
exec bash "$here/scripts/fmt.sh" "${files[@]}"
