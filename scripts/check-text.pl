#!/usr/bin/env perl
# The plain text of the tree: every file git knows or would add (ignored
# files left out) that is text is plain ASCII, ends its lines with LF, has
# no blank at the end of a line and ends with LF.  A Markdown file whose
# name ends in .de.md is German and may hold UTF-8.  Exit 0 only when every
# file holds and at least one file was read.
#
#     perl scripts/check-text.pl
use strict;
use warnings;

my $root = shift // '.';
chdir $root or die "ABORT: cannot enter $root\n";
open my $git, '-|', 'git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'
    or die "ABORT: git ls-files did not start\n";
my @files = do { local $/ = "\0"; map { chomp; $_ } <$git> };
close $git or die "ABORT: git ls-files failed\n";

my %binary = map { $_ => 1 } qw(png ico db gif jpg jpeg webp zip);
my ($read, $bad) = (0, 0);
for my $f (@files) {
    next unless -f $f;
    my ($ext) = $f =~ /\.([^.\/]+)$/;
    next if defined $ext && $binary{lc $ext};
    next if $f =~ m{^testdata/gorambo/\.};
    open my $in, '<:raw', $f or die "ABORT: cannot read $f\n";
    my $text = do { local $/; <$in> };
    close $in;
    $read++;
    next if $text eq '';
    my $german = $f =~ /\.de\.md$/;
    my @faults;
    push @faults, 'byte outside ASCII' if !$german && $text =~ /[^\x00-\x7f]/;
    push @faults, 'CR' if $text =~ /\r/;
    push @faults, 'blank at the end of a line' if $text =~ /[ \t]\n/;
    push @faults, 'no LF at the end' if $text !~ /\n\z/;
    if (@faults) {
        print "$f: ", join(', ', @faults), "\n";
        $bad++;
    }
}
print "check-text: $read files read, $bad with faults\n";
exit 9 if $read == 0;
exit($bad == 0 ? 0 : 1);
