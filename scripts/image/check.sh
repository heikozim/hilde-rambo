#!/usr/bin/env bash
# Runs inside the container image: hilde check of each pair X.hih,X.hiq given, paths
# relative to the rambo tree, or ../wolly/... for a module of Wolly.  Exit 0
# only when every one checks.
#
#     bash scripts/run.sh check.sh src/Rambo/Config.hih,src/Rambo/Config.hiq
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh
[ $# -gt 0 ] || { echo "ABORT: no file" >&2; exit 9; }
n=0
bad=0
for f in "$@"; do
	"$HILDE" check "$f" --modules="$MODS"
	r=$?
	echo "check $f rc=$r"
	n=$((n + 1))
	[ $r = 0 ] || bad=$((bad + 1))
done
echo "checked $n, red $bad"
[ $n -gt 0 ] && [ $bad = 0 ]
