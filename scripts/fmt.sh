#!/usr/bin/env bash
# Runs on the workstation: brings the files given into Hilde's one form with hilde
# fmt in the container image (scripts/image/fmt.sh) and writes the changed ones back.
# A path of the Wolly tree is given as ../wolly/src/...; it is written into
# WOLLY_TREE (default ../wolly beside this tree).
#
#     bash scripts/fmt.sh src/Rambo/Fixture.hiq ../wolly/src/Wolly/OpKey.hiq
[ "${BASH_VERSINFO[0]:-0}" -ge 3 ] || { echo "ABORT: bash too old"; exit 9; }
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
wolly=${WOLLY_TREE:-$(dirname "$here")/wolly}
out=$(mktemp "${TMPDIR:-/tmp}/rambo-fmt.XXXXXX") || exit 9
bash "$here/scripts/run.sh" fmt.sh "$@" > "$out"
rc=$?
perl -e '
    my ($file, $here, $wolly) = @ARGV;
    open my $in, "<", $file or die "ABORT: $file\n";
    my ($path, $text, $n) = (undef, "", 0);
    while (<$in>) {
        if (/^=== file (\S+)$/) { $path = $1; $text = ""; next }
        if (/^=== end$/ && defined $path) {
            require MIME::Base64;
            my $target = $path =~ s{^\.\./wolly/}{$wolly/}r;
            $target = "$here/$target" unless $target =~ m{^/};
            open my $o, ">", $target or die "ABORT: cannot write $target\n";
            print $o MIME::Base64::decode_base64($text);
            close $o;
            print "written $target\n";
            $n++;
            undef $path;
            next;
        }
        $text .= $_ if defined $path;
    }
    print "fmt: $n files written back\n";
' "$out" "$here" "$wolly"
wrote=$?
rm -f "$out"
[ $wrote -eq 0 ] || exit 9
exit $rc
