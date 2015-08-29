#!/usr/bin/perl

use warnings;
use strict;

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program converts Cold Start ground truth files from LDC to the
# standard file format for Cold Start results.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.0";

### DO NOT INCLUDE
##################################################################################### 
# Library inclusions
##################################################################################### 
### DO INCLUDE
### DO INCLUDE Utils                  ColdStartLib.pm
### DO INCLUDE Patterns               ColdStartLib.pm
### DO INCLUDE Logger                 ColdStartLib.pm
### DO INCLUDE Provenance             ColdStartLib.pm

binmode(STDOUT, ':utf8');

my $level01_query_id;
my $logger = Logger->new();

die "Usage: perl $0 <LDC_manual_run_file>" unless @ARGV == 1;
open(my $infile, "<:utf8", $ARGV[0]) or die "Could not open $ARGV[0]: $!";

while (<$infile>) {
  chomp;
  my ($query_and_hop, $slotname, $runid, $full_provenance_string, $value_string, $type, $value_provenance_string, $confidence, $too_many) = split(/\t/);
  die "Too few entries on line" unless defined $confidence;
  die "Too many entries on line" if defined $too_many;
  # Normalize provenance
  my $value_provenance = Provenance->new($logger,
					 {FILENAME => "STDIN", LINENUM => $.},
					 'PROVENANCETRIPLELIST',
					 $value_provenance_string);
  $value_provenance_string = $value_provenance->tostring();
  my $full_provenance = Provenance->new($logger,
					{FILENAME => 'STDIN', LINENUM => $.},
					'PROVENANCETRIPLELIST',
					$full_provenance_string);
  $full_provenance_string = $full_provenance->tostring();
  # Replace query and hop with appropriate query ID
  $query_and_hop =~ /^(.*)_(\d\d)$/ or die "Bad query_and_hop: $query_and_hop";
  my $query_id = $1;
  my $hop = $2;
  if ($hop eq '00') {
    my $uuid = &main::uuid_generate($query_id, $value_string, $value_provenance->tostring());
    $level01_query_id = "${query_id}_$uuid";
    print "$query_id\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n";
  }
  elsif ($hop eq '01') {
    print "$level01_query_id\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n";
  }
  else {
    die "Unknown hop: $hop";
  }
}

close $infile;

1;
