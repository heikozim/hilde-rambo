#!/usr/bin/env bash
# Runs inside the container image: hilde fmt of the files given, paths relative to the
# rambo tree or ../wolly/...; prints each file that changed between the
# lines "=== file <path>" and "=== end", its new text in Base64, for
# scripts/fmt.sh to write back.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh > /dev/null
[ $# -gt 0 ] || { echo "ABORT: no file" >&2; exit 9; }
changed=0
for f in "$@"; do
	cp "$f" "$RUN/before" || exit 9
	"$HILDE" fmt "$f" > /dev/null || { echo "ABORT: hilde fmt $f failed" >&2; exit 9; }
	if ! cmp -s "$RUN/before" "$f"; then
		echo "=== file $f"
		base64 < "$f"
		echo "=== end"
		changed=$((changed + 1))
	fi
done
echo "fmt: $# files, $changed changed" >&2
