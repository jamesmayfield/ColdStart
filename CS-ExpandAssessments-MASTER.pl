#!/usr/bin/perl

use warnings;
use strict;


binmode(STDOUT, ":utf8");

### DO NOT INCLUDE

use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program pools KB variant submissions, SF variant submissions,
# and ground truth from LDC. It anonymizes the run ID, maps all
# confidence values to 1.0, and sorts the results.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.0";

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
    foreach my $entry (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID} ||
			     lc $a->{VALUE} cmp lc $b->{VALUE} ||
			     $a->{VALUE_PROVENANCE}->tostring() cmp $b->{VALUE_PROVENANCE}->tostring()}
		       @{$pool->{ENTRIES_BY_TYPE}{$schema->{TYPE}}}) {
      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      my $ldc_query_id = $entry->{QUERY_ID};
      $ldc_query_id =~ /(\d+)$/;
      my $ldc_query_num = $1;
      foreach my $cssf_queryid( @{$index{$ldc_query_id}} ) {
      	my $new_entry_string = $entry_string;
      	$new_entry_string =~ s/$ldc_query_id/$cssf_queryid/g;
      	my $assessment_id = (($hop+1)*1000 + $ldc_query_num)*10000 + $i;
     	$new_entry_string = "$assessment_id\t$new_entry_string";
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
my $switches = SwitchProcessor->new($0, "Validate a TAC Cold Start Slot Filling variant output file, checking for common errors.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify an output file with warnings repaired. Omit for validation only");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addParam("ldc_queryfile", "required", "File containing LDC queries used to generate the input files");
$switches->addParam("cssf_queryfile", "required", "File containing CSSF queries used to generate the input files");
$switches->addParam("assessment_file", "required", "Tab-separated file (to be expanded) containing assessments from LDC (one that contains LDC QUERY IDs)");
$switches->addVarSwitch("assessment_file_ex", "Tab-separated file containing \"expanded\" previous hop (hop0, in the current scheme) assessments from LDC (one that contains LDC QUERY IDs)");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");

$switches->process(@ARGV);

my $ldc_queryfile = $switches->get("ldc_queryfile");
my $cssf_queryfile = $switches->get("cssf_queryfile");
my $index_filename = $switches->get("index_file");
my $assessment_file = $switches->get("assessment_file");
my $hop = 0;

my $assessment_file_ex = $switches->get("assessment_file_ex");
$hop = 1 if (defined $assessment_file_ex);


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
  my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $ldc_queries, $assessment_file);
  print $program_output &expand_pool($logger, $pool, %index);
}
elsif ($hop == 1) {
  my $cssf_queries = QuerySet->new($logger, $cssf_queryfile);
  my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $cssf_queries, $assessment_file_ex);
  
  # Generate query mapping
  my %mapping;
  foreach my $query_id( keys %{ $pool->{ENTRIES_BY_EC} } ) {
    foreach my $ec( keys %{ $pool->{ENTRIES_BY_EC}{$query_id} }) {
  	  foreach my $entry( @{$pool->{ENTRIES_BY_EC}{$query_id}{$ec}} ) {
  	    my $target_query_id = $entry->{TARGET_QUERY_ID};
  	    push( @{$mapping{$ec}}, $target_query_id );
  	  }
    }
  }
  
  # Transform the assessments
  my $i = 1;
  open(my $infile, "<:utf8", $assessment_file) or $logger->NIST_die("Could not open $assessment_file: $!");
  while(my $line = <$infile>) {
    chomp $line;
    my @elements = split(/\t/, $line);
    my $ldc_ec_slot = $elements[1];
    $ldc_ec_slot =~ /^(.*?):(.*?):(.*?)$/;
    my ($ldc_query_id, $ec_num, $slot) = ($1, $2, $3);
    $ldc_query_id =~ /(\d+)$/;
    my $ldc_query_num = $1;
    foreach my $cssf_query_id_base( @{$index{$ldc_query_id}} ) {
      my $cssf_ec = "$cssf_query_id_base:$ec_num";
      foreach my $cssf_query_id( @{$mapping{ $cssf_ec }} ) {
      	my $new_query_slot = "$cssf_query_id:$slot";
      	my $new_line = $line;
      	$new_line =~ s/$ldc_ec_slot/$new_query_slot/g;
      	$new_line =~ s/$ldc_query_id/$cssf_query_id_base/g;
      	my $assessment_id = (($hop+1)*1000 + $ldc_query_num)*10000 + $i;
      	print $program_output "$assessment_id\t$new_line\n";
      	$i++;
      }
    }
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


1;
