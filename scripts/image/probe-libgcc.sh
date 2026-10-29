#!/usr/bin/env bash
# Runs inside the container image (scripts/run.sh probe-libgcc.sh): says whether the
# image holds libgcc_s.so.1, which glibc loads for pthread_exit.
#
#     bash scripts/run.sh probe-libgcc.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
found=0
for d in /lib /usr/lib /lib64 /usr/lib64 /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu; do
	if [ -e "$d/libgcc_s.so.1" ]; then
		echo "libgcc: $d/libgcc_s.so.1"
		found=$((found + 1))
	fi
done
echo "libgcc-found=$found"
head -3 /etc/os-release
