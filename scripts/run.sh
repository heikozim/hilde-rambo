#!/usr/bin/env bash
# Runs on the workstation: sends the rambo tree and the Wolly tree it builds on into
# a container of the build image on the build host and runs one script of
# scripts/image/ there.  Nothing is written on the host: the two trees go to
# the container as one tar on standard input, unpacked at /tmp/w/rambo and
# /tmp/w/wolly, and end with it.
#
#     bash scripts/run.sh <script> [args...]
#
# WOLLY_TREE names the Wolly tree (default ../wolly beside this tree),
# RAMBO_IMAGE the image (default wolly-dev:latest).  The build host and its
# ssh user and port are RAMBO_HOST, RAMBO_SSH_USER and RAMBO_SSH_PORT, from
# the environment or scripts/remote.env (scripts/remote.sh).
# HILDE_OVERLAY names a Hilde tree whose files listed in
# scripts/hilde-overlay.txt replace those of the image's standard library
# (default ../hilde beside this tree when that list is not empty), for a
# change of Hilde that is not in the image yet.
[ "${BASH_VERSINFO[0]:-0}" -ge 3 ] || { echo "ABORT: bash too old"; exit 9; }
set -u
script=${1:?script}
shift
here=$(cd "$(dirname "$0")/.." && pwd)
wolly=${WOLLY_TREE:-$(dirname "$here")/wolly}
. "$here/scripts/remote.sh" || exit 9
remote_need RAMBO_HOST RAMBO_SSH_USER RAMBO_SSH_PORT || exit 9
image=${RAMBO_IMAGE:-wolly-dev:latest}
[ -r "$here/scripts/image/$script" ] || { echo "ABORT: scripts/image/$script missing"; exit 9; }
[ -d "$wolly/src/Wolly" ] || { echo "ABORT: $wolly is no Wolly tree"; exit 9; }
parent_r=$(dirname "$here")
name_r=$(basename "$here")
parent_w=$(dirname "$wolly")
name_w=$(basename "$wolly")
overlay=${HILDE_OVERLAY:-$(dirname "$here")/hilde}
parent_h=$(dirname "$overlay")
name_h=$(basename "$overlay")
files=()
while read -r f; do
	case "$f" in ''|'#'*) continue ;; esac
	[ -r "$overlay/$f" ] || { echo "ABORT: $overlay/$f missing"; exit 9; }
	files+=("$name_h/$f")
done < "$here/scripts/hilde-overlay.txt"
# The trees under the names the scripts in the image expect.
pack() {
	COPYFILE_DISABLE=1 tar --no-xattrs -cf - --exclude=.git --exclude=_run --exclude='._*' \
		-s ",^$name_r/,rambo/," -s ",^$name_w/,wolly/," -s ",^$name_h/,hilde/," \
		-C "$parent_r" "$name_r" -C "$parent_w" "$name_w/src" "$name_w/scripts" \
		-C "$parent_h" "${files[@]}"
}
pack | ssh -o BatchMode=yes -o ConnectTimeout=10 -p "$RAMBO_SSH_PORT" "$RAMBO_SSH_USER@$RAMBO_HOST" \
	"[ -S /run/user/\$(id -u)/docker.sock ] && export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock; docker run --rm -i --network=none -u 1000:1000 -e HOME=/tmp/w/rambo/_run -w /tmp $image bash -c 'mkdir -p /tmp/w && tar -xf - -C /tmp/w && cd /tmp/w/rambo && exec bash scripts/image/\$0 \"\$@\" < /dev/null' $script $*"
st=("${PIPESTATUS[@]}")
echo "pack-rc=${st[0]} run-rc=${st[1]}"
[ "${st[0]}" -eq 0 ] || exit 9
exit "${st[1]}"
