#!/usr/bin/perl

use warnings;
use strict;

use POSIX qw(ceil floor);

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE

use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program pools KB variant submissions transformed to SF format, SF variant 
# submissions, and ground truth from LDC. It anonymizes the run ID, maps all
# confidence values to 1.0, and sorts the results.
#
# Author: Shahzad Rajput
# Please send questions or comments to shahzad "dot" rajput "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2.3";

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

my $default_max_depth = 10;

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
	$logger->NIST_die("No matching base query") if @base_entries == 0;
	# FIXME: Make sure that the base entry is correct??
	$base_entries[0];
}

# Convert this EvaluationQueryOutput back to its proper printed representation
sub pool_to_string {
  my ($logger, $pool, $depth_param, $epsilon) = @_;
  ## Rules for $depth_param
  # $constant_depth_flag = 0 => depth unspecified
  # $constant_depth_flag = 1 => depth is constant
  # $constant_depth_flag = 2 => depth varies across slots
  my $constant_depth_flag = 0;
  my %depth;
  if(defined $depth_param){
  	if(-e $depth_param){
  		$constant_depth_flag = 2;
  		open(my $infile, "<:utf8", $depth_param) or $logger->NIST_die("Could not open $depth_param: $!");
  		while(<$infile>){
  			chomp;
  			my ($slot, $depth) = split(/\s+/);
  			$logger->NIST_die("Duplicate depth specified for slot: $slot") if(exists $depth{$slot});
  			my $delta_depth = ceil($depth*$epsilon);
  			$depth{$slot} = $depth + $delta_depth;
  		}
  		close($infile);
  	}
  	elsif($depth_param =~ /^\d+$/){
  		$constant_depth_flag = 1;
  	}
  	else{
  		$logger->NIST_die("Illegal value for depth: $depth_param")
  	}
  }
  my $hop = 0;
  my $schema_name = '2014assessments';
  my $schema = $EvaluationQueryOutput::schemas{$schema_name};
  $logger->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my $i=1;
  my %output_strings;
  my %assessment_ids;
  my $move_on_flag;
  if (defined $pool->{ENTRIES_BY_RUNS}) {
  	foreach my $run_id (keys %{$pool->{ENTRIES_BY_RUNS}}){
  		my $depth_i = 0;
  		foreach my $confidence (sort {$b<=>$a} keys %{$pool->{ENTRIES_BY_RUNS}{$run_id}}){
		    foreach my $entry (@{$pool->{ENTRIES_BY_RUNS}{$run_id}{$confidence}}) {
		      $entry->{ASSESSMENT_ID} = "00000000";
		      $entry->{QUERY_AND_SLOT_NAME} = "$entry->{QUERY_ID}:$entry->{SLOT_NAME}";
		      $entry->{VALUE_EC} = 0;
		      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
		      if ($entry->{QUERY}->{LEVEL} == $hop) {
		      	  	my $sf_query_id = $entry->{"QUERY_ID"};
		      	  	my $ldc_query_id = $entry->{"QUERY"}{"LDC_QUERY_ID"};
		      	  	$entry_string =~ s/$sf_query_id/$ldc_query_id/g;
		       	    if(not exists $assessment_ids{$entry_string}){
		       	  	  my $assessment_id = sprintf("%s_%d_%03d",$ldc_query_id, $hop, $i);
		      	  	  $assessment_ids{$entry_string} = $assessment_id;
		      	  	  $entry_string =~ s/^00000000/$assessment_id/;
		          	  $output_strings{ $entry_string }++;
		          	  $i++;
		      	    }
		      }
		      $depth_i++;
		      $move_on_flag = 0;
		      my $slot = $entry->{SLOT_NAME};
		      my $max_depth;
		      $max_depth = $depth_param if($constant_depth_flag == 1);
		      $max_depth = $depth{$slot} if($constant_depth_flag == 2);
		      
		      $logger->record_problem('UNDEFINED_SLOT_DEPTH', $slot, $default_max_depth, {FILENAME => __FILE__, LINENUM => __LINE__}) 
		      			unless $max_depth;
		      $max_depth = $default_max_depth unless $max_depth;
		      $move_on_flag = 1 if($depth_i == $max_depth); 
		      last if($move_on_flag == 1 && defined $depth_param);
		    }
		    last if($move_on_flag == 1 && defined $depth_param);
  		}
  	}
  }
  my $retVal = "";
  
  $retVal = join("\n", sort keys %output_strings). "\n" 
  				if (scalar(keys %output_strings) > 0);
  
  $retVal;
}

