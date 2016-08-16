#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
#####################################################################################
# This program checks for a number of possible problems with a set of
# queries. It then converts queries containing multiple entry points,
# to multiple queries that can be distributed to CSSF teams.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
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
### DO INCLUDE Switches               ColdStartLib.pm

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
my $logger = Logger->new();

my %type_repairs = (
  none => "Do not repair mismatched slots",
  'delete-slot' => "Delete second (and all subsequent) slots",
  'delete-query' => "Delete the entire query",
);
my $type_repair_string = "{" . join("; ", map {"$_: $type_repairs{$_}"} sort keys %type_repairs) . "}";

my %subtype_repairs = (
  none => "Do not repair mismatched slots",
  repair => "Modify second slot to match first",
  'delete-slot' => "Delete second (and all subsequent) slots",
  'delete-query' => "Delete the entire query",
);
my $subtype_repair_string = "{" . join("; ", map {"$_: $subtype_repairs{$_}"} sort keys %subtype_repairs) . "}";

my %dup_repairs = (
  none => "Do not check for duplicates",
  ignore => "Check for duplicates but do not repair",
  'delete' => "Delete the later (orthographically) query",
);
my $dups_repair_string = "{" . join("; ", map {"$_: $dup_repairs{$_}"} sort keys %dup_repairs) . "}";

my %subtype_map = (
  'city' => {NORMAL => 'city', stateorprovince => 'stateorprovince', country => 'country'},
  'cities' => {NORMAL => 'city', stateorprovince => 'statesorprovinces', country => 'countries'},
  'stateorprovince' => {NORMAL => 'stateorprovince', city => 'city', country => 'country'},
  'statesorprovinces' => {NORMAL => 'stateorprovince', city => 'cities', country => 'countries'},
  'country' => {NORMAL => 'country', city => 'city', stateorprovince => 'stateorprovince'},
  'countries' => {NORMAL => 'country', city => 'cities', stateorprovince => 'statesorprovinces'},
);

sub fix_queries {
  my ($queries, $fix_types, $fix_subtypes) = @_;
  my $new_queries = QuerySet->new($queries->{LOGGER});
 query:
  foreach my $query ($queries->get_all_queries()) {
    my @repairs;
    my $max_slot = $#{$query->{SLOTS}};
    if ($fix_types ne 'none') {
      my $domains = {$query->get('ENTTYPE') => 'true'};
    num:
      foreach my $num (0..$max_slot) {
	my $predicate = $query->{PREDICATES}[$num];
	foreach my $domain (keys %{$domains}) {
	  if ($predicate->{DOMAIN}{$domain}) {
	    $domains = $predicate->{RANGE};
	    next num;
	  }
	}
	# None of the domains matched, so handle the error
	$queries->{LOGGER}->record_problem('MISMATCHED_HOP_TYPES',
					   $query->{QUERY_ID},
					   join(":", sort keys %{$domains}),
					   $query->get("SLOT$num"),
					   'NO_SOURCE');
	# delete-query requested, so skip to the next query
	next query if $fix_types eq 'delete-query';
	# alternative is delete-slot. Update max slot that will be output
	$max_slot = $num - 1;
	last num;
      }
    }
    if ($fix_subtypes ne 'none') {
      for (my $num = 0; $num < $max_slot; $num++) {
	my $slot0_subtype;
	my $predicate0 = $query->{PREDICATES}[$num]{NAME};
	if ($predicate0 =~ /^(.*?)_of_.*$/) {
	  $slot0_subtype = $subtype_map{$1}{NORMAL};
	  next unless defined $slot0_subtype;
	}
	else {
	  next;
	}
	my $slot1_subtype;
	my $slot1_prefix;
	my $slot1 = $query->get('SLOT' . ($num + 1));
	my $predicate1 = $query->{PREDICATES}[$num + 1]{NAME};
	if ($slot1 =~ /^(.*_of_)(.*)$/ || $slot1 =~ /(.*_in_)(.*)$/) {
	  $slot1_subtype = $subtype_map{$2}{NORMAL};
	  next unless defined $slot1_subtype;
	  $slot1_prefix = $1;
	}
	else {
	  next;
	}
	unless ($slot0_subtype eq $slot1_subtype) {
	  $queries->{LOGGER}->record_problem('MISMATCHED_HOP_SUBTYPES',
					     $query->{QUERY_ID},
					     $predicate0,
					     $predicate1,
					     'NO_SOURCE');
	  next query if $fix_subtypes eq 'delete-query';
	  if ($fix_subtypes eq 'delete-slot') {
	    $max_slot = $num;
	    last num;
	  }
	  my $new_slot1 = "$slot1_prefix$subtype_map{$slot1_subtype}{$slot0_subtype}";
	  push(@repairs, {KEY => 'SLOT' . ($num + 1), VALUE => $new_slot1});
	}
      }
    }
    my $new_query = $query->duplicate();
    foreach my $repair (@repairs) {
      $new_query->put($repair->{KEY}, $repair->{VALUE});
    }
    $new_query->truncate_slots($max_slot);
    $new_queries->add($new_query);
  }
  $new_queries;
}

