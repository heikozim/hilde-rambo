#!/usr/bin/env bash
# Runs inside the container image (scripts/run.sh gate.sh): the gates that need Hilde,
# over rambo's sources and the modules of Wolly listed in
# scripts/wolly-modules.txt.
#
#   fmt        hilde fmt --check of every .hiq and .hih
#   contract-lint  every function of an interface under src and cmd states
#              a contract or a line "No contract: <reason>." in its docstring
#   check      hilde check of every module pair
#   unit       hilde test of every test file
#   contracts  hilde test --contracts of each module with a contract
#   egress     the programme imports no module that makes a connection
#   cli        the programme built and its commands run in a fresh directory
#
# Each prints one line gate=<name> rc=<n>; exit 0 only when all are 0.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/image/env.sh

wolly_pairs=()
wolly_tests=()
wolly_files=()
while read -r m; do
	case "$m" in ''|'#'*) continue ;; esac
	[ -r "$WOLLY/src/Wolly/$m.hih" ] || { echo "ABORT: Wolly.$m missing"; exit 9; }
	wolly_pairs+=("$WOLLY/src/Wolly/$m.hih,$WOLLY/src/Wolly/$m.hiq")
	wolly_files+=("$WOLLY/src/Wolly/$m.hih" "$WOLLY/src/Wolly/$m.hiq")
	[ -r "$WOLLY/src/Wolly/$m.test.hiq" ] && { wolly_tests+=("$WOLLY/src/Wolly/$m.test.hiq"); wolly_files+=("$WOLLY/src/Wolly/$m.test.hiq"); }
