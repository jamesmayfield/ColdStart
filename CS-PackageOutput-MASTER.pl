#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program marshals round 1 and round 2 output for the Slot
# Filling variant of the Cold Start 2015 task. It basically just
# concatenates the two files, but it makes sure that the round 1
# responses come first (so that the corresponding queries can be
# automatically generated)
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2.0";

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

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Marshal round 1 and round 2 output for the Cold Start 2015 Slot Filling variant.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated. Only the original query file needs to be specified here");
$switches->addParam("round1file", "required", "File containing round 1 output");
$switches->addParam("round2file", "required", "File containing round 2 output");
$switches->addParam("outputfile", "required", "File into which to place combined output");


$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("outputfile");

my $logger = Logger->new();

# Allow redirection of stderr
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

# The input files to process
my $round1file = $switches->get("round1file");
$logger->NIST_die("File $round1file does not exist") unless -e $round1file;
my $round2file = $switches->get("round2file");
$logger->NIST_die("File $round2file does not exist") unless -e $round2file;

my $outputfilename = $switches->get("outputfile");
$logger->NIST_die("File $outputfilename already exists") if -e $outputfilename;
open($program_output, ">:utf8", $outputfilename) or $logger->NIST_die("Could not open $outputfilename: $!");

my $queries = QuerySet->new($logger, $queryfile);

# FIXME: parameterize discipline
my $sf_output1 = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, $round1file);
my $sf_output2 = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, $round2file);
my $runid1 = $sf_output1->get_runid();
my $runid2 = $sf_output2->get_runid();
if ($runid1 ne $runid2) {
  $logger->record_problem('MISMATCHED_RUNID', $runid1, $runid2, 'NO_SOURCE');
  $sf_output2->set_runid($runid1);
}

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
print $program_output $sf_output1->tostring("2015SFsubmissions");
print $program_output $sf_output2->tostring("2015SFsubmissions");
close $program_output;
print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Ensured all program exits are NIST-compliant
# 1.2 - Bug fixes
# 1.3 - Handle 2015 format changes
# 1.4 - Further 2015 format changes
# 2.0 - Version upped to reflect changes in the library
1;
