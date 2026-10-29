#!/usr/bin/env bash
# Runs inside the container image (scripts/run.sh cli.sh): builds rambo and runs its
# commands in a fresh directory as an operator would, printing what each
# printed and its exit status.  Every step prints one line step=<name>
# rc=<n> want=<n>; the run exits 0 only when every rc is the one wanted.
#
#     bash scripts/run.sh cli.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh

bash scripts/image/build.sh || exit 1
bin=$RUN/bin/rambo
dir=$RUN/cli
rm -rf "$dir" && mkdir -p "$dir/etc" "$dir/var" "$dir/run" || exit 9
conf=$dir/etc/rambo.conf
printf 'issuer = https://auth.example.org\netc_dir = %s\nvar_dir = %s\nsocket_dir = %s\ndb = %s\nvault = %s\npepper = %s\n' \
	"$dir/etc" "$dir/var" "$dir/run" "$dir/var/rambo.db" "$dir/etc/.rambo.env" "$dir/var/.rambo_pepper" > "$conf" || exit 9
export RAMBO_CONFIG=$conf

good=0
bad=0
# step <name> <wanted rc> <args...>: runs rambo with args, shows its output.
step() {
	local name=$1 want=$2 rc
	shift 2
	echo "---- rambo $*"
	"$bin" "$@" > "$dir/out" 2> "$dir/err" < /dev/null
	rc=$?
	cat "$dir/out"
	sed 's/^/stderr: /' "$dir/err"
	echo "step=$name rc=$rc want=$want"
	if [ "$rc" -eq "$want" ]; then good=$((good + 1)); else bad=$((bad + 1)); fi
}

