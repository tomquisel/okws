#!/usr/bin/perl

#
# A script to collect .x files in a given directory, and to make
# one .C/.h pair of it, so that a program can access the whole
# collection of .x files without hardcoding.
#

use strict;
use Getopt::Std;
use IO::File;

use File::Basename;

my %opts = ();
my $mode = 0;
my $HFILE = 1;
my $CFILE = 2;

sub usage {
    print STDERR <<EOF;
usage: $0 [-c|-h] [-o <outfile>]  [-n <objname>] *.x

Typical Invocations:

    $0 -o my_prot_collection.h prot1.x prot2.x prot3.x
    $0 -o my_prot_collection.C prot1.x prot2.x prot3.x

Which will give you a symbol 'my_con_collection_rpc_file_list' that
you can then use in your XML service.

Note that a -c or -h can be provided, or the mode is alternatively
inferred from the suffix of the output file, acceptable choices for
which are .h, .hh. .hxx, .C, .cc and .cxx.

EOF
    exit (-1);
}

sub generate_cfile {
    my ($fh, $fn, $fnbase, $symname, $xfiles) = @_;

    if ($fnbase) {
	my $hfile = $fnbase . ".h";
	print $fh <<EOF;

#include "$hfile"
EOF
    }
    print $fh "\n";
    foreach my $x (@$xfiles) {
	print $fh qq{\#include "$x.h"\n};
    }
    print $fh "\n";

    print $fh "xml_rpc_file *" . $symname . "[] = {\n";
    foreach my $x (@$xfiles) {
	my $sym = $x . "_rpc_file";
	print $fh "  &" . $sym  . ",\n";
    }
    print $fh "  NULL\n};\n\n";
}

sub generate_hfile {
    my ($fh, $fn, $symname, $xfiles) = @_;

    if ($fn eq "-") {
	$fn = $symname ."_spontaneous_stdout";
    }

    my $protector = "__" . uc ($fn) . "__" ;
    $protector =~ s/\./_/g ;
    

    my $csym = '*' . $symname . "[]";
    print $fh <<EOF;
/*
 * $fn - autogenerated by $0 
 */
#ifndef $protector
#define $protector

#include "okxmlxlate.h"

extern xml_rpc_file $csym;

#endif /* $protector */

EOF

}

getopts ("?hco:n:", \%opts);
my $outfile = "-";
$outfile = $opts{o} if defined $opts{o};
my $name = "";
$name = $opts{n} if defined $opts{n};

if (defined $opts{'?'}) {
    usage ();
}

my %suffixtab = ( ".h" => $HFILE,
		  ".hh" => $HFILE,
		  ".hxx" => $HFILE,
		  ".C" => $CFILE,
		  ".cxx" => $CFILE,
		  ".cc" => $CFILE );

my @suffixes = keys %suffixtab;
my $suffixre = '(' . join ("|", @suffixes) . ")";
my $suffixmode = 0;

my ($outbase, $outpath, $outsuffix);
unless ($outfile eq "-") {
    ($outbase, $outpath, $outsuffix) = fileparse ($outfile, qr{$suffixre});

    if (length ($outsuffix) == 0) {
	warn ("Suffix on output must be either " .
	      ".h, .C, .hh, .cc, .hxx, or .cxx\n");
	exit (1);
    }
    
    $suffixmode = $suffixtab{$outsuffix};
}

if (length ($name) == 0) {
    if ($outfile eq "-") {
	warn ("Need to supply a name for the array in the output file\n");
	usage ();
    } else {
	$name = $outbase . "_rpc_file_list";
    }
}

my $outfh;
if ($outfile eq "-") {
    $outfh = \*STDOUT;
} else {
    $outfh = new IO::File (">$outfile");
    if (!$outfh) {
	warn ("Cannot open file for writing: $outfile\n");
	exit (1);
    }
}

if (defined $opts{h}) {
    $mode = $HFILE;
} elsif (defined $opts{c}) {
    $mode = $CFILE;
} elsif ($suffixmode) {
    $mode = $suffixmode;
} else {
    usage ();
}

if ($suffixmode && $suffixmode != $mode) {
    warn ("Got header/C-file clash; please check arguments\n");
    exit (1);
}

if ($#ARGV < 0) {
    warn ("No input .x files provided\n");
    exit (1);
}

my $bad = 0;
my @xfiles = ();
foreach my $f (@ARGV) {
    my ($name, $path, $suffix) = fileparse ($f, qr{\.x} );
    unless ($suffix and $suffix eq ".x") {
	warn ("Can only accept files with .x suffix; got $f instead\n");
	$bad = 1;
    }
    push (@xfiles, $name);
}

exit (1) if $bad;


if ($mode == $HFILE) {
    generate_hfile ($outfh, $outfile, $name, \@xfiles);
} elsif ($mode == $CFILE) {
    generate_cfile ($outfh, $outfile, $outbase, $name, \@xfiles);
} else {
    warn ("Unexpected error!\n");
    exit (1);
}

$outfh->close ();



