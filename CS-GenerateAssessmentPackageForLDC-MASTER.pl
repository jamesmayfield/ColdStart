#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

# perl CS-GenerateAssessmentPackageForLDC-MASTER.pl -hop 1 -intermediate_data_dir 
# /home/skr1/cold-start-collaborative/data/2015/Batches -ldc_packages_dir 
# /home/skr1/cold-start-collaborative/data/2015/ldc_package_tmp 
# /home/skr1/cold-start-collaborative/data/2015/tmp4 batch_55

### DO INCLUDE
##################################################################################### 
# This program generates the assessment package for LDC. 
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
### DO INCLUDE Logger                 ColdStartLib.pm
### DO INCLUDE Switches               ColdStartLib.pm

sub check_errors {
  my ($assessment_file) = @_;
  open(my $infile, "<:utf8", $assessment_file) or $logger->NIST_die("Could not open $assessment_file: $!");
	
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Create pools for assessment. This script is the main script to be called for pooling.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('hop', "Spefify the hop number for which the pool is being generated. Hop 0 is the same as round 1, similarly hop 1 is round 2.");
$switches->put('hop', '0');
$switches->addVarSwitch('ldc_packages_dir', "Spefify the directory containing assessment packages for LDC.");
$switches->put('ldc_packages_dir', 'AssessmentPackages');
$switches->addVarSwitch('intermediate_data_dir', "Spefify the directory containing intermediate data.");
$switches->put('intermediate_data_dir', 'Batches');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryids", "required", "File containing list of ldc-queryids included in this batch.");
$switches->addParam("batchid", "required", "The ID of the batch to be assigned to this set of queries (specifed using -queryids switch).");

$switches->process(@ARGV);

my $hop = $switches->get("hop");
my $ldc_packages_dir = $switches->get("ldc_packages_dir");
my $intermediate_data_dir = $switches->get("intermediate_data_dir");
my $queryids_file = $switches->get("queryids");
my $batchid = $switches->get("batchid");
my $error_filename = $switches->get("error_file");

my $logger = Logger->new();
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();


# Check if the script is a MASTER script, in that case MASTER of all the dependent scripts are used.
my $master = "";
$master = "-MASTER" if($0=~/MASTER/);

# Load the list of queryids included in this batch
my %queryids;
if (defined $queryids_file) {
  open(my $infile, "<:utf8", $queryids_file) or $logger->NIST_die("Could not open $queryids_file: $!");
  while(<$infile>) {
    chomp;
    $queryids{$_}++;
  }
  close $infile;
}

if($hop==0) {
  # Generate the assessment file for hop-0
  
  my $ldc_batch_dir = "$ldc_packages_dir/$batchid";
  system("mkdir $ldc_batch_dir") if(not -e $ldc_batch_dir);
  my $ldc_hop_dir = "$ldc_batch_dir/hop_$hop";
  $logger->NIST_die("$ldc_hop_dir already exists.") if(-e $ldc_hop_dir);
  system("mkdir $ldc_hop_dir");
  
  my $intermediate_batch_dir = "$intermediate_data_dir/$batchid";
  system("mkdir $intermediate_batch_dir") if(not -e $intermediate_batch_dir);  
  
  foreach my $query_id(sort keys %queryids) {
  	my $query_dir = "$intermediate_data_dir/batch_99/$query_id";
  	$logger->NIST_die("$query_dir does not exist: $!") if(not -e $query_dir);
  	system("cp -r $query_dir $intermediate_batch_dir");
  	
  	my $slot0 = `grep "<slot0>" $query_dir/tac_kbp_2015_english_cold_start_evaluation_queries_v2.xml`;
  	$slot0 =~ /<slot0>(.*?)<\/slot0>/;
  	$slot0 = $1;
  	$slot0 =~ s/\:/_/g;
  	
  	my $destination_file = "$ldc_hop_dir/$query_id\_$slot0";
  	system("cp $query_dir/hop0_pool.csldc $destination_file");
  }
}
elsif($hop==1) {
  my $ldc_batch_dir = "$ldc_packages_dir/$batchid";
  my $ldc_hop0_dir = "$ldc_batch_dir/hop_0";
  $logger->NIST_die("$ldc_hop0_dir does not exists.") if(not -e $ldc_hop0_dir);
  my $ldc_hop1_dir = "$ldc_batch_dir/hop_1";
  $logger->NIST_die("$ldc_hop1_dir already exists.") if(-e $ldc_hop1_dir);
  system("mkdir $ldc_hop1_dir");
  # Create the hop-1 pools
  foreach my $query_id(sort keys %queryids) {
	my $query_dir = "$intermediate_data_dir/$batchid/$query_id";
  	my $slot0 = `grep "<slot0>" $query_dir/tac_kbp_2015_english_cold_start_evaluation_queries_v2.xml`;
  	$slot0 =~ /<slot0>(.*?)<\/slot0>/;
  	$slot0 = $1;
  	$slot0 =~ s/\:/_/g;
  	
  	my $ldc_assessed_hop0_file = "$ldc_hop0_dir/$query_id\_$slot0";
  	
	$logger->NIST_die("Multiple equivalence class for a mention.") if(check_errors($ldc_assessed_hop0_file)==1);
  	
  	system("cp $ldc_assessed_hop0_file $query_dir/hop0_pool.csldc.assessed");
  	system("perl CS-Pooler$master.pl -batches_dir $intermediate_data_dir -hop 1 $batchid $query_id");
  	
  	my $error_check = `cat $intermediate_data_dir/$batchid/*/hop1_pool.errlog | wc -l`;
  	$logger->NIST_die("Errors encountered. See files $intermediate_data_dir/$batchid/*/hop1_pool.errlog for detail.") if($error_check>1); 
  	
  	# Move the files over to the flat directory structure format for LDC
  	
  }	
}
else {
  $logger->NIST_die("Unexpected value \"$hop\" for hop.");
}


################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
1;