step version 0 version
# want <name> <perl test on the output>: one more step on what rambo printed.
want() {
	local name=$1 test=$2
	if perl -0777 -ne "exit((do { $test }) ? 0 : 1)" "$dir/out"; then
		echo "step=$name ok"; good=$((good + 1))
	else
		echo "step=$name FAILED"; bad=$((bad + 1))
	fi
}
want version-line '/\Arambo 0\.2\.0, Copyright \(C\) 2026 Heiko Zimmermann\n\z/'
step version-flag 0 -V
step version-full 0 version --full
want version-fields '/\Aversion     0\.2\.0\ncommit      \S+.*\nbuilt       \S+\ncompiler    hilde \S+\nsystem      \S+\/\S+\nlibrary     libcrypto \S.*\nlibrary     sqlcipher 3\.\S+\ncopyright   Copyright \(C\) 2026 Heiko Zimmermann\n\z/'
step version-flag-full 0 --version --full
want version-flag-fields '/\Aversion     0\.2\.0\n/ && /\ncopyright   Copyright \(C\) 2026 Heiko Zimmermann\n\z/'
step info 0 info
want info-fields '/\A ____      _    __  __ ____   ___\n/ && /\nRights, Accounts, Multi-factor, Bearer tokens & OAuth\n\nname        rambo\nversion     0\.2\.0\ncommit      .*\nsystem      \S+\narch        \S+\nconfig      \S*rambo\.conf\nbinary      \S+\ncompiler    hilde \S+\nhost        \S+\ntime        \S+Z\n\z/'
step help 0 --help
step init 0 setup init
step init-again 0 setup init
step setup-list 0 setup list
step add-alice 0 account add alice@example.org --name Alice
step add-bob 0 account add bob@example.org
step add-taken 1 account add Alice@Example.org
step add-bad 1 account add not-an-address
step list 0 account list
step lock-no-yes 1 account lock bob@example.org
step lock 0 account lock bob@example.org --yes
step list-locked 0 account list
step unlock 0 account unlock bob@example.org
step set-name 0 account set-name bob@example.org Bob
step client-add 0 client add --id lucy --name Lucy --kind web --redirect https://lucy.example.org/cb --start-url https://lucy.example.org/login
step client-native 0 client add --id cli --name Cli --kind native --redirect http://127.0.0.1/cb
step client-bad 1 client add --id x --kind web
step client-list 0 client list
step client-alg-rs256 1 client alg lucy RS256
step client-alg 0 client alg lucy ML-DSA-44
step client-alg-hybrid 0 client alg lucy ML-DSA-44-Ed25519
step client-alg-default 0 client alg lucy default
step client-add-rs256 1 client add --id x2 --name X --kind web --redirect https://x.example.org/cb --alg RS256
step client-alg-bad 1 client alg lucy HS256
step client-lax 0 client lax lucy on
step client-limits 0 client limits lucy --idle 30m
step client-disable-no-yes 1 client disable lucy
step client-list-2 0 client list
step role-grant 0 role grant alice@example.org lucy admin
step role-grant-again 0 role grant alice@example.org lucy admin
step role-list 0 role list
step role-revoke-no-yes 1 role revoke alice@example.org lucy admin
step session-list 0 session list
step keys 0 keys rotate
# one new key of each family, each line with its algorithm and its kid
n=$(grep -c -E '^signing key ML-DSA-44(-Ed25519)? [A-Za-z0-9_-]{43}$' "$dir/out")
echo "step=keys-lines n=$n want=2"
if [ "$n" = 2 ]; then good=$((good + 1)); else bad=$((bad + 1)); fi
step reset-password 0 account reset-password bob@example.org --yes
step delete 0 account delete bob@example.org --yes
step list-after 0 account list
step unknown 1 account frobnicate
step sandbox 0 sandbox
want sandbox-form '/\Asandbox:     [a-z-]+(, [a-z-]+)*\n\n  promises: stdio\n\nsandbox profile "rambo-serve" \(\S+\/\S+\)\n  promises: stdio rpath[a-z ]*\n(  \w+: \/\S* \([rwxc]+\)\n)+  paths: \d+\n\nsandbox profile "rambo-admin" \(\S+\/\S+\)\n  promises: stdio rpath[a-z ]* tty\n(  \w+: \/\S* \([rwxc]+\)\n)+  paths: \d+\n\z/ && !/\n\n\n/'
want sandbox-count 'my $ok = 0; for my $p (split /\n\n/) { next unless $p =~ /\Asandbox profile/; my $n = () = $p =~ /^  \w+: \//mg; if ($p =~ /\n  paths: (\d+)\n?\z/ && $1 == $n) { $ok++ } else { $ok = -9 } } $ok == 2'
want sandbox-once 'my %s; my $d = 0; for my $p (split /\n\n/) { %s = (); for (grep { /^  \w+: \// } split /\n/, $p) { $d++ if $s{$_}++ } } $d == 0'
want sandbox-sorted 'my $ok = 1; for my $p (split /\n\n/) { my @l = grep { /^  \w+: \// } split /\n/, $p; $ok = 0 if join("\n", @l) ne join("\n", sort @l) } $ok'
step sandbox-flag 0 -s

# serve: two root accounts, HTTP on the loopback, the files of www.
step serve-without-roots 1 serve
step add-root2 0 account add root2@example.org
ids=$("$bin" account list | awk 'NR > 1 && ($2 == "alice@example.org" || $2 == "root2@example.org") { print $1 }' | tr '\n' ' ')
printf 'root_accounts = %s\nlisten = http\nhttp_addr = 127.0.0.1:18480\n' "$ids" >> "$conf"
export RAMBO_WWW=$RAMBO/www
"$bin" serve > "$dir/serve.out" 2>&1 &
pid=$!
up=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if curl -s -o /dev/null http://127.0.0.1:18480/jwks; then
		up=1
		break
	fi
	sleep 1
