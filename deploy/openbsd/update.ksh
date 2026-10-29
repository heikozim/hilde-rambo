#!/bin/ksh
#
# Part of rambo.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Puts a new rambo binary in place of the running one on its OpenBSD host,
# as root, from the unpacked package:
#
#     cd /home/<user>/rambo-update && ksh ./update.ksh
#
# Every check that can refuse runs before the first change.  Then the
# running binary is copied to the backup directory, the new one is moved in
# place, rambo is restarted, and /jwks must name the same key ids as
# before.  Any failure after the copy puts the old binary back and restarts
# it.  The data are not touched.  The output is the record of the run; it
# holds no secret.  The issuer is the key issuer of rambo.conf.
set -u
umask 077
PKG=$(pwd)
BIN=/usr/local/sbin/rambo
RC=/etc/rc.d/rambo
CONF=/etc/rambo/rambo.conf
BACK=/var/backups/rambo-update

die() { echo "STOP: $* -- nothing was changed"; exit 1; }
sum() { sha256 -q "$1"; }
conf() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p" "$CONF" | tail -1; }
kids() { ftp -V -o - "$ISSUER/jwks" 2> /dev/null | tr ',' '\n' | sed -n 's/.*"kid":"\([^"]*\)".*/\1/p' | sort; }

echo "== checks $(date)"
[ "$(uname -s)" = OpenBSD ] || die "not OpenBSD"
# The binary of the package is built on this release; OpenBSD keeps no
# binary compatibility between releases.
[ "$(uname -r)" = "$(cat "$PKG/RELEASE" 2> /dev/null)" ] || die "the package is built for OpenBSD $(cat "$PKG/RELEASE" 2> /dev/null), this host runs $(uname -r)"
[ "$(id -u)" = 0 ] || die "not root"
[ -r "$PKG/SHA256" ] || die "no SHA256 in $PKG"
(cd "$PKG" && sha256 -c -q SHA256) || die "a file of the package does not match SHA256"
for f in rambo rc.d/rambo; do
	[ -r "$PKG/$f" ] || die "$PKG/$f missing"
done
[ ! -e "$BACK" ] || die "$BACK exists: an earlier update; look at it and move it away first"
[ -x "$BIN" ] || die "no $BIN"
[ -r "$CONF" ] || die "no $CONF"
ISSUER=$(conf issuer)
case "$ISSUER" in https://*) ;; *) die "issuer in $CONF is not https://host";; esac
case "${ISSUER#https://}" in ''|*[!A-Za-z0-9.-]*|.*|-*) die "issuer in $CONF is not https://host";; esac
[ "$(sum "$RC")" = "$(sum "$PKG/rc.d/rambo")" ] || die "$RC is not rambo's rc.d script: switch over first"
rcctl check rambo > /dev/null || die "rambo does not run"
before=$(kids)
[ -n "$before" ] || die "$ISSUER/jwks names no key"
old=$("$BIN" version 2> /dev/null)
echo "running: $old, binary $(sum "$BIN")"
echo "kids before: $(echo $before)"
# The binary is tried where it will run: the package may lie on a file
# system mounted noexec, as /home often is.
install -o root -g bin -m 0555 "$PKG/rambo" "$BIN.new" || die "install $BIN.new"
if ! new=$("$BIN.new" version 2> "$BIN.new.err"); then
	sed 's/^/  /' "$BIN.new.err"
	rm -f "$BIN.new" "$BIN.new.err"
	die "the new binary does not run here"
fi
rm -f "$BIN.new.err"
echo "new: $new, binary $(sum "$BIN.new")"
echo "checks ok"

back() {
	echo "FAILED: $* -- back to the old binary"
	install -o root -g bin -m 0555 "$BACK/rambo.bin" "$BIN" && rcctl restart rambo
	echo "back: $("$BIN" version 2> /dev/null), binary $(sum "$BIN")"
	exit 1
}

echo "== keep the old binary in $BACK"
install -d -o root -g wheel -m 0700 "$BACK" || { rm -f "$BIN.new"; die "install -d $BACK"; }
cp -p "$BIN" "$BACK/rambo.bin" || { rm -f "$BIN.new"; die "copy to $BACK"; }
(cd "$BACK" && sha256 rambo.bin > SHA256) || { rm -f "$BIN.new"; die "sum of $BACK"; }

echo "== put the new binary in place and restart"
mv -f "$BIN.new" "$BIN" || back "mv $BIN.new $BIN"
rcctl restart rambo || back "rcctl restart rambo"
after=""
for i in 1 2 3 4 5 6 7 8 9 10; do
	after=$(kids)
	[ -n "$after" ] && break
	sleep 1
done
echo "kids after: $(echo $after)"
[ "$after" = "$before" ] || back "/jwks names other key ids than before"
echo "UPDATED: $("$BIN" version), binary $(sum "$BIN"); the old one is kept in $BACK"
