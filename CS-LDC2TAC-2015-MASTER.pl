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

my $version = "2.0";    # Updated to work with 2016

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

die "Usage: perl $0 <LDC_manual_run_file> <queries.index>" unless @ARGV == 2;

my $ldc_manual_run = $ARGV[0];
my $index_file = $ARGV[1];

my $infile;

my %index;
open($infile, "<:utf8", $index_file) or die "Could not open $index_file: $!";
while(<$infile>) {
  chomp;
  my ($sf_queryid, $ldc_queryid) = split(/\s+/, $_);
  $index{$ldc_queryid}{$sf_queryid} = 1;
}
close($infile);


open($infile, "<:utf8", $ldc_manual_run) or die "Could not open $ldc_manual_run: $!";

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
  my $ldc_queryid = $1;
  foreach my $sf_queryid(keys %{$index{$ldc_queryid}}) {
    my $hop = $2;
    if ($hop eq '00') {
      my $uuid = &main::generate_uuid_from_values($sf_queryid, $value_string, $value_provenance->tostring(), 12);
      $level01_query_id = "${sf_queryid}_$uuid";
      print "$sf_queryid\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n";
    }
    elsif ($hop eq '01') {
      print "$level01_query_id\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n";
    }
    else {
      die "Unknown hop: $hop";
    }
  }
}

close $infile;

1;