done
echo "serve-up=$up"
# fetch <name> <wanted status> <path> [curl args...]: one request, its status.
fetch() {
	local name=$1 want=$2 path=$3 got
	shift 3
	got=$(curl -s -o "$dir/body" -w '%{http_code}' "$@" "http://127.0.0.1:18480$path")
	echo "---- GET $path"
	head -c 300 "$dir/body"
	echo
	echo "step=$name rc=$got want=$want"
	if [ "$got" = "$want" ]; then good=$((good + 1)); else bad=$((bad + 1)); fi
}
if [ "$up" -eq 1 ]; then
	fetch discovery 200 /.well-known/openid-configuration
	fetch jwks 200 /jwks
	fetch css 200 /static/rambo.css
	fetch worker 200 /pow-worker.js
	fetch login 302 /login
	fetch nothing 404 /nowhere
	fetch climb 404 /static/../etc/rambo.conf
	fetch token-get 405 /token
	fetch token-post 401 /token -d grant_type=client_credentials
else
	bad=$((bad + 1))
	cat "$dir/serve.out"
fi
kill "$pid" 2> /dev/null
wait "$pid" 2> /dev/null

# migrate: a copy of a data set of the earlier Go provider, taken over and served.
old=$RUN/old
rm -rf "$old" && mkdir -p "$old/etc" "$old/var" "$old/run" || exit 9
cp testdata/gorambo/.rambo.env "$old/etc/.rambo.env" || exit 9
cp testdata/gorambo/.rambo_pepper "$old/var/.rambo_pepper" || exit 9
cp testdata/gorambo/rambo.db "$old/var/rambo.db" || exit 9
issuer=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["issuer"])' testdata/gorambo/expected.json)
roots=$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["alice_id"], d["bob_id"])' testdata/gorambo/expected.json)
printf 'issuer = %s\netc_dir = %s\nvar_dir = %s\nsocket_dir = %s\ndb = %s\nvault = %s\npepper = %s\n' \
	"$issuer" "$old/etc" "$old/var" "$old/run" "$old/var/rambo.db" "$old/etc/.rambo.env" "$old/var/.rambo_pepper" > "$old/etc/rambo.conf" || exit 9
export RAMBO_CONFIG=$old/etc/rambo.conf
step migrate 0 migrate
if grep -q 'clients the Go provider marked RS256, now ML-DSA-44: 1' "$dir/out"; then
	echo "step=migrate-names-rs256 rc=1 want=1"
	good=$((good + 1))
else
	echo "step=migrate-names-rs256 rc=0 want=1"
	bad=$((bad + 1))
fi
# The data set of the earlier Go provider is at oidcop 6: migrate raises it to 7
# as the Go library v0.95.0 does, the ledger and the column sign_alg.
seven=$(python3 -I -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); v=c.execute("select max(version) from oidcop_schema").fetchone()[0]; n=sum(1 for r in c.execute("pragma table_info(op_clients)") if r[1] == "sign_alg"); print(v, n)' "$old/var/rambo.db")
echo "step=migrate-raised ledger,column=$seven want=7 1"
if [ "$seven" = "7 1" ]; then good=$((good + 1)); else bad=$((bad + 1)); fi
step gitea-alg 0 client alg gitea ML-DSA-44
step gitea-alg-hybrid 0 client alg gitea ML-DSA-44-Ed25519
step gitea-alg-default 0 client alg gitea default
step migrated-accounts 0 account list
step migrated-clients 0 client list
step migrated-roles 0 role list
printf 'root_accounts = %s\nlisten = http\nhttp_addr = 127.0.0.1:18481\n' "$roots" >> "$old/etc/rambo.conf"
"$bin" serve > "$old/serve.out" 2>&1 &
pid=$!
up=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if curl -s -o "$old/jwks" http://127.0.0.1:18481/jwks; then
		up=1
		break
	fi
	sleep 1