done < scripts/wolly-modules.txt
mapfile -t rambo_files < <(find src cmd -name '*.hi[qh]' 2> /dev/null | sort)
mapfile -t rambo_pairs < <(find src cmd -name '*.hih' 2> /dev/null | sort | sed 's/\.hih$//; s/.*/&.hih,&.hiq/')
mapfile -t rambo_tests < <(find src cmd -name '*.test.hiq' 2> /dev/null | sort)
echo "== rambo: ${#rambo_pairs[@]} modules, ${#rambo_tests[@]} test files; Wolly: ${#wolly_pairs[@]} modules, ${#wolly_tests[@]} test files"
[ ${#rambo_pairs[@]} -gt 0 ] || { echo "ABORT: no module found under src"; exit 9; }

overall=0
note() {
	echo "gate=$1 rc=$2"
	[ "$2" -eq 0 ] || overall=1
}

# The arguments name the steps to run, all of them when there are none; the
# last line names the steps that ran, so a part is never taken for the whole.
STEPS=${*:-fmt contract-lint check unit contracts egress cli}
want() {
	case " $STEPS " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

if want fmt; then
	"$HILDE" fmt --check "${rambo_files[@]}" "${wolly_files[@]}"
	note fmt $?
fi

# Hilde's own check when the Hilde of the image carries it, else the same
# rule in rambo's scripts/check-contracts.pl.
if want contract-lint; then
	if [ -r "$H/scripts/check-contracts.py" ]; then
		python3 "$H/scripts/check-contracts.py" src cmd
	else
		perl scripts/check-contracts.pl --self-test && perl scripts/check-contracts.pl src cmd
	fi
	note contract-lint $?
fi

if want check; then
	bad=0
	for p in "${rambo_pairs[@]}" "${wolly_pairs[@]}"; do
		"$HILDE" check "$p" --modules="$MODS" > "$RUN/check.out" 2>&1 || { bad=$((bad + 1)); cat "$RUN/check.out"; }
	done
	note check $bad
fi

if want unit; then
	"$HILDE" test --modules="$MODS" "${rambo_tests[@]}" "${wolly_tests[@]}"
	note unit $?
fi

# hilde test --contracts takes a directory of modules: each module with a
# requires or ensures in its interface goes alone into one, the rest of its
# tree beside it, as Wolly's own contracts step does it.
contract() {
	local tree=$1 ns=$2 m=$3 other=$4 c
	c=$RUN/contracts/$ns.$m
	mkdir -p "$c/one/$ns" "$c/rest" || return 9
	cp -R "$tree/$ns" "$c/rest/" || return 9
	mv "$c/rest/$ns/$m.hih" "$c/rest/$ns/$m.hiq" "$c/one/$ns/" || return 9
	rm -f "$c/rest/$ns/$m.test.hiq"
	[ ! -d "$tree/$ns/templates" ] || cp -R "$tree/$ns/templates" "$c/one/$ns/" || return 9
	"$HILDE" test --contracts --seed=20261022 --rounds=200 \
		--modules="$H/bindings/generated:$STD:$c/rest$other" "$c/one" > "$c.log" 2>&1
}
if want contracts; then
	rm -rf "$RUN/contracts" || exit 9
	good=0
	bad=0
	empty=0
	for p in "${wolly_pairs[@]}" "${rambo_pairs[@]}"; do
		hih=${p%%,*}
		case "$hih" in
		/*) ;;
		*) hih=$RAMBO/$hih ;;
		esac
		grep -q -E '^[[:space:]]+(requires|ensures) ' "$hih" || continue
		case "$hih" in
		"$WOLLY"/*) tree=$WOLLY/src other= ;;
		*) tree=$RAMBO/src other=:$WOLLY/src ;;
		esac
		rel=${hih#"$tree"/}
		ns=${rel%%/*}
		m=$(basename "$hih" .hih)
		if contract "$tree" "$ns" "$m" "$other"; then
			good=$((good + 1))
			grep -q " 0 tests," "$RUN/contracts/$ns.$m.log" && empty=$((empty + 1))
			echo "contracts $ns.$m: $(tail -1 "$RUN/contracts/$ns.$m.log")"
		else
			bad=$((bad + 1))
			echo "contracts $ns.$m failed"
			tail -15 "$RUN/contracts/$ns.$m.log"
		fi
	done
	echo "contracts: $good modules green, $empty of them without a function the generator can call, $bad red"
	[ "$good" -gt 0 ] || bad=$((bad + 1))
	note contracts $bad
fi

# The programme rambo only answers and never calls out itself, as the
# provider before it did, so that a relying party sees no difference.  So
# no module of its closure may open a connection of its own.
if ! want egress; then
	:
elif [ -r cmd/rambo/Rambo.hih ]; then
	mods=$(python3 -I "$WOLLY/scripts/modules.py" "$STD" "$H/bindings/generated" "$WOLLY/src" "$RAMBO/src" -- cmd/rambo/Rambo.hih,cmd/rambo/Rambo.hiq)
	r=$?
	if [ $r -ne 0 ]; then
		note egress 9
	else
		found=0
		for forbidden in HttpClient Smtp Resolve Acme Ssh Sftp RaftTcp; do
			if echo "$mods" | tr ' ,' '\n\n' | grep -q "/$forbidden\.hiq$"; then
				echo "egress: the programme imports Standard.$forbidden"
				found=$((found + 1))
			fi
		done
		# Standard.Database of the image imports the clients of PostgreSQL
		# and MariaDB; they connect only when opened, so no code of rambo
		# or of its Wolly modules may open them.  Wolly.TestDb opens
		# PostgreSQL and is the control that the pattern finds a call.
		# POSIX ERE without \b, which OpenBSD's grep does not know.
		pattern='open(Postgres|MariaDB|Mariadb)([^A-Za-z0-9_]|$)'
		grep -q -E "$pattern" "$WOLLY/src/Wolly/TestDb.hiq" || { echo "egress: the pattern finds no call in Wolly.TestDb"; found=$((found + 1)); }
		opened=$(grep -l -E "$pattern" "${rambo_files[@]}" "${wolly_files[@]}" | grep -v "\.test\.hiq$")
		if [ -n "$opened" ]; then
			echo "egress: a connection to a database server is opened in: $opened"
			found=$((found + 1))
		fi
		echo "egress: $(echo "$mods" | tr ' ,' '\n\n' | grep -c .) files looked at, ${#rambo_files[@]} of rambo and ${#wolly_files[@]} of Wolly searched for a call that opens a database server"
		note egress $found
	fi
else
	echo "egress: no programme yet (cmd/rambo) -- not run"
	note egress 0
fi

if want cli; then
	bash scripts/image/cli.sh > "$RUN/cli.out" 2>&1
	r=$?
	grep -a -E "^(cli|build-rambo)" "$RUN/cli.out"
	[ $r -eq 0 ] || grep -a -B12 -E "^step=.* rc=([0-9]+) want=" "$RUN/cli.out" | tail -40
	note cli $r
fi

echo "gate: overall=$overall steps=$STEPS"
exit $overall
