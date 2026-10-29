#!/usr/bin/env bash
# Runs inside the container image: hilde test of the test files given (X.test.hiq,
# paths relative to the rambo tree or ../wolly/...), or of every test under
# src when none is given.  ARGS adds options of hilde test (--contracts).
#
#     bash scripts/run.sh unit.sh ../wolly/src/Wolly/OpKey.test.hiq
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh
if [ $# -eq 0 ]; then
	set -- src
fi
# shellcheck disable=SC2086
"$HILDE" test ${ARGS:-} --modules="$MODS" "$@"
r=$?
echo "unit-rc=$r"
exit $r
