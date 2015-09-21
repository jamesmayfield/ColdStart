#!/usr/bin/perl

use warnings;
use strict;


binmode(STDOUT, ":utf8");

### DO NOT INCLUDE

use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program transforms CSLDC assessment file to CSSF assessment file. 
#
# Author: Shahzad Rajput
# Please send questions or comments to shahzad "dot" rajput "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.2";

# Filehandles for program and error output
my $program_output = *STDOUT{IO};
my $error_output = *STDERR{IO};


### DO NOT INCLUDE
##################################################################################### 
# Library inclusions
##################################################################################### 
### DO INCLUDE
### DO INCLUDE Utils                  ColdStartLib.pm
### DO INCLUDE Patterns               ColdStartLib.pm
### DO INCLUDE Logger                 ColdStartLib.pm
### DO INCLUDE Provenance             ColdStartLib.pm
### DO INCLUDE Predicates             ColdStartLib.pm
### DO INCLUDE Query                  ColdStartLib.pm
### DO INCLUDE QuerySet               ColdStartLib.pm
### DO INCLUDE EvaluationQueryOutput  ColdStartLib.pm
### DO INCLUDE Switches               ColdStartLib.pm

# Load file which contains mapping from output query name to original LDC query name
sub load_index_file {
  my ($logger, $index_filename) = @_;
  my %index;
  open(my $infile, "<:utf8", $index_filename) or $logger->NIST_die("Could not open $index_filename: $!");
  while(<$infile>) {
    chomp;
    my ($query_id, $ldc_query_id) = split(/\t/);
    push( @{$index{$ldc_query_id}}, $query_id );
  }
  close $infile;
  %index;
}

# Expand this pool to transform the LDC QUERY IDs back to CSSF QUERY IDs
sub expand_pool {
  my ($logger, $pool, %index) = @_;
  my $schema_name = '2014assessments';
  my $schema = $EvaluationQueryOutput::schemas{$schema_name};
  $logger->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my %output_strings;
  my $hop = 0;
  my $i = 1;
  if (defined $pool->{ENTRIES_BY_TYPE}) {
    foreach my $entry (@{$pool->{ENTRIES_BY_TYPE}{$schema->{TYPE}}}) {
      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      my $ldc_query_id = $entry->{QUERY_ID};
      $ldc_query_id =~ /(\d+)$/;
      my $ldc_query_num = $1;
      foreach my $cssf_queryid( @{$index{$ldc_query_id}} ) {
      	my $new_entry_string = $entry_string;
      	$new_entry_string =~ s/$ldc_query_id/$cssf_queryid/g;
#      	my $assessment_id = (($hop+1)*1000 + $ldc_query_num)*10000 + $i;
#     	$new_entry_string = "$assessment_id\t$new_entry_string";
        $output_strings{ $new_entry_string }++;   
        $i++;
      }
    }
  }
  join("\n", sort keys %output_strings), "\n";
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Transform CSLDC assessment file to CSSF assessment file, checking for common errors.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify an output file with warnings repaired. Omit for validation only");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addParam("ldc_queryfile", "required", "File containing LDC queries used to generate the input files");
$switches->addParam("cssf_queryfile", "required", "File containing CSSF queries used to generate the input files");
$switches->addParam("csldc_assessment_file", "required", "Tab-separated file containing assessments from LDC");
$switches->addVarSwitch("cssf_hop0_assessment_file", "The hop0 cssf assessments should be written. Required for transforming the hop-1 (round#2) assessments.");
$switches->addVarSwitch("hop1_query_file", "Specify the file to which hop1 queries should be written. This file is required by LDC and becomes input to their assessment system for assessing hop1 pool.");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");

$switches->process(@ARGV);

my $ldc_queryfile = $switches->get("ldc_queryfile");
my $cssf_queryfile = $switches->get("cssf_queryfile");
my $index_filename = $switches->get("index_file");
my $csldc_assessment_file = $switches->get("csldc_assessment_file");
my $hop1_query_file = $switches->get("hop1_query_file");
my $hop = 0;

my $cssf_hop0_assessment_file = $switches->get("cssf_hop0_assessment_file");
$hop = 1 if (defined $cssf_hop0_assessment_file);

my $logger = Logger->new();
# It is not an error for pools to have multiple fills for a single-valued slot
$logger->delete_error('MULTIPLE_FILLS_SLOT');
$logger->delete_error('DUPLICATE_QUERY');
$logger->delete_error('MULTIPLE_RUNIDS');

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
} elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
} else {
  open($program_output, ">:utf8", $output_filename) or $logger->NIST_die("Could not open $output_filename: $!");
}

my $error_filename = $switches->get("error_file");
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();

my %index = &load_index_file($logger, $index_filename);

