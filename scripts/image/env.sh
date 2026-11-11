# Sourced by the scripts under scripts/image/, from the root of the rambo
# tree.  Names the tools and the directories of the modules a rambo
# programme is compiled with, in one of two places:
#
#   - inside the container image (scripts/run.sh), which /etc/wolly-dev marks;
#   - in a BSD guest, where WOLLY_TOOLS names the directory with the Hilde
#     tree and the Hiawatha build made there, and $WOLLY_TOOLS/wolly-tools
#     says what they were built from.
#
# The Wolly tree stands beside the rambo tree as ../wolly in both.
if [ -r /etc/wolly-dev ]; then
	RAMBO_PLACE=image
	H=/opt/hilde
	HILDE=/usr/local/bin/hilde
	HIAWATHA=/usr/local/sbin/hiawatha
elif [ -n "${WOLLY_TOOLS:-}" ] && [ -r "$WOLLY_TOOLS/wolly-tools" ]; then
	RAMBO_PLACE=guest
	H=$WOLLY_TOOLS/hilde
	HILDE=$H/hilde
	HIAWATHA=$WOLLY_TOOLS/hiawatha/build/hiawatha
else
	echo "ABORT: neither in the image wolly-dev nor in a guest with WOLLY_TOOLS -- run through scripts/run.sh" >&2
	exit 9
fi
[ -r scripts/image/env.sh ] && [ -d src/Rambo ] || { echo "ABORT: run from the root of the rambo tree" >&2; exit 9; }
RAMBO=$PWD
WOLLY=$(cd ../wolly && pwd)
RUN=$RAMBO/_run
export TMPDIR=$RUN/tmp
for t in "$HILDE" "$HIAWATHA"; do
	[ -x "$t" ] || { echo "ABORT: $t missing -- nothing ran" >&2; exit 9; }
done
mkdir -p "$TMPDIR" || exit 9
# The standard library: the tool's, with the files of a Hilde tree sent
# along (scripts/hilde-overlay.txt) in place of its own.
STD=$H/standard/src
if [ -d ../hilde/standard/src ]; then
	STD=$RUN/standard
	rm -rf "$STD" && mkdir -p "$STD" && cp -R "$H/standard/src/." "$STD/" || exit 9
	for f in ../hilde/standard/src/*; do
		cp -R "$f" "$STD/" || exit 9
		echo "overlay: $(basename "$f")"
	done
fi
MODS="$H/bindings/generated:$STD:$WOLLY/src:$RAMBO/src"