sub check_for_duplication {
  my ($queries, $fix_duplicates) = @_;
  my $new_queries = QuerySet->new($queries->{LOGGER});
  my %exact_matches;
  my %candidate_matches;
  my %dedup;
 query:
  foreach my $query (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID}} $queries->get_all_queries()) {
    my $entrypoints = $query->get("ENTRYPOINTS");
    my $query_id = $query->get("QUERY_ID");
    foreach my $entrypoint (@{$entrypoints}) {
      my $provenance = "$entrypoint->{DOCID}:$entrypoint->{START}:$entrypoint->{END}";
      my $hashstring = "$provenance:" . join(":", @{$query->{SLOTS}});
      if (defined $exact_matches{$hashstring}) {
	unless ($dedup{$exact_matches{$hashstring}}{$query_id}++) {
	  $new_queries->add($query) if $fix_duplicates eq 'ignore';
	  $queries->{LOGGER}->record_problem("DUPLICATE_QUERY", $exact_matches{$hashstring}, $query_id, 'NO_SOURCE');
	}
	next query;
      }
      $exact_matches{$hashstring} = $query_id;
    }

    foreach my $entrypoint (@{$entrypoints}) {
      my $candidate_hashstring = "$entrypoint->{NAME}:" . join(":", @{$query->{SLOTS}});
      if (defined $candidate_matches{$candidate_hashstring} && $candidate_matches{$candidate_hashstring} ne $query_id) {
	unless ($dedup{$candidate_matches{$candidate_hashstring}}{$query_id}++) {
	  $queries->{LOGGER}->record_problem("POSSIBLE_DUPLICATE_QUERY", $candidate_matches{$candidate_hashstring}, $query_id, $entrypoint->{NAME}, "NO_SOURCE");
	  # Don't delete these, because they might be legitimate
	  $new_queries->add($query);
	  next query;
	}
      }
      $candidate_matches{$candidate_hashstring} = $query_id;
    }
    $new_queries->add($query);
  }
  $new_queries;
}

sub generate_expanded_queries {
  my ($queries, $query_base, $index_file, $languages) = @_;
  my $new_queries = QuerySet->new($queries->{LOGGER});

  foreach my $query ($queries->get_all_queries()) {
    $query->expand($query_base, $new_queries);
  }
  
  foreach my $query ($new_queries->get_all_queries()) {
    if($languages) {
    	my @query_languages = @{$query->{LANGUAGES}};
    	my %selected_languages = map {$_=>1} split(":", $languages);
    	my $skip = 1;
    	foreach my $query_language(@query_languages){
    		if(exists $selected_languages{$query_language}){
    			$skip = 0;
    			last;
    		}  
    	}
    	next if $skip;
    } 
    print $index_file $query->get("FULL_QUERY_ID"), "\t", $query->get("ORIGINAL_QUERY_ID"), "\n" if defined $index_file;
  }
  $new_queries;
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Validates query files, correcting various problems. Converts queries containing multiple entry points to multiple queries with single entry points.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('query_base', "Base name for generated queries");
$switches->put('query_base', 'TAC2015CS');
$switches->addVarSwitch('index_file', "Filename into which to place mapping from output query name to original LDC query name");
$switches->addVarSwitch('types', "Repair queries with type mismatches (choices are $type_repair_string)");
$switches->put('types', 'none');
$switches->addVarSwitch('subtypes', "Repair queries with subtype mismatches (choices are $subtype_repair_string)");
$switches->put('subtypes', 'none');
$switches->addVarSwitch('languages', "Select the languages to be considered for output.");
$switches->put('languages', 'ENGLISH:CHINESE:SPANISH');
$switches->addConstantSwitch('expand', 'true', "Expand single queries with multiple entry points into multiple queries with single entry points");
$switches->addVarSwitch('dups', "Check whether different queries with the same slots share one or more entry points (choices are $dups_repair_string)");
$switches->put('dups', 'none');
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated. Only the original query file needs to be specified here");
$switches->addParam("outputfile", "required", "File into which to place combined output");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("outputfile");
my $query_base = $switches->get('query_base');
my $languages = $switches->get('languages');

my $fix_types = lc $switches->get('types');
$logger->NIST_die("Unknown -types argument: $fix_types") unless $type_repairs{$fix_types};
my $fix_subtypes = lc $switches->get('subtypes');
$logger->NIST_die("Unknown -subtypes argument: $fix_subtypes") unless $subtype_repairs{$fix_subtypes};

my $fix_dups = lc $switches->get('dups');
$logger->NIST_die("Unknown -dups argument: $fix_dups") unless $dup_repairs{$fix_dups};

# Allow redirection of stderr
my $error_filename = $switches->get("error_file");
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();

my $outputfilename = $switches->get("outputfile");
$logger->NIST_die("File $outputfilename already exists") if -e $outputfilename;
open($program_output, ">:utf8", $outputfilename) or $logger->NIST_die("Could not open $outputfilename: $!");

my $index_filename = $switches->get('index_file');
my $index_file;
if (defined $index_filename) {
  $logger->NIST_die("File $index_filename already exists") if -e $index_filename;
  open($index_file, ">:utf8", $index_filename) or $logger->NIST_die("Could not create $index_filename: $!");
}

my $queries = QuerySet->new($logger, $queryfile);

$queries = &fix_queries($queries, $fix_types, $fix_subtypes)
  if $fix_types ne 'none' || $fix_subtypes ne 'none';
$queries = &check_for_duplication($queries, $fix_dups) if $fix_dups ne 'none';
$queries = &generate_expanded_queries($queries, $query_base, $index_file, $languages) if $switches->get('expand');

print $program_output $queries->tostring("", undef, ['SLOT', 'NODEID'], $languages);

close $program_output;
close $index_file if defined $index_file;

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
# 1.1 - Added code to build index from expanded query_id to original LDC query_id
# 1.2 - Refactored generate_expanded_queries to move expansion into ColdStartLib
# 2.0 - Verion upped to make the code work with new ColdStartLib
# 2.1 - NODEID is removed from the CS-ValidateQueries output to make the SF queries file look the same as 2015.
# 2.2 - Added support for printing queries with entrypoint from selected languages
# 2.3 - Fixing the queries.index file to print queries with entrypoint from selected languages only
1;