done
# passkeys: alice adds one on her account page and signs in with it; the
# command line lists it, revokes it, and it signs nobody in.
# e2e <mode>: one run of passkey-e2e.py, its steps counted with ours.
e2e() {
	local out=$old/e2e-$1.out g b
	python3 -I scripts/image/passkey-e2e.py "$1" 18481 testdata/gorambo/expected.json \
		"$WOLLY/scripts/passkey-authenticator.py" "$old/passkey.pem" > "$out" 2>&1
	echo "e2e-$1-rc=$?"
	cat "$out"
	g=$(awk '/^passkey-e2e: / { print $2 }' "$out")
	b=$(awk '/^passkey-e2e: / { print $5 }' "$out")
	if [ -n "$g" ] && [ -n "$b" ]; then
		good=$((good + g))
		bad=$((bad + b))
	else
		bad=$((bad + 1))
	fi
}
openssl ecparam -name prime256v1 -genkey -noout -out "$old/passkey.pem" 2> /dev/null || exit 9
if [ "$up" -eq 1 ]; then
	e2e add
	alice=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["alice_email"])' testdata/gorambo/expected.json)
	step passkey-list 0 passkey list
	step passkey-list-alice 0 passkey list "$alice"
	if grep -q 'EBESExQVFhcYGRobHB0eHw.*Notebook' "$dir/out" && ! grep -q 'never$' "$dir/out"; then
		echo "step=passkey-list-shows rc=1 want=1"
		good=$((good + 1))
	else
		echo "step=passkey-list-shows rc=0 want=1"
		bad=$((bad + 1))
	fi
	step passkey-revoke-no-yes 1 passkey revoke EBESExQVFhcYGRobHB0eHw
	step passkey-revoke 0 passkey revoke EBESExQVFhcYGRobHB0eHw --yes
	step passkey-revoke-again 1 passkey revoke EBESExQVFhcYGRobHB0eHw --yes
	step reset-passkeys-no-yes 1 account reset-passkeys "$alice"
	step reset-passkeys 0 account reset-passkeys "$alice" --yes
	e2e revoked
else
	bad=$((bad + 1))
	cat "$old/serve.out"
fi
kill "$pid" 2> /dev/null
wait "$pid" 2> /dev/null
python3 -I -c 'import json,sys; want=json.load(open(sys.argv[1]))["jwks"]; got=open(sys.argv[2]).read(); i=next((k for k in range(min(len(got),len(want))) if got[k]!=want[k]), min(len(got),len(want))); print("jwks: got", len(got), "want", len(want), "first difference at", i, repr(got[max(0,i-40):i+40]), repr(want[max(0,i-40):i+40]))' testdata/gorambo/expected.json "$old/jwks"
same=$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); want=json.loads(d["jwks"])["keys"]; got=json.loads(open(sys.argv[2]).read())["keys"]; kids={k["kid"] for k in got}; pure=[k for k in got if k.get("alg") == "ML-DSA-44"]; hybrid=[k for k in got if k.get("alg") == "ML-DSA-44-Ed25519"]; print(1 if all(k in want for k in pure) and len(pure) + len(hybrid) == len(got) and len(hybrid) == 1 and d["id_kid"] in kids and d["gitea_kid"] not in kids and all(k["kty"] == "AKP" for k in got) else 0)' testdata/gorambo/expected.json "$old/jwks")
echo "---- GET /jwks of the taken-over installation: up=$up every ML-DSA-44 key one of the Go provider's, the one there, one new ML-DSA-44-Ed25519 key, no RSA key=$same"
echo "step=migrated-jwks rc=$same want=1"
if [ "$same" = 1 ]; then good=$((good + 1)); else bad=$((bad + 1)); cat "$old/serve.out"; fi
rsaname=$(python3 -I -c 'import hashlib,json,sys; k=json.load(open(sys.argv[1]))["gitea_kid"]; print("RAMBO_SIGNING_KEY_" + hashlib.sha256(k.encode()).hexdigest()[:16].upper())' testdata/gorambo/expected.json)
kept=$("$bin" setup list 2> /dev/null | grep -c "^  $rsaname\$")
echo "---- the Go provider's RSA key $rsaname in the vault after serving: $kept"
if [ "$kept" = 1 ]; then good=$((good + 1)); echo "step=rsa-key-kept rc=1 want=1"; else bad=$((bad + 1)); echo "step=rsa-key-kept rc=0 want=1"; fi
python3 -I -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute("insert into oidcop_schema (version) values (8)"); c.commit()' "$old/var/rambo.db"
step migrate-too-new 1 migrate
echo "cli: $good steps as wanted, $bad not"
[ "$bad" -eq 0 ]
