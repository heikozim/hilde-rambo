#!/usr/bin/env bash
# Runs inside the container image (scripts/run.sh probe-egress.sh): lists the files of
# the closure of the programme that name PostgreSQL or MariaDB, and the
# files of the closure that import them.
#
#     bash scripts/run.sh probe-egress.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh
mods=$(python3 -I "$WOLLY/scripts/modules.py" "$STD" "$H/bindings/generated" "$WOLLY/src" "$RAMBO/src" -- cmd/rambo/Rambo.hih,cmd/rambo/Rambo.hiq)
echo "$mods" | tr ' ,' '\n\n' | grep -i -E "postgres|mariadb"
for f in $(echo "$mods" | tr ' ,' '\n\n'); do
	if grep -q -E "^import Standard\.(Postgres|MariaDB|Database\.Postgres|Database\.MariaDB) " "$f" 2> /dev/null; then
		echo "imports a backend: $f"
	fi
done
echo "probe-done"
