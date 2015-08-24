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
sub add_ldc_query_ids {
  my ($logger, $queries, $index_filename) = @_;
  open(my $infile, "<:utf8", $index_filename) or $logger->NIST_die("Could not open $index_filename: $!");
  while(<$infile>) {
    chomp;
    my ($query_id, $ldc_query_id) = split(/\t/);
	$queries->get($query_id)->put("LDC_QUERY_ID", $ldc_query_id);
  }
  close $infile;
  $queries;
}

# Get base entry
sub get_base_entry {
	my ($logger, $entry, $pool) = @_;
	
	my $query_id = $entry->{QUERY_ID};
	my $query_id_base = $entry->{QUERY_ID_BASE};
	my @base_entries = grep {$_->{TARGET_QUERY_ID} eq $query_id} @{ $pool->{ENTRIES_BY_QUERY_ID_BASE}{ASSESSMENT}{$query_id_base} };
	$logger->NIST_die("Multiple matching base queries") if @base_entries > 1;
	$logger->NIST_die("No matching base query") if @base_entries == 0;
	$base_entries[0];
}

# Convert this EvaluationQueryOutput back to its proper printed representation
sub pool_to_string {
  my ($logger, $pool, $hop) = @_;
  my $schema_name = '2015Pool';
  my $schema = $EvaluationQueryOutput::schemas{$schema_name};
  $logger->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my %output_strings;
  if (defined $pool->{ENTRIES_BY_TYPE}) {
    foreach my $entry (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID} ||
			     lc $a->{VALUE} cmp lc $b->{VALUE} ||
			     $a->{VALUE_PROVENANCE}->tostring() cmp $b->{VALUE_PROVENANCE}->tostring()}
		       @{$pool->{ENTRIES_BY_TYPE}{$schema->{TYPE}}}) {
      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      if ($entry->{QUERY}->{LEVEL} == $hop) {
      	if($hop==0) {
      	  $output_strings{ $entry_string }++;
      	}
      	else{
      	  my $base_entry = &get_base_entry($logger, $entry, $pool);
      	  my $base_entry_ec = $base_entry->{VALUE_EC};
      	  my $base_entry_query_id = $base_entry->{QUERY_ID};
      	  my $base_entry_ldc_query_id = $base_entry->{QUERY}->{LDC_QUERY_ID};
      	  my $ldc_ec = $base_entry_ec;
      	  $ldc_ec =~ s/$base_entry_query_id/$base_entry_ldc_query_id/;
      	  $entry_string =~ s/$base_entry_ldc_query_id/$ldc_ec/;
          $output_strings{ $entry_string }++ if($base_entry->{JUDGMENT} eq "CORRECT");
      	}
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
$switches->addVarSwitch('runid', "Specify the Run ID for the pooled run");
$switches->put('runid', 'Pool');
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addVarSwitch('hop0_assessment_file', "Tab-separated file containing \"expanded\" hop0 assessments");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the input files");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addParam("dir", "required", "Directory containing files to pool.");

$switches->process(@ARGV);

my $hop = 0;
my $queryfile = $switches->get("queryfile");
my $index_filename = $switches->get("index_file");

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

# Load mapping from docid to document length
my $docids_file = $switches->get("docs");
my $docids;
if (defined $docids_file) {
  open(my $infile, "<:utf8", $docids_file) or $logger->NIST_die("Could not open $docids_file: $!");
  while(<$infile>) {
    chomp;
    my ($docid, $document_length) = split(/\t/);
    $docids->{$docid} = $document_length;
  }
  close $infile;
  Provenance::set_docids($docids);
}

my $queries = QuerySet->new($logger, $queryfile);

# Load file which contains mapping from output query name to original LDC query name
$queries = &add_ldc_query_ids($logger, $queries, $index_filename);

my $dirname = $switches->get('dir');
my @files_to_pool = <$dirname/*.valid.ldc.tab.txt> or $logger->NIST_die("No files to pool found in directory $dirname");

my $hop0_assessment_file = $switches->get("hop0_assessment_file");

# Include the hop0 assessment file to be loaded, if provided
if (defined $hop0_assessment_file) {
  $hop = 1;
  push (@files_to_pool, $hop0_assessment_file);
}

my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, @files_to_pool);
$pool->set_runid($switches->get('runid'));
$pool->set_confidence('1.0');

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}

print $program_output &pool_to_string($logger, $pool, $hop);

print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version


1;
