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

my %level01_query_ids;
my $logger = Logger->new();

# Load index-file
my %index;
my %inverted_index; 
my $index_file = "/Users/rajput/cold-start-collaborative/demo_v3.0/queries.index";
my $infile;
open($infile, "<:utf8", $index_file);
while (<$infile>) {
  chomp;
  my ($cssf_query_id, $csldc_query_id) = split(/\t/);
  push(@{$index{$csldc_query_id}}, $cssf_query_id);
  $inverted_index{$cssf_query_id} = $csldc_query_id;
}
close($infile);

#die "Usage: perl $0 <LDC_manual_run_file>" unless @ARGV == 1;
my $ldc_manual_run_file = "/Users/rajput/cold-start-collaborative/data/LDC/tac_kbp_2015_english_cold_start_evaluation_manual_run.tab";

open($infile, "<:utf8", $ldc_manual_run_file);

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
  my $csldc_query_id = $1;
  my $hop = $2;
    
  if ($hop eq '00') {
  	%level01_query_ids = ();
  	foreach my $cssf_query_id( @{$index{$csldc_query_id}} ) {
  		my $uuid = &main::uuid_generate($cssf_query_id, $value_string, $value_provenance->tostring());
  		my $level01_query_id = "${cssf_query_id}_$uuid";
  		$level01_query_ids{$level01_query_id}++;
  		print "$cssf_query_id\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n";
  	}
  }
  elsif ($hop eq '01') {
  	foreach my $level01_query_id( keys %level01_query_ids ){
  		print "$level01_query_id\t$slotname\t$runid\t$full_provenance_string\t$value_string\t$type\t$value_provenance_string\t$confidence\n"; 
  	}
  }
  else {
    die "Unknown hop: $hop";
  }
}

close $infile;

1;