if ($hop == 0) {
  my $ldc_queries = QuerySet->new($logger, $ldc_queryfile);
  my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $ldc_queries, $csldc_assessment_file);
  print $program_output &expand_pool($logger, $pool, %index);
 
  # Generate LDC Queries for Hop-1 (Round#2)
  my %hop1_queries;
  foreach my $ldc_queryid( keys %{$pool->{ENTRIES_BY_EC}}) {
  	foreach my $ldc_ec( keys %{$pool->{ENTRIES_BY_EC}{$ldc_queryid}}) {
  	  my @entries = @{$pool->{ENTRIES_BY_EC}{$ldc_queryid}{$ldc_ec}};
  	  my $query;
  	  if( @entries ){
  	  	my $entry = shift @entries;
  	  	$query = $entry->{TARGET_QUERY};
  	  	next if(not defined $query);
### DO NOT INCLUDE
#  	  	foreach my $entry( @entries ) {
#  	  	  foreach my $entrypoint( @{$entry->{TARGET_QUERY}->{ENTRYPOINTS}} ) {
#  	  		push (@{$query->{ENTRYPOINTS}}, $entrypoint);	
#  	  	  }
#  	  	}
### DO INCLUDE
		my @entrypoints = @{$query->{ENTRYPOINTS}};
		foreach my $entry( @entries ){
			foreach my $entrypoint( @{$entry->{TARGET_QUERY}->{ENTRYPOINTS}} ) {
				my @exists = grep {$_->{UUID} eq $entrypoint->{UUID}} @entrypoints;
				push (@entrypoints, $entrypoint) if(scalar @exists == 0);
			}
		}
		
		@{$query->{ENTRYPOINTS}} = @entrypoints;
			
  	  	my $query_id = "$ldc_queryid:$ldc_ec";
  	  	$query->{QUERY_ID} = $query_id;
  	  	my $slot1 = $query->{SLOT};
  	  	$slot1 =~ /^(.*?):.*?$/;
  	  	my $enttype = uc $1;
  	  	
  	  	$query->{ENTTYPE} = $enttype;
  	  	$hop1_queries{ $query_id } = $query;
  	  } 
  	}
  }
  my $hop1_query_output;
  open($hop1_query_output, ">:utf8", $hop1_query_file) or $logger->NIST_die("Could not open $hop1_query_file: $!");
  print $hop1_query_output "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<query_set>\n";
  foreach my $query_id( sort keys %hop1_queries ){
  	#print STDERR "--print $query_id\n";
  	my $query = $hop1_queries{ $query_id };
  	print $hop1_query_output $query->tostring("  ");
  }  
  print $hop1_query_output "</query_set>\n";
  close($hop1_query_output);
}
elsif ($hop == 1) {
  my $cssf_queries = QuerySet->new($logger, $cssf_queryfile);
  my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $cssf_queries, $cssf_hop0_assessment_file);
  
  # Generate query mapping
  my %mapping;
  foreach my $query_id( keys %{ $pool->{ENTRIES_BY_EC} } ) {
    foreach my $ec( keys %{ $pool->{ENTRIES_BY_EC}{$query_id} }) {
  	  foreach my $entry( @{$pool->{ENTRIES_BY_EC}{$query_id}{$ec}} ) {
  	    my $target_query_id = $entry->{TARGET_QUERY_ID};
  	    #push( @{$mapping{$ec}}, $target_query_id );
  	    $mapping{$ec}{$target_query_id}++;
  	  }
    }
  }
  
  # Transform the assessments
  my $i = 1;
  open(my $infile, "<:utf8", $csldc_assessment_file) or $logger->NIST_die("Could not open $csldc_assessment_file: $!");
  while(my $line = <$infile>) {
    chomp $line;
    my @elements = split(/\t/, $line);
    my $ldc_ec_slot = $elements[1];
    $ldc_ec_slot =~ /^(.*?):(.*?):(.*?)$/;
    my ($ldc_query_id, $ec_num, $slot) = ($1, $2, $3);
    $ldc_query_id =~ /(\d+)$/;
    my $ldc_query_num = $1;
   # foreach my $cssf_query_id_base( @{$index{$ldc_query_id}} ) {
   #   my $cssf_ec = "$cssf_query_id_base:$ec_num";
      foreach my $cssf_query_id( keys %{$mapping{ $ec_num }} ) {
      	my $new_query_slot = "$cssf_query_id:$slot";
      	my $new_entry_string = $line;
      	$new_entry_string =~ s/$ldc_ec_slot/$new_query_slot/g;
      	#$new_entry_string =~ s/$ldc_query_id/$cssf_query_id_base/g;
      	#$new_entry_string =~ s/$ldc_query_id/$cssf_query_id/g;
      	#my $assessment_id = (($hop+1)*1000 + $ldc_query_num)*10000 + $i;
      	#$new_entry_string = "$assessment_id\t$new_entry_string";
      	print $program_output "$new_entry_string\n";
      	$i++;
      }
    #}
  }
  close $infile;
  
}

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}

print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Hop#1 queries file now just outputs one entry point rather than the long process of collecting all the entry points in the next round
# 1.2 - Hop#1 queries file includes multiple distint entry points; Inexact mentions included
 
1;