#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program produces Cold Start 2014 queries for the second round
# of a Slot Filling variant submission. It takes as input the
# evaluation queries and a first round output file.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.9";

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

# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

sub generate_round1_query {
  my ($logger, $query) = @_;
  $query->put('SLOT', $query->get('SLOT0'));
  $query;
}

my %rewrites = (
  '<' => '&lt;',
  '>' => '&gt;',
  '&' => '&amp;',
  '"' => '&quot;',
  "'" => '&apos;',
);

sub generate_round2_query {
  my ($logger, $submission, $valid) = @_;
  my $original_query = $submission->{QUERY};
  $logger->NIST_die("Query ID $submission->{QUERY_ID} not found") unless defined $original_query;
  my $new_queryid = "$submission->{QUERY_ID_BASE}_$submission->{TARGET_UUID}";
  my $new_query = Query->new($logger);
  $new_query->put('QUERY_ID', $new_queryid);
  my $name = $submission->{VALUE};
  $name =~ s/([<&>'"])/$rewrites{$1}/ge if $valid;
  $new_query->add_entrypoint(NAME => $name,
			     PROVENANCE => $submission->{VALUE_PROVENANCE});
  $new_query->put('PREFIX', $original_query->get('PREFIX'));
  foreach my $key (keys %{$original_query}) {
    $new_query->put('slot' . ($1 - 1), $original_query->get($key)) if $key =~ /^slot(\d+)$/i;
  }
  # FIXME: Should be generalized to multiple hops
  my $next_slot = $original_query->get('SLOT1');
  if (defined $next_slot) {
    my ($next_slot_type) = $next_slot =~ /^(.*?):/;
    my $submission_value_type = lc $submission->{VALUE_TYPE};
    return if ($next_slot_type ne $submission_value_type);
    $new_query->put('SLOT', $next_slot);
    $new_query->put('ENTTYPE', $next_slot_type);
  }
  $new_query;
}

sub generate_round1_queries {
  my ($logger, $queries) = @_;
  my $new_queries = QuerySet->new($logger);
  foreach my $query ($queries->get_all_queries()) {
    my $new_query = &generate_round1_query($logger, $query);
    $new_queries->add($new_query);
  }
  $new_queries;
}  

sub generate_round2_queries {
  my ($logger, $round1_submissions, $valid) = @_;
  my $new_queries = QuerySet->new($logger);
  foreach my $submission (@{$round1_submissions->{ENTRIES_BY_TYPE}{SUBMISSION}}) {
    my $new_query = &generate_round2_query($logger, $submission, $valid);
    $new_queries->add($new_query) if defined $new_query->{SLOT};
  }
  $new_queries;
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Generate a query file for a Cold Start Slot Filling variant submission. With two arguments, it updates the input queries with the <slot> field. With three arguments it generates a second round query file based on the first round slot filling output.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->addConstantSwitch('valid', 'true', "Ensure valid XML output by escaping angle brackets and ampersands");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated");
$switches->addParam("outputfile", "required", "File into which new queries are to be placed.");
$switches->addParam("runfile", "File containing query output. Omit to generate initial queries.");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
### DO NOT INCLUDE
# The following variable was never used. 
#my $outputfile = $switches->get("runfile");
### DO INCLUDE

### DO NOT INCLUDE
# my $queryfile = "/Users/mayfield/Documents/Work/TAC/2013/ColdStart/Data/LDC2013E87_TAC_2013_KBP_English_Cold_Start_Evaluation_Queries_and_Annotations/data/tac_2013_kbp_english_cold_start_evaluation_queries-corrected.xml";
# my $outputfile = "/Users/mayfield/Documents/Work/TAC/2014/ColdStart/Data/sample-sub-with-errors.tsv";
### DO INCLUDE

my $logger = Logger->new();

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("outputfile");
if (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
} elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
} else {
  open($program_output, ">:utf8", $output_filename) or $logger->NIST_die("Could not open $output_filename: $!");
}

my $error_filename = $switches->get("error_file");
if (lc $error_filename eq 'stdout') {
  $error_output = *STDOUT{IO};
}
elsif (lc $error_filename eq 'stderr') {
  $error_output = *STDERR{IO};
}
else {
  open($error_output, ">:utf8", $error_filename) or $logger->NIST_die("Could not open $error_filename: $!");
}

# Load mapping from docid to length of that document
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
}

my $queries = QuerySet->new($logger, $queryfile);

# The input file to process
my $filename = $switches->get("runfile");

if (!defined $program_output && !defined $filename) {
  print $error_output "WARNING: to generate first round queries, you should use the -output_file switch\n\n";
}

if (defined $filename) {
  $logger->NIST_die("File $filename does not exist") unless -e $filename;
  # FIXME: parameterize discipline
  my $sf_output = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, $filename);

  # Problems were identified while the KB was loaded; now report them
  my ($num_errors, $num_warnings) = $logger->report_all_problems();
  if ($num_errors) {
    $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
  }
  my $new_queries = &generate_round2_queries($logger, $sf_output, $switches->get('valid'));
  print $program_output $new_queries->tostring() if defined $program_output;
  print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
  exit 0;
}
else {
  my $new_queries = &generate_round1_queries($logger, $queries);
  print $program_output $new_queries->tostring() if defined $program_output;
  exit 0;
### DO NOT INCLUDE
  # This code was briefly considered when CS-ExpandQueries.pl was
  # introduced to remove multiple entry points from
  # queries. Ultimately we decided to keep the requirement for
  # participants to run CS-GenerateQueres.pl at the start of the
  # process to avoid having to change the documentation
  # my $short_queryfile = $queryfile;
  # $short_queryfile =~ s/.*\///;
  # print $error_output "Starting in 2015, CS-GenerateQueries does not need to be run on distributed queries.\n",
  #                     "Please use $short_queryfile directly for the first round queries.\n";
  # exit 0;
### DO INCLUDE
}

### DO NOT INCLUDE
##################################################################################### 
# Library inclusions
##################################################################################### 
### DO INCLUDE

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Eliminated improperly included junk code
# 1.2 - Ensured all program exits are NIST-compliant
# 1.3 - Bug fixes
# 1.4 - Bug fixes
# 1.5 - Added -valid option for quoting ampersands etc. so as to produce compliant XML
# 1.6 - Removed requirement to run GenerateQueries on the LDC queries (We are running CS-ExpandQueries instead)
# 1.7 - Reverted to requirement to maintain consistency with documentation; bug fixes
# 1.8 - General Release
# 1.9 - Code modified to work with new library
1;
