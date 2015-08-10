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

my $version = "1.2";

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

my %subtype_map = (
  'city' => {NORMAL => 'city', state => 'stateorprovince', country => 'country'},
  'cities' => {NORMAL => 'city', state => 'statesorprovinces', country => 'countries'},
  'stateorprovince' => {NORMAL => 'state', city => 'city', country => 'country'},
  'statesorprovinces' => {NORMAL => 'state', city => 'cities', country => 'countries'},
  'country' => {NORMAL => 'country', city => 'city', state => 'stateorprovince'},
  'countries' => {NORMAL => 'country', city => 'cities', state => 'statesorprovinces'},
);

sub fix_queries {
  my ($queries, $fix_types, $fix_subtypes) = @_;
  my $new_queries = QuerySet->new($logger);
  foreach my $query ($queries->get_all_queries()) {
&main::dump_structure($query, 'query', [qw(LOGGER)]);
    foreach my $num (0..($#{$query->{SLOTS}} - 1)) {
      my $first_slot = $query->get("SLOT$num");
      my $first_predicate = $query->{PREDICATES}[$num];
      my $second_slot = $query->get("SLOT" . ($num + 1));
      my $second_predicate = $query->{PREDICATES}[$num + 1];
      if ($fix_types ne 'none') {
      }
    }
  }
  $new_queries;
}

sub generate_expanded_queries {
  my ($queries, $query_base) = @_;
  my $new_queries = QuerySet->new($logger);
  my %all_query_ids;

  foreach my $query ($queries->get_all_queries()) {
    my $entrypoints = $query->get("ENTRYPOINTS");
    my $query_id = $query->get("QUERY_ID");
    foreach my $entrypoint (@{$entrypoints}) {
      my $new_query = $query->duplicate('ENTRYPOINTS');
      $new_query->add_entrypoint(%{$entrypoint});
      my $short_uuid = $new_query->get_short_uuid();
      $new_query->put('QUERY_ID', "${query_base}_$short_uuid");
### DO NOT INCLUDE
      my $new_queryid = $new_query->get('QUERY_ID');
      print STDERR "Duplicate: $new_queryid\t$query_id\t$all_query_ids{$new_queryid}\n" if defined $all_query_ids{$new_queryid};
      $all_query_ids{$new_queryid} = $query_id;
### DO INCLUDE
      delete $new_query->{SLOT};
      $new_queries->add($new_query);
    }
  }
  $new_queries;
}

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
$switches->addVarSwitch('query_base', "Base name for generated queries");
$switches->put('query_base', 'TAC2015CS');
$switches->addVarSwitch('types', "Repair queries with type mismatches (choices are $type_repair_string)");
$switches->put('types', 'none');
$switches->addVarSwitch('subtypes', "Repair queries with subtype mismatches (choices are $subtype_repair_string)");
$switches->put('subtypes', 'none');
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated. Only the original query file needs to be specified here");
$switches->addParam("outputfile", "required", "File into which to place combined output");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("outputfile");
my $query_base = $switches->get('query_base');

my $fix_types = lc $switches->get('types');
$logger->NIST_die("Unknown -types argument: $fix_types") unless $type_repairs{$fix_types};
my $fix_subtypes = lc $switches->get('subtypes');
$logger->NIST_die("Unknown -subtypes argument: $fix_subtypes") unless $subtype_repairs{$fix_subtypes};

# Allow redirection of stderr
my $error_filename = $switches->get("error_file");
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();

my $outputfilename = $switches->get("outputfile");
$logger->NIST_die("File $outputfilename already exists") if -e $outputfilename;
open($program_output, ">:utf8", $outputfilename) or $logger->NIST_die("Could not open $outputfilename: $!");

my $queries = QuerySet->new($logger, $queryfile);

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}

$queries = &fix_queries($queries, $fix_types, $fix_subtypes)
  if $fix_types ne 'none' || $fix_subtypes ne 'none';
$queries = &generate_expanded_queries($queries, $query_base);

print $program_output $queries->tostring("", undef, [qw(SLOT)]);

# print $program_output "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
# print $program_output "<query_set>\n";
# foreach my $query (sort {$a->get('QUERY_ID') cmp $b->get('QUERY_ID')} $new_queries->get_all_queries()) {
#   print $program_output $query->tostring('  ', [qw(SLOT)]);
# }
# print $program_output "<query_set>\n";

close $program_output;
print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Modified to obfuscate the relationships among queries
# 1.2 - Added type match checking

1;
