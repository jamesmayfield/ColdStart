#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program transforms the SF assessment file with numeric equivalence class to 
# one with fully qualified equivalence class.
#
# Author: Shahzad Rajput
# Please send questions or comments to shahzad.rajput "at" gmail "dot" com
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

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Transform the SF assessment file with numeric equivalence class to one with fully qualified equivalence class","");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify an output file. Omit for output to be redirected to STDOUT");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("assessmentsfile", "required", "Slot filling assessment file containing numeric equivalence classes");
$switches->addParam("queryfile", "required", "File containing slot filling queries");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $assessmentsfile = $switches->get("assessmentsfile");

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

my $queries = QuerySet->new($logger, $queryfile);
my $pool = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, $assessmentsfile);

foreach my $entry(sort {$a->{LINENUM} <=> $b->{LINENUM}} @{$pool->{ENTRIES_BY_TYPE}{ASSESSMENT}}) {
	my $line = $entry->{LINE};
	my @elements = split(/\t/, $line);
	my $value_ec = pop(@elements);
	if($value_ec ne "0") {
		if($entry->{QUERY}->{LEVEL} == 0) {
			$value_ec = $entry->{QUERY_ID}.":".$value_ec;
		}
		else{
			my $parent_entry = $pool->{QUERYID2PARENTASSESSMENT}{$entry->{QUERY_ID}};
			my $parent_value_ec = $parent_entry->{VALUE_EC};
			$value_ec = "$parent_value_ec:$value_ec";
		}
		$entry->{VALUE_EC} = $value_ec;
	}
	$line = join("\t", @elements)."\t".$value_ec;
	print $program_output "$line\n";
}
