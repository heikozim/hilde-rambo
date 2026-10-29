#!/usr/bin/env perl
# Every function and method an interface file declares between "module X
# is" and "end module." states a contract: a requires or ensures clause
# before the ";" that ends its declaration, or a line beginning "No
# contract:" in its docstring.  Prints file:line name for each miss and the
# counts; exit 0 only when no declaration misses and at least one was read.
# The same rule as check-contracts.py of Hilde, for the trees named.
#
#     perl scripts/check-contracts.pl <dir>...
#     perl scripts/check-contracts.pl --self-test
use strict;
use warnings;

# The declarations of text that miss a contract, as [line, name].
sub misses {
    my ($text) = @_;
    my @l = split /\n/, $text;
    my ($in, $indoc, $doc, $n) = (0, 0, '', 0);
    my @miss;
    for (my $i = 0; $i < @l; $i++) {
        my $line = $l[$i];
        if (!$in) { $in = 1 if $line =~ /^module\s+\S+\s+is\s*$/; next; }
        last if $line =~ /^end module\.\s*$/;
        if ($line =~ /^\s*"""\s*$/) {
            if ($indoc) { $indoc = 0; } else { $indoc = 1; $doc = ''; }
            next;
        }
        if ($indoc) { $doc .= "$line\n"; next; }
        if ($line =~ /^\s+(?:function|method)\s+(\w+)\s*\(/) {
            my ($name, $at, $decl) = ($1, $i + 1, "$line\n");
            while ($decl !~ /;\s*$/ && $i + 1 < @l) { $i++; $decl .= "$l[$i]\n"; }
            $n++;
            push @miss, [$at, $name] unless $decl =~ /\b(?:requires|ensures)\b/ || $doc =~ /^\s*No contract:/m;
            $doc = '';
        } elsif ($line =~ /^\s+(?:record|type|union|constant|typeclass|instance)\b/) {
            $doc = '';
        }
    }
    return ($n, @miss);
}

sub self_test {
    my $good = "module M is\n    \"\"\"\n    A.\n    No contract: it only frees.\n    \"\"\"\n    function a(x: T): Unit;\n"
        . "    function b(): Int64\n        ensures result = 1;\n    generic [R: Region]\n    function c(n: Int64): Unit\n        requires n > 0;\nend module.\n";
    my $bad = "module M is\n    \"\"\"\n    A.  No ensures: a walk.\n    \"\"\"\n    function a(x: T): Unit;\n    function d(): Int64;\nend module.\n";
    my ($gn, @gm) = misses($good);
    my ($bn, @bm) = misses($bad);
    my $ok = $gn == 3 && @gm == 0 && $bn == 2 && @bm == 2 && $bm[0][1] eq 'a' && $bm[1][1] eq 'd';
    print "self-test good=$gn/" . scalar(@gm) . " bad=$bn/" . scalar(@bm) . " " . ($ok ? "ok" : "FAILED") . "\n";
    return $ok ? 0 : 1;
}

exit self_test() if @ARGV == 1 && $ARGV[0] eq '--self-test';
@ARGV or die "ABORT: no tree named -- nothing was checked\n";
my @files;
for my $root (@ARGV) {
    -d $root or die "ABORT: $root is no directory -- nothing was checked\n";
    open my $find, '-|', 'find', $root, '-name', '*.hih', '-type', 'f' or die "ABORT: find did not start\n";
    push @files, map { chomp; $_ } <$find>;
    close $find or die "ABORT: find failed\n";
}
my ($files, $decls, $missed) = (0, 0, 0);
for my $f (sort @files) {
    open my $in, '<', $f or die "ABORT: cannot read $f\n";
    my $text = do { local $/; <$in> };
    close $in;
    my ($n, @miss) = misses($text);
    $files++;
    $decls += $n;
    for my $m (@miss) { print "$f:$m->[0] $m->[1]\n"; $missed++; }
}
print "check-contracts: $files files, $decls declarations, $missed without a contract\n";
exit($files > 0 && $decls > 0 && $missed == 0 ? 0 : 1);
