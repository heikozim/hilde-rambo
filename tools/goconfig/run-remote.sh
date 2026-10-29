#!/usr/bin/env bash
# Runs on the workstation: runs goconfig on the build host RAMBO_HOST over
# testdata/config/inputs.txt and writes its answers to
# testdata/config/expected.txt.  The work directory there is
# RAMBO_REMOTE_DIR/rambo-goconfig; it is removed afterwards.  The host, its
# ssh user and port and RAMBO_REMOTE_DIR come from the environment or
# scripts/remote.env (scripts/remote.sh).
#
#     bash tools/goconfig/run-remote.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 3 ] || { echo "ABORT: bash too old"; exit 9; }
set -u
here=$(cd "$(dirname "$0")/../.." && pwd)
. "$here/scripts/remote.sh" || exit 9
remote_need RAMBO_HOST RAMBO_SSH_USER RAMBO_SSH_PORT RAMBO_REMOTE_DIR || exit 9
work=$RAMBO_REMOTE_DIR/rambo-goconfig
ssh_=(ssh -o BatchMode=yes -o ConnectTimeout=10 -p "$RAMBO_SSH_PORT" "$RAMBO_SSH_USER@$RAMBO_HOST")
COPYFILE_DISABLE=1 tar --no-xattrs -C "$here/tools" -cf - goconfig |
	"${ssh_[@]}" "rm -rf $work && mkdir -p $work && tar -xf - -C $work"
st=("${PIPESTATUS[@]}")
[ "${st[0]}" -eq 0 ] && [ "${st[1]}" -eq 0 ] || { echo "send-rc=${st[*]}"; exit 9; }
"${ssh_[@]}" "cd $work/goconfig && GOFLAGS=-mod=mod GOPROXY=off go run ." < "$here/testdata/config/inputs.txt" > "$here/testdata/config/expected.txt"
rc=$?
echo "run-rc=$rc lines=$(wc -l < "$here/testdata/config/expected.txt")"
"${ssh_[@]}" "rm -rf $work; test -e $work && echo left || echo removed" < /dev/null
exit $rc
