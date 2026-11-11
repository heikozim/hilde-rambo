# Part of rambo.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# The targets of the scripts that build or test on another machine.
# Sourced with ., not run:
#
#     . "$here/scripts/remote.sh" || exit 9
#     remote_need RAMBO_HOST RAMBO_SSH_USER RAMBO_SSH_PORT || exit 9
#
# The values come from the environment, else from scripts/remote.env beside
# this file (template: scripts/remote.env.example).  A variable already set
# in the environment wins.  The file is not read as code: only lines
# KEY=VALUE with one of the keys below, without quotes; empty lines and
# lines starting with # do not count.  A value may hold only letters,
# digits and . _ - / @ : because the scripts put it into commands for ssh;
# a directory must be an absolute path without .., a port a number from 1
# to 65535.
#
# Keys:
#   RAMBO_HOST           the machine that builds and tests
#   RAMBO_SSH_USER       the user for ssh on RAMBO_HOST and RAMBO_BSD_HOST
#   RAMBO_SSH_PORT       the port of ssh on both
#   RAMBO_REMOTE_DIR     the directory of the work folders on RAMBO_HOST
#   RAMBO_BSD_HOST       the machine with the BSD guests
#   RAMBO_BSD_TOOLCHAIN  the directory of the archives hilde.tar and
#                        hiawatha.tar on RAMBO_BSD_HOST
#
# remote_need ends with 1 and one line ABORT for each missing or invalid
# key, else with 0.  An error reading the file ends the sourcing with 1.

REMOTE_KEYS="RAMBO_HOST RAMBO_SSH_USER RAMBO_SSH_PORT RAMBO_REMOTE_DIR RAMBO_BSD_HOST RAMBO_BSD_TOOLCHAIN"

# Whether $1 is one of the keys.
remote_known() {
	case " $REMOTE_KEYS " in *" $1 "*) return 0 ;; esac
	return 1
}

# Whether the value $2 fits the key $1.
remote_valid() {
	case "$2" in '' | *[!A-Za-z0-9._/@:-]*) return 1 ;; esac
	case "$1" in
		RAMBO_SSH_PORT)
			case "$2" in *[!0-9]* | 0*) return 1 ;; esac
			[ "$2" -le 65535 ] || return 1 ;;
		RAMBO_REMOTE_DIR | RAMBO_BSD_TOOLCHAIN)
			case "$2" in /*) ;; *) return 1 ;; esac
			case "/$2/" in */../* | */./*) return 1 ;; esac ;;
		*)
			case "$2" in -*) return 1 ;; esac ;;
	esac
	return 0
}

# Reads the file $1; a key from the environment stays.
remote_read() {
	local line key value n=0
	while IFS= read -r line || [ -n "$line" ]; do
		n=$((n + 1))
		case "$line" in '' | '#'*) continue ;; esac
		key=${line%%=*}
		value=${line#*=}
		if [ "$key" = "$line" ] || ! remote_known "$key"; then
			echo "ABORT: $1:$n is no line KEY=VALUE with a known key"
			return 1
		fi
		[ -n "${!key:-}" ] && continue
		printf -v "$key" '%s' "$value"
		export "${key?}"
	done < "$1"
	return 0
}

# Checks that every key named is set and fits.
remote_need() {
	local key bad=0
	for key in "$@"; do
		if [ -z "${!key:-}" ]; then
			echo "ABORT: $key is not set (environment or scripts/remote.env, see scripts/remote.env.example) -- nothing ran"
			bad=1
		elif ! remote_valid "$key" "${!key}"; then
			echo "ABORT: $key has an invalid value -- nothing ran"
			bad=1
		fi
	done
	return $bad
}

REMOTE_ENV=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/remote.env
if [ -e "$REMOTE_ENV" ]; then
	remote_read "$REMOTE_ENV" || return 1
fi
