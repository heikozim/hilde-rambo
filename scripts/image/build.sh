#!/usr/bin/env bash
# Runs inside the container image (scripts/run.sh build.sh): compiles the programme of
# cmd/rambo into _run/bin/rambo, with the modules of its closure from the
# standard library, Wolly and rambo.
#
#     bash scripts/run.sh build.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh

pair=cmd/rambo/Rambo.hih,cmd/rambo/Rambo.hiq
mods=$(python3 -I "$WOLLY/scripts/modules.py" "$STD" "$H/bindings/generated" "$WOLLY/src" "$RAMBO/src" -- "$pair")
r=$?
[ $r -eq 0 ] || { echo "build: the modules were not found (rc=$r)"; exit 1; }
mkdir -p "$RUN/bin" || exit 9
# shellcheck disable=SC2086
"$HILDE" compile $mods --entrypoint=Rambo.Main:main --output="$RUN/bin/rambo"
r=$?
echo "build-rambo-rc=$r ($(echo "$mods" | wc -w) files)"
exit $r
