#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program validates Cold Start 2014 Slot Filling variant
# submissions. It takes as input the evaluation queries and a Slot
# Filling variant output file. Optionally, it will repair problems
# that lead to warnings and output a revised run file.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2017.2.0";

# Filehandles for program and error output
my $program_output = *STDOUT{IO};
my $error_output = *STDERR{IO};

### DO NOT INCLUDE
##################################################################################### 
# Library inclusions
##################################################################################### 
### DO INCLUDE
### DO INCLUDE Header                 ColdStartLib.pm
### DO INCLUDE Utils                  ColdStartLib.pm
### DO INCLUDE Patterns               ColdStartLib.pm
### DO INCLUDE Logger                 ColdStartLib.pm
### DO INCLUDE Provenance             ColdStartLib.pm
### DO INCLUDE Predicates             ColdStartLib.pm
### DO INCLUDE Query                  ColdStartLib.pm
### DO INCLUDE QuerySet               ColdStartLib.pm
### DO INCLUDE EvaluationQueryOutput  ColdStartLib.pm
### DO INCLUDE Switches               ColdStartLib.pm
### DO INCLUDE NodeTree               ColdStartLib.pm

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Validate a TAC Cold Start Slot Filling variant output file, checking for common errors.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify an output file with warnings repaired. Omit for validation only");
$switches->put('output_file', 'none');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addConstantSwitch('allow_comments', 'true', "Enable comments introduced by a pound sign in the middle of an input line");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addVarSwitch('depth', "Colon-speated scheme name and depth; to be used only at NIST.");
$switches->addConstantSwitch('groundtruth', 'true', "Treat input file as ground truth (so don't, e.g., enforce single-valued slots)");
$switches->addVarSwitch('justifications', "Are multiple justifications allowed? " .
			"Legal values are of the form A:B where A represents justifications per document and B represents total justifications. " .
			"Use \'M\' to allow any number of justifications, for e.g., \'M:10\' to allow multiple justifications per document ".
			"but overall not more than 10 (best or top) justifications.");
$switches->put('justifications', "1:3");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated");
$switches->addParam("filename", "required", "File containing query output.");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("filename");

&EvaluationQueryOutput::enable_comments() if $switches->get('allow_comments');

my $logger = Logger->new();
# It is not an error for ground truth to have multiple fills for a single-valued slot
$logger->delete_error('MULTIPLE_FILLS_SLOT') if $switches->get('groundtruth');

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if ($output_filename eq 'none') {
  undef $program_output;
}
elsif (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
}
elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
}
else {
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
    my ($docid, $document_length, $file) = split(/\t/);
    $docids->{$docid} = {LENGTH=>$document_length, FILE=>$file};
  }
  close $infile;
  Provenance::set_docids($docids);
}

my $depth = $switches->get("depth");
$logger->NIST_die("-depth should be of the form \"[AB]:d\".\n".
  "A/B is used to select\n".
  "A: top d nodes \n".
  "B: top d nodes from hop-0 and top dxd nodes from hop-1 (including parents to insure that there are no orphans)\n".
  "with respect to confidence value, in the validated output.\n"
  )
  if ($depth && $depth !~ /^[AB]:\d/);

# How should multiple justifications be handled?
my $justifications_allowed = $switches->get("justifications");
$logger->NIST_die("Argument to -justifications switch must be of the form A:B where A and B are " .
                  "either positive numbers or character \'M\' representing infinity.")
  unless $justifications_allowed =~ /^[\dM]:[\dM]$/;

# The input file to process
my $filename = $switches->get("filename");
$logger->NIST_die("File $filename does not exist") unless -e $filename;

my $queries = QuerySet->new($logger, $queryfile);

# FIXME: parameterize discipline
my $sf_output = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries,
                    {JUSTIFICATIONS_ALLOWED => $justifications_allowed,
                     DEPTH => $depth,}, $filename);

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
else{
  print $program_output $sf_output->tostring("2017SFsubmissions") if defined $program_output;
}
print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Eliminated improperly included junk code
# 1.2 - Ensured all program exits are NIST-compliant
# 1.3 - Additional checks, bug fixes
# 1.4 - Added support for -groundtruth switch to allow e.g., multiple fills for single-valued slots
# 1.5 - Handle 2015 format changes
# 1.6 - Incorporate updated libraries
# 1.7 - Added switch to enable comments, defaulting to disabled
# 1.8 - Enabled WRONG_SLOT_NAME and BAD_QUERY warnings
# 1.9 - Verion upped due to change in library.
# 2.0 - Validated output is produced only if there were no errors
# 2017.1.0 - First release of 2017
# 2017.1.1 - Node confidence computation function changed to have the denomerator
#            same irrespective of how many justifications were provided.
#            Also support added to have the confidence vary depending on allowed
#            justifications passed through parameter -justifications
# 2017.1.2 - Switch -depth introduced (to be used only at NIST)
# 2017.1.3 - INCLUDEs etc updated to allow Include.pl to successfully create standalone executables
# 2017.1.4 - INACCURACTE_MENTION_STRING made a WARNING instead of an ERROR
#          - Support added in SF validator to compare filler string with the text in source
#            document at the filler provenance
# 2017.2.0 - Code state at the release of scores
1;
