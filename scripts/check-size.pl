#!/usr/bin/env perl
# The size of the sources: no .hiq or .hih file under src/ or cmd/ has more
# than 2000 lines, so that a module stays one thing a reader can hold.  Exit
# 0 only when every file holds and at least one was read.
#
#     perl scripts/check-size.pl
use strict;
use warnings;

my $most = 2000;
my ($read, $bad) = (0, 0);
my @dirs = grep { -d } qw(src cmd);
my @todo = @dirs;
while (my $d = shift @todo) {
    opendir my $dh, $d or die "ABORT: cannot read $d\n";
    for my $e (sort grep { !/^\./ } readdir $dh) {
        my $p = "$d/$e";
        if (-d $p) { push @todo, $p; next }
        next unless $p =~ /\.hi[qh]$/;
        open my $in, '<', $p or die "ABORT: cannot read $p\n";
        my $n = 0;
        $n++ while <$in>;
        close $in;
        $read++;
        if ($n > $most) {
            print "$p: $n lines, at most $most\n";
            $bad++;
        }
    }
    closedir $dh;
}
print "check-size: $read files read, $bad too long\n";
exit 9 if $read == 0;
exit($bad == 0 ? 0 : 1);
