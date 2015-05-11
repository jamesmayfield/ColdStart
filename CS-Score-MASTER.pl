#!/usr/bin/perl

use warnings;
use strict;
use utf8;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program scores Cold Start 2014 submissions. It takes as input
# the evaluation queries, the appropriate assessment files, and a
# submission file. The submission file is either a Slot Filling
# variant submission file, or the result of applying the evaluation
# queries to a submitted knowledge base (typically obtained by running
# CS-ResolveQueries.pl)
#
# Authors: James Mayfield, Shahzad Rajput
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2.0";

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
# Hush up perl worrywart module. Not sure this is still needed.
my $pattern = $main::comment_pattern;

### DO INCLUDE

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Score one or more TAC Cold Start runs",
				   "Discipline is one of the following:\n" . EvaluationQueryOutput::get_all_disciplines());
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);

$switches->addVarSwitch('output_file', "Where should program output be sent? (filename, stdout or stderr)");
$switches->put('output_file', 'stdout');
$switches->addVarSwitch("error_file", "Where should error output be sent? (filename, stdout or stderr)");
$switches->put("error_file", "stdout");
$switches->addConstantSwitch("tabs", "true", "Use tabs to separate output fields instead of spaces");
$switches->addVarSwitch("discipline", "Discipline for identifying ground truth (see below for options)");
$switches->put("discipline", 'ASSESSED');

# Shahzad: Which of thes switches do we want to keep?
# $switches->addVarSwitch("runids", "Colon-separated list of run IDs to be scored");
$switches->addConstantSwitch('showmissing', 'true', "Show missing assessments");
# $switches->addConstantSwitch('components', 'true', "Show component scores for each query");
# $switches->addVarSwitch("queries", "file or colon-separated list of queries to be scored " .
# 			           "(if omitted, all query files in 'files' parameter will be scored)");

$switches->addParam("files", "required", "all others", "Query files, submission files and judgment files");

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

my $discipline = $switches->get('discipline');
my $use_tabs = $switches->get("tabs");

my @filenames = @{$switches->get("files")};
my @queryfilenames = grep {/\.xml$/} @filenames;
my @runfilenames = grep {!/\.xml$/} @filenames;
my $queries = QuerySet->new($logger, @queryfilenames);
my $submissions_and_assessments = EvaluationQueryOutput->new($logger, $discipline, $queries, @runfilenames);

#print "Scoring: ", join(", ", @query_ids_to_score), "\n";

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;

package main;

