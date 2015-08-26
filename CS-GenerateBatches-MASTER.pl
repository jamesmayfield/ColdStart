#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program generates batches for assessing.
# This script essentially breaks the queryfile and runs into several batches. 
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


##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Generate batches from set of validated runs.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected.");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('num_batches', "The number of batches to be created. This switch cannot be set together with switch batches_file. Only one of the switches: num_batches and batches_file must be specified.");
$switches->addVarSwitch('batches_file', "File containing batch query mapping. This switch cannot be set together with switch num_batches. Only one of the switches: num_batches and batches_file must be specified.");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addParam("dir", "required", "Directory containing validated runs/submissions.");
$switches->addParam('output_directory', "required", "Specify an output directory to which the batches should be written.");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $runs_directory = $switches->get("dir");
my $output_directory = $switches->get("output_directory");
my $batches_file = $switches->get("batches_file");
my $num_batches = $switches->get("num_batches");
my $index_file = $switches->get("index_file");

my $logger = Logger->new();

$logger->NIST_die("Both switches: num_batches and batches_file specified at the same time.") 
	if(defined $num_batches && defined $batches_file);

$logger->NIST_die("None of the switches: num_batches and batches_file specified.") 
	if(!defined $num_batches && !defined $batches_file);

$logger->NIST_die("$output_directory already exists.") if -e $output_directory;

# Create output directory
`mkdir $output_directory`;

# Load index_file
my (%index, %inverted_index);
$logger->NIST_die("$index_file does not exists.") unless -e $index_file;
open(my $infile, "<:utf8", $index_file) or $logger->NIST_die("Could not open $index_file: $!");
while(<$infile>){
	chomp;
	my ($sf_query_id, $ldc_query_id) = split(/\t/);
	push (@{$index{$ldc_query_id}}, $sf_query_id);
	$inverted_index{$sf_query_id} = $ldc_query_id;
}
close($infile);

# Load or prepare batch_id to query_id mapping
my %batches;
# Load the mapping
if(defined $batches_file){
	$logger->NIST_die("$batches_file does not exists.") unless -e $batches_file;
	open(my $infile, "<:utf8", $batches_file) or $logger->NIST_die("Could not open $batches_file: $!");
	while(<$infile>){
		chomp;
		my ($batch_id, $ldc_query_id) = split(/\t/); 
		push (@{$batches{$batch_id}}, $ldc_query_id);   
	}
	close($infile);
}
# Prepare the mapping
else{
	my $i = 1;
	foreach my $ldc_query_id(keys %index){
		my $num_batch = ($i % $num_batches) + 1;
		my $batch_id = sprintf("%s_%02d", "batch", $num_batch);
		push (@{$batches{$batch_id}}, $ldc_query_id);
		$i++;
	}
}

# Generate the batch
my $query_file_name = $queryfile;
$query_file_name =~ s/(.*?\/)+//g;
foreach my $batch_id(keys %batches) {
	# create the batch directory
	my $batch_dir = "$output_directory/$batch_id";
	`mkdir $batch_dir`;
	
	# Generate the queryfile for the batch
	my $pool_query_file = "$batch_dir/$query_file_name";
	my $queries = QuerySet->new($logger, $queryfile);
	open(my $outfile, ">:utf8", $pool_query_file) or $logger->NIST_die("Could not open $pool_query_file: $!");
	print $outfile "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<query_set>\n";
	foreach my $ldc_query_id($queries->get_all_query_ids()) {
		if(grep {$_ eq $ldc_query_id} @{$batches{$batch_id}}) {
			# $ldc_query_id is member of this batch
			my $query = $queries->get($ldc_query_id);
			print $outfile $query->tostring("  ");
		}
	}
	print $outfile "</query_set>";
	close($outfile);
	
	# Generate the runs for the batch
	my $batch_runs_dir = "$batch_dir/runs";
	
	# Generate the runs directory
	`mkdir $batch_runs_dir`;
	
	# Generate the runs
	my @files_to_pool = <$runs_directory/*.valid.ldc.tab.txt> or $logger->NIST_die("No files to pool found in directory $runs_directory");
	foreach my $run_file(@files_to_pool) {
		$run_file =~ /^(.*?\/)*(.*?)$/;
		my $batch_run_file = "$batch_runs_dir/$2";
		open(my $outfile, ">:utf8", $batch_run_file) or $logger->NIST_die("Could not open $batch_run_file: $!");
		open(my $infile, "<:utf8", $run_file) or $logger->NIST_die("Could not open $run_file: $!");
		while(my $line = <$infile>){
			$line =~ /^(.*?)\t/;
			my $sf_query_id = $1;
			if($sf_query_id =~ /^(.*?)\_(.*?)\_(.*?)$/) {
				$sf_query_id = "$1\_$2";
			}
			my $ldc_query_id = $inverted_index{$sf_query_id};
			if(not exists $inverted_index{$sf_query_id}) {
				print "error\n";
			}
			if(grep {$_ eq $ldc_query_id} @{$batches{$batch_id}}) {
				print $outfile $line;
			}
		}
		close($infile);
		close($outfile);
	}
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