# Generate pool for hop1 (round#2)
sub generate_pool_hop1 {
  my ($logger, $pool, $output_dir, $depth, $epsilon) = @_;
	
  # FIXME: Handle $depth
  #
  # We don't need to handle this now because most likely we are adding all 
  # entries for selected queries for assessment. But, should it be the case
  # that we need to subsample then this method would need considerable change.
	
  my $hop = 1;
  my $schema_name = '2014assessments';
  my $schema = $EvaluationQueryOutput::schemas{$schema_name};
  $logger->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my %assessment_ids;
  my %hop1_ldc_ecs;
  if (defined $pool->{ENTRIES_BY_TYPE}) {
    foreach my $entry (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID} ||
			     lc $a->{VALUE} cmp lc $b->{VALUE} ||
			     $a->{VALUE_PROVENANCE}->tostring() cmp $b->{VALUE_PROVENANCE}->tostring()}
		       @{$pool->{ENTRIES_BY_TYPE}{SUBMISSION}}) {
      $entry->{ASSESSMENT_ID} = "00000000";
      $entry->{QUERY_AND_SLOT_NAME} = "$entry->{QUERY_ID}:$entry->{SLOT_NAME}";
      $entry->{VALUE_EC} = 0;
      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      if ($entry->{QUERY}->{LEVEL} == $hop) {
      	  my $base_entry = &get_base_entry($logger, $entry, $pool);
      	  if($base_entry->{JUDGMENT} eq "CORRECT" || $base_entry->{VALUE_ASSESSMENT} eq "INEXACT"){
	      	  my $base_entry_ec = $base_entry->{VALUE_EC};
	      	  my $base_entry_query_id = $base_entry->{QUERY_ID};
	      	  my $base_entry_ldc_query_id = $base_entry->{QUERY}->{LDC_QUERY_ID};
	      	  my $entry_sf_query_id = $entry->{QUERY_ID};
	      	  my $ldc_ec = "$base_entry_query_id:$base_entry_ec";
	      	  $ldc_ec =~ s/$base_entry_query_id/$base_entry_ldc_query_id/;
	      	  $hop1_ldc_ecs{$ldc_ec}++;
      	  }
      }
	}
  }
  
  my $i = 1;
  foreach my $kit_ldc_ec(keys %hop1_ldc_ecs) {
  	my %output_strings;
  	my $kit_hop1_query_dir = "$output_dir/$kit_ldc_ec";
  	`mkdir $kit_hop1_query_dir`;
	my $output_filename = "$kit_hop1_query_dir/hop1_pool.csldc";
	open(my $outfile, ">:utf8", $output_filename) or $logger->NIST_die("Could not open $output_filename: $!");
  	foreach my $entry (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID} ||
			     lc $a->{VALUE} cmp lc $b->{VALUE} ||
			     $a->{VALUE_PROVENANCE}->tostring() cmp $b->{VALUE_PROVENANCE}->tostring()}
		       @{$pool->{ENTRIES_BY_TYPE}{SUBMISSION}}) {
      $entry->{ASSESSMENT_ID} = "00000000";
      $entry->{QUERY_AND_SLOT_NAME} = "$entry->{QUERY_ID}:$entry->{SLOT_NAME}";
      $entry->{VALUE_EC} = 0;
      my $entry_string = join("\t", map {$pool->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      if ($entry->{QUERY}->{LEVEL} == $hop) {
      	  my $base_entry = &get_base_entry($logger, $entry, $pool);
      	  my $base_entry_ec = $base_entry->{VALUE_EC};
      	  my $base_entry_query_id = $base_entry->{QUERY_ID};
      	  my $base_entry_ldc_query_id = $base_entry->{QUERY}->{LDC_QUERY_ID};
      	  my $base_entry_ldc_ec = "$base_entry_ldc_query_id:$base_entry_ec";
      	  next if($base_entry_ldc_ec ne $kit_ldc_ec); 
      	  my $entry_sf_query_id = $entry->{QUERY_ID};
      	  my $ldc_ec = $kit_ldc_ec;
      	  $entry_string =~ s/$entry_sf_query_id/$ldc_ec/;
      	  my $sf_query_id = $entry->{"QUERY_ID"};
      	  my $ldc_query_id = $entry->{"QUERY"}{"LDC_QUERY_ID"};
      	  $entry_string =~ s/$sf_query_id/$ldc_query_id/g;
      	  if(not exists $assessment_ids{$entry_string}){
      	  	my $assessment_id = sprintf("%s_%d_%03d",$ldc_query_id, $hop, $i);
      	  	$assessment_ids{$entry_string} = $assessment_id;
      	  	$entry_string =~ s/^00000000/$assessment_id/;
          	$output_strings{ $entry_string }++ if($base_entry->{JUDGMENT} eq "CORRECT" || $base_entry->{VALUE_ASSESSMENT} eq "INEXACT");
          	$i++;
      	  }
      }
	}
	print $outfile join("\n", sort keys %output_strings), "\n";
	close($outfile);
  }
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Create a pool from the submissions.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify an output file with warnings repaired. Omit for validation only");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch('output_dir', "Specify an output directory in which the kits for hop-1 should be created. Only required when pool for hop-1 (round#2) are being created.");
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('runid', "Specify the Run ID for the pooled run");
$switches->put('runid', 'Pool');
$switches->addVarSwitch('depth', "Specify the maximum depth for the pooled runs. This could be an integer value constant across slots or could be a file containing different slot depths written as slot and depth pair separated by space, one pair per line.");
$switches->addVarSwitch('epsilon', "Epsilon used for depth pooling where depth varies per slot");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addVarSwitch('hop0_assessment_file', "Tab-separated file containing \"expanded\" hop0 assessments (\'hop0_pool.cssf.assessed\'). Required for generating pool for hop-1.");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the input files");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addParam("dir", "required", "Directory containing files to pool.");

$switches->process(@ARGV);

my $hop = 0;
my $queryfile = $switches->get("queryfile");
my $index_filename = $switches->get("index_file");
my $output_dir = $switches->get("output_dir");
my $depth = $switches->get("depth");
my $epsilon = $switches->get("epsilon");

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

# Prepare $pool->{ENTRIES_BY_RUNS}

if (defined $pool->{ENTRIES_BY_TYPE}) {
    foreach my $entry (@{$pool->{ENTRIES_BY_TYPE}{SUBMISSION}}) {
    	push( @{$pool->{ENTRIES_BY_RUNS}{$entry->{RUNID}}{$entry->{CONFIDENCE}}}, $entry );
    }
}

$pool->set_runid($switches->get('runid'));
$pool->set_confidence('1.0');

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}

if($hop == 0) {
	print $program_output &pool_to_string($logger, $pool, $depth, $epsilon);
}
elsif($hop == 1){
	&generate_pool_hop1($logger, $pool, $output_dir, $depth, $epsilon);
}
else{
	$logger->NIST_die("Incorrect hop:$hop");
}

print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 2.0 - Pooling in two steps with global equivalence classes. Conforms to 2015 format.
# 2.1 - Empty files are properly ignored rather than exiting the program.
# 2.2 - In this release, we have fixed the output when all the submission files are empty.
# 2.3 - Support added for pooling upto a certain depth, and depth/per slot with epsilon.
 
1;