my @fields_to_print = (
  {NAME => 'EC',               HEADER => 'QID/EC',   FORMAT => '%s',    WIDTH => 20,	MACRO_AVG => 1},
  {NAME => 'RUNID',            HEADER => 'Run ID',   FORMAT => '%s',    WIDTH => 12,	MACRO_AVG => 1},
  {NAME => 'LEVEL',            HEADER => 'Hop',      FORMAT => '%s',    WIDTH => 4,		MACRO_AVG => 1},
  {NAME => 'NUM_GROUND_TRUTH', HEADER => 'GT',       FORMAT => '%4d',   WIDTH => 5,  MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_CORRECT',      HEADER => 'Right',    FORMAT => '%4d',   WIDTH => 5,  MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_INCORRECT',    HEADER => 'Wrong',    FORMAT => '%4d',   WIDTH => 5,  MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_REDUNDANT',    HEADER => 'Dup',      FORMAT => '%4d',   WIDTH => 5,  MEAN_FORMAT => '%4.2f'},
  {NAME => 'PRECISION',        HEADER => 'Prec',     FORMAT => '%6.4f', WIDTH => 7},
  {NAME => 'RECALL',           HEADER => 'Recall',   FORMAT => '%6.4f', WIDTH => 7},
  {NAME => 'F1',               HEADER => 'F1',       FORMAT => '%6.4f', WIDTH => 7, MACRO_AVG => 1},
);

sub print_headers {
  my $header = "";
  foreach my $field (@fields_to_print) {
  	my $separator = $switches->get("tabs") ? "\t" : ' ' x ($field->{WIDTH} - length($field->{HEADER})) . ' ';
    $header .= "$field->{HEADER}$separator";
  }
  print $program_output "$header\n";
}

sub aggregate_score {
  my ($aggregates, $runid, $level, $scores) = @_;
  # Make sure the necessary aggregate structures are present
  unless (defined $aggregates->{$runid}{$level}) {
    my $scoreset = ScoreSet->new();
    $scoreset->put('RUNID', $runid);
    $scoreset->put('EC', 'ALL');
    $scoreset->put('LEVEL', $level);
    $aggregates->{$runid}{$level} = $scoreset;
  }
  # Aggregate this set of scores for regular slots
  $aggregates->{$runid}{$level}->add($scores);
}

sub print_scores_line {
  my ($scores) = @_;
  foreach my $field (@fields_to_print) {
    my $text = sprintf($field->{FORMAT}, $scores->get($field->{NAME}));
    $text = "$text" if $field->{NAME} eq 'EC';
    my $separator = $switches->get("tabs") ? "\t" : ' ' x ($field->{WIDTH} - length($text)) . ' ';
    print $program_output "$text$separator";
  }
  print $program_output "\n";
}

sub score_runid {
  my ($runid, $submissions_and_assessments, $aggregates, $queries, $show_components) = @_;
  &print_headers;
  # Score each query, printing the query-by-query scores
  foreach my $query_id (sort $queries->get_all_top_level_query_ids()) {
    my $query = $queries->get($query_id);
    # Get the scores just for this query in this run
    my @scores = $submissions_and_assessments->score_query($query, $discipline, $runid);
    # # Ignore any queries that don't have at least one ground truth correct answer
    # next unless $scores->get('NUM_GROUND_TRUTH');
    foreach my $scores (sort {substr($a->{EC}, 0, index($a->{EC}, ":")) cmp substr($b->{EC}, 0, index($b->{EC}, ":")) ||
    					substr($a->{EC},index($a->{EC}, ":")+1) cmp substr($b->{EC},index($b->{EC}, ":")+1)}
    					@scores) {
      # Aggregate scores along various axes
      if ($query->{LEVEL} == 0) {
	&aggregate_score($aggregates, $runid, $scores->{LEVEL}, $scores);
	&aggregate_score($aggregates, $runid, 'ALL',            $scores);
      }
      # FIXME
      #&print_scores_line($scores, $query->{LEVEL} ? "  #" : "") if $query->{LEVEL} == 0 || $show_components;
      &print_scores_line($scores) if $query->{LEVEL} == 0 || $show_components;
    }
  }
}

# Keep aggregate scores for regular slots
my $aggregates = {};

my @runids = $submissions_and_assessments->get_all_runids();

#my @averages = qw(ALL-micro ALL-macro);
my @averages = qw(ALL-micro);


foreach my $runid (@runids) {
  &score_runid($runid, $submissions_and_assessments, $aggregates, $queries);
  foreach my $average( @averages ){
	  foreach my $level (sort keys %{$aggregates->{$runid}}) {
	    foreach my $field (@fields_to_print) {
	      my $text = ' ';
	      if (($average eq 'ALL-macro' && exists $field->{MACRO_AVG}) || $average eq 'ALL-micro'){
		      my $value = $aggregates->{$runid}{$level}->get($field->{NAME}, $average);
		      $value = $average if $value eq 'ALL' && $field->{NAME} eq 'EC';
		      $text = sprintf($field->{FORMAT}, $value);
	      }
	      
	      print $text, ' ' x ($field->{WIDTH} - length($text)), ' ';
	    }
	    print "\n";
	  }
  }
}

$logger->close_error_output();

################################################################################
# Revision History
################################################################################

# 2.0 - Rewrite to operate off of ground truth tree
# 1.1 - Merged with Shahzad's pseudoslot scoring; added fuzzy match hooks
# 1.0 - Initial version

1;
