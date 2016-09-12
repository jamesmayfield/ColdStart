#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use Carp;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program generates the bootstrap-samples file needed by the 2016 scorer
#
# Authors: Shahzad Rajput
# Please send questions or comments to shahzad "dot" "rajput "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.0";

# Filehandles for program and error output
my $program_output;
my $error_output;


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
### DO INCLUDE Scoring                ColdStartLib.pm
### DO INCLUDE Switches               ColdStartLib.pm

### DO NOT INCLUDE
# Hush up perl worrywart module. FIXME: Not sure this is still needed.
my $pattern = $main::comment_pattern;
### DO INCLUDE

# Handle run-time switches
my $switches = SwitchProcessor->new($0,
   "Generate the bootstrap samples for 2016 scorer", "", "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);

$switches->addVarSwitch('output_file', "Where should program output be sent? (filename, stdout or stderr)");
$switches->put('output_file', 'stdout');
$switches->addVarSwitch("error_file", "Where should error output be sent? (filename, stdout or stderr)");
$switches->put("error_file", "stderr");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");

$switches->addParam("num_samples", "required", "How many random bootstrap-samples to be selected?");
$switches->addParam('index_file', "required", "Filename containing mapping from output query name to original LDC query name");

$switches->process(@ARGV);

my $logger = Logger->new();
$logger->ignore_warning('MULTIPLE_RUNIDS');

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if (lc $output_filename eq 'stdout') {
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

my $index_filename = $switches->get('index_file');
my $num_samples = $switches->get("num_samples");

my $index = load_index();

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;

package main;

sub load_index {
	my ($index_file, $index);
	open($index_file, $index_filename) or $logger->NIST_die("Could not create $index_filename: $!");
	while(<$index_file>) {
		chomp;
		my ($sf_queryid, $ldc_queryid) = split(/\s+/, $_);
		$index->{$sf_queryid} = $ldc_queryid;
	}
	close($index_file);
	$index;
}

my $samples = Bootstrap->new($logger);
print $program_output $samples->generate($num_samples, $index);

$logger->close_error_output();

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version

1;
