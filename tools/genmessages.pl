#!/usr/bin/perl
# Writes src/Rambo/Messages.hih and src/Rambo/Messages.hiq from the page
# texts of the earlier Go provider (internal/web/messages_en.go and messages_de.go), as a
# catalog of Standard.I18n, so that both speak with the same words.  Each
# key becomes a case of the union Key: title.logged_out is TitleLoggedOut.
# The %s of a text becomes {arg}; a letter outside ASCII is written as
# \u{X}.  The texts rambo has beyond those of that provider are in texts/, in the same
# form, and are read with them.  Stops when a key is missing in one
# language, is there twice, two keys make one name, or a text holds a brace.
#
#     perl tools/genmessages.pl <tree of the Go provider>/internal/web src/Rambo texts
use strict;
use warnings;

my ($from, $to, $own) = @ARGV;
die "usage: genmessages.pl GO-PROVIDER-WEB-DIR OUT-DIR OWN-DIR\n" unless defined $own;

sub texts {
	my ($path) = @_;
	open my $fh, '<:encoding(UTF-8)', $path or die "$path: $!";
	my %t;
	while (my $line = <$fh>) {
		next unless $line =~ /^\s*"([a-z0-9_.]+)":\s*"((?:[^"\\]|\\.)*)",/;
		my ($key, $text) = ($1, $2);
		die "$path: $key twice\n" if exists $t{$key};
		die "$path: $key holds a brace\n" if $text =~ /[{}]/;
		$t{$key} = $text;
	}
	close $fh;
	return \%t;
}

# The texts of the earlier Go provider with rambo's own added; a key in both stops.
sub merged {
	my ($go, $mine) = @_;
	for my $k (keys %$mine) {
		die "$k is the Go provider's and rambo's\n" if exists $go->{$k};
		$go->{$k} = $mine->{$k};
	}
	return $go;
}

sub name {
	my ($key) = @_;
	return join '', map { ucfirst } split /[._]/, $key;
}

# A Go string body as a Hilde string body, %s as {arg}.
sub hilde {
	my ($go) = @_;
	my $out = '';
	while (length $go) {
		if ($go =~ s/^%s//) {
			$out .= '{arg}';
		} elsif ($go =~ s/^\\u([0-9a-fA-F]{4})//) {
			$out .= sprintf('\\u{%x}', hex $1);
		} elsif ($go =~ s/^\\(["\\nrt])//) {
			$out .= "\\$1";
		} elsif ($go =~ s/^\\(.)//) {
			die "an escape \\$1 the generator does not know\n";
		} else {
			$go =~ s/^(.)//s;
			my $c = $1;
			$out .= ord($c) < 128 ? $c : sprintf('\\u{%x}', ord $c);
		}
	}
	return $out;
}

my $en = merged(texts("$from/messages_en.go"), texts("$own/messages_en.txt"));
my $de = merged(texts("$from/messages_de.go"), texts("$own/messages_de.txt"));
for my $k (keys %$en) { die "de lacks $k\n" unless exists $de->{$k} }
for my $k (keys %$de) { die "en lacks $k\n" unless exists $en->{$k} }
my @keys = sort keys %$en;
my %seen;
for my $k (@keys) {
	my $n = name($k);
	die "$k and $seen{$n} are both $n\n" if exists $seen{$n};
	$seen{$n} = $k;
}

my $head = "--\n-- Part of rambo.\n--\n-- SPDX-FileCopyrightText: 2026 Heiko Zimmermann\n"
	. "-- SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception\n--\n"
	. "-- Written by tools/genmessages.pl from the page texts of the earlier Go provider and texts/;\n"
	. "-- change the generator or the texts, not this file.\n";

open my $hih, '>:encoding(UTF-8)', "$to/Messages.hih" or die "$to/Messages.hih: $!";
print $hih $head;
print $hih "\"\"\"\nThe texts of the pages in English and German, as a catalog of\n"
	. "Standard.I18n.  A text with {arg} has a word put in its place.\n\"\"\"\n";
print $hih "import Standard.I18n (\n    Catalog\n);\n\nmodule Rambo.Messages is\n";
print $hih "    \"\"\"\n    The texts of the pages, one case each.\n    \"\"\"\n    union Key: Free is\n";
print $hih "        case " . name($_) . ";\n" for @keys;
print $hih "    end;\n\n";
print $hih "    \"\"\"\n    The catalog: English first, then German.\n"
	. "    No ensures: a record of function pointers has no equality to state it with.\n"
	. "    \"\"\"\n    function messages(): Catalog[Key];\nend module.\n";
close $hih;

open my $hiq, '>:encoding(UTF-8)', "$to/Messages.hiq" or die "$to/Messages.hiq: $!";
print $hiq $head;
print $hiq "import Standard.I18n (\n    Message,\n    Text,\n    Language,\n    Catalog,\n"
	. "    englishPlural,\n    germanPlural\n);\n\nmodule body Rambo.Messages is\n";
for my $l (['english', $en], ['german', $de]) {
	my ($fn, $t) = @$l;
	print $hiq "    function $fn(key: Key): Message is\n        case key of\n";
	for my $k (@keys) {
		print $hiq "            when " . name($k) . " do\n";
		print $hiq "                return Text(text => \"" . hilde($t->{$k}) . "\");\n";
	}
	print $hiq "        end case;\n    end;\n\n";
}
print $hiq "    function others(i: Index): Option[Language[Key]] is\n        if i = 0 then\n"
	. "            return Some(value => Language(code => \"de\", texts => german, plural => germanPlural));\n"
	. "        end if;\n        return None();\n    end;\n\n";
print $hiq "    function messages(): Catalog[Key] is\n"
	. "        return Catalog(default => Language(code => \"en\", texts => english, plural => englishPlural),\n"
	. "            others => others);\n    end;\nend module body.\n";
close $hiq;
printf "keys=%d\n", scalar @keys;
