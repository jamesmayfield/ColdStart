#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program converts from LDC’s original queries containing multiple entry points, 
# to multiple queries that can be distributed to CSSF teams.
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

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "converts from LDC’s original queries containing multiple entry points, to multiple queries that can be distributed to CSSF teams.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated. Only the original query file needs to be specified here");
$switches->addParam("outputfile", "required", "File into which to place combined output");


$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("outputfile");

my $logger = Logger->new();

# Allow redirection of stderr
my $error_filename = $switches->get("error_file");
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();

my $outputfilename = $switches->get("outputfile");
$logger->NIST_die("File $outputfilename already exists") if -e $outputfilename;
open($program_output, ">:utf8", $outputfilename) or $logger->NIST_die("Could not open $outputfilename: $!");

my $queries = QuerySet->new($logger, $queryfile);

print $program_output "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print $program_output "<query_set>\n";

foreach my $query( $queries->get_all_queries() ){
	my $entrypoints = $query->get("ENTRYPOINTS");
	my $query_id = $query->get("QUERY_ID");
	my $split_num = 1;
	foreach my $entrypoint( @{$entrypoints} ){
		my $split_num_str = sprintf("%03d", $split_num);
		delete $query->{ENTRYPOINTS};
		push(@{$query->{ENTRYPOINTS}}, $entrypoint);
		$query->{QUERY_ID} = $query_id."_".$split_num_str;
		$query->{QUERY_ID_BASE} = $query_id."_".$split_num_str;		
		print $program_output $query->tostring();
		$split_num++;
	}
	
}
print $program_output "<query_set>\n";

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
#print $program_output $sf_output1->tostring("2014SFsubmissions");
close $program_output;
print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version

1;
