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
# This program scores Cold Start 2015 submissions. It takes as input
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

my $version = "2.1";

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
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");

### DO NOT INCLUDE
# Shahzad: Which of thes switches do we want to keep?
#$switches->addConstantSwitch('showmissing', 'true', "Show missing assessments");
# $switches->addVarSwitch("runids", "Colon-separated list of run IDs to be scored");
# $switches->addConstantSwitch('components', 'true', "Show component scores for each query");
# $switches->addVarSwitch("queries", "file or colon-separated list of queries to be scored " .
# 			           "(if omitted, all query files in 'files' parameter will be scored)");
### DO INCLUDE
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

# Load index file
my $indexfile = $switches->get("index_file");
my $input;
my %index;
open($input, "<:utf8", $indexfile);
while(<$input>) {
	chomp;
	my ($cssf_query_id, $csldc_query_id) = split(/\t/);
	$index{$cssf_query_id} = $csldc_query_id;
}
close($input);


my @filenames = @{$switches->get("files")};
my @queryfilenames = grep {/\.xml$/} @filenames;
my @runfilenames = grep {!/\.xml$/} @filenames;
my $queries = QuerySet->new($logger, @queryfilenames);
my $submissions_and_assessments = EvaluationQueryOutput->new($logger, $discipline, $queries, @runfilenames);

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;

package ScoresPrinter;

my @fields_to_print = (
  {NAME => 'LDC_QUERY_ID',     HEADER => 'LDC_QID',  FORMAT => '%s',     JUSTIFY => 'L'},
  {NAME => 'EC',               HEADER => 'QID/EC',   FORMAT => '%s',     JUSTIFY => 'L'},
  {NAME => 'RUNID',            HEADER => 'Run ID',   FORMAT => '%s',     JUSTIFY => 'L'},
  {NAME => 'LEVEL',            HEADER => 'Hop',      FORMAT => '%s',     JUSTIFY => 'L'},
  {NAME => 'NUM_GROUND_TRUTH', HEADER => 'GT',       FORMAT => '%4d',    JUSTIFY => 'R', MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_CORRECT',      HEADER => 'Right',    FORMAT => '%4d',    JUSTIFY => 'R', MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_INCORRECT',    HEADER => 'Wrong',    FORMAT => '%4d',    JUSTIFY => 'R', MEAN_FORMAT => '%4.2f'},
  {NAME => 'NUM_REDUNDANT',    HEADER => 'Dup',      FORMAT => '%4d',    JUSTIFY => 'R', MEAN_FORMAT => '%4.2f'},
  {NAME => 'PRECISION',        HEADER => 'Prec',     FORMAT => '%6.4f',  JUSTIFY => 'L'},
  {NAME => 'RECALL',           HEADER => 'Recall',   FORMAT => '%6.4f',  JUSTIFY => 'L'},
  {NAME => 'F1',               HEADER => 'F1',       FORMAT => '%6.4f',  JUSTIFY => 'L'},
);

sub new {
  my ($class, $separator) = @_;
  my $self = {FIELDS_TO_PRINT => \@fields_to_print,
	      WIDTHS => {map {$_->{NAME} => length($_->{HEADER})} @fields_to_print},
	      HEADERS => [map {$_->{HEADER}} @fields_to_print],
	      LINES => [],
	     };
  $self->{SEPARATOR} = $separator if defined $separator;
  bless($self, $class);
  $self;
}

sub add_score {
  my ($self, $score) = @_;
  my $ec = $score->{EC};
  my @components = split(/:/, $ec);
  my $cssf_query_id = shift(@components);
  my $csldc_query_id = $index{$cssf_query_id};
  $score->{LDC_QUERY_ID} = $csldc_query_id;
  $score->{LDC_QUERY_ID} = "ALL-Micro" if not defined $score->{LDC_QUERY_ID};
  my %elements_to_print;
  foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
    my $text = sprintf($field->{FORMAT}, $score->get($field->{NAME}));
    $elements_to_print{$field->{NAME}} = $text;
    $self->{WIDTHS}{$field->{NAME}} = length($text) if length($text) > $self->{WIDTHS}{$field->{NAME}};
  }
  push(@{$self->{LINES}}, \%elements_to_print);
}

sub print_line {
  my ($self, $line) = @_;
  my $separator = "";
  foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
    my $value = (defined $line ? $line->{$field->{NAME}} : $field->{HEADER});
    print $program_output $separator;
    my $numspaces = defined $self->{SEPARATOR} ? 0 : $self->{WIDTHS}{$field->{NAME}} - length($value);
    print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'R' && !defined $self->{SEPARATOR};
    print $program_output $value;
    print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'L' && !defined $self->{SEPARATOR};
    $separator = defined $self->{SEPARATOR} ? $self->{SEPARATOR} : ' ';
  }
  print $program_output "\n";
}
  
sub print_headers {
  my ($self) = @_;
  $self->print_line();
}

sub print_lines {
  my ($self) = @_;
  my @lines = sort {$a->{LDC_QUERY_ID} cmp $b->{LDC_QUERY_ID} || $a->{EC} cmp $b->{EC}} 
  				grep {$_->{EC} =~ /^CS/} @{$self->{LINES}};
  push(@lines, grep {$_->{EC} !~ /^CS/} @{$self->{LINES}});
  foreach my $line (@lines) {
    $self->print_line($line);
  }
}

package main;

sub aggregate_score {
  my ($aggregates, $runid, $level, $scores) = @_;
  # Make sure the necessary aggregate structures are present
  unless (defined $aggregates->{$runid}{$level}) {
    my $scoreset = ScoreSet->new();
    $scoreset->put('RUNID', $runid);
    $scoreset->put('EC', 'ALL-Micro');
    $scoreset->put('LEVEL', $level);
    $aggregates->{$runid}{$level} = $scoreset;
  }
  # Aggregate this set of scores for regular slots
  $aggregates->{$runid}{$level}->add($scores);
}

# Compare two equivalence class names; comparison is alphabetic for
# the first component, and numerical for all subsequent
# components. This is broken out as a separate function to ensure that
# queries with more than two hops are supported in some fantasized
# future
sub compare_ec_names {
  my ($qa, @a) = split(/:/, $a->{EC});
  my ($qb, @b) = split(/:/, $b->{EC});
  $qa cmp $qb ||
    eval(join(" || ", map {$a[$_] <=> $b[$_]} 0..&min($#a, $#b))) ||
    scalar @a <=> scalar @b;
}

sub score_runid {
  my ($runid, $submissions_and_assessments, $aggregates, $queries, $use_tabs) = @_;
  my $scores_printer = ScoresPrinter->new($use_tabs ? "\t" : undef);
  # Score each query, printing the query-by-query scores
  foreach my $query_id (sort $queries->get_all_top_level_query_ids()) {
    my $query = $queries->get($query_id);
    # Get the scores just for this query in this run
    my @scores = $submissions_and_assessments->score_query($query, $discipline, $runid);
### DO NOT INCLUDE
    # # Ignore any queries that don't have at least one ground truth correct answer
    # next unless $scores->get('NUM_GROUND_TRUTH');
### DO INCLUDE
    foreach my $scores (sort compare_ec_names @scores) {
      $scores_printer->add_score($scores);
      # Aggregate scores along various axes
      if ($query->{LEVEL} == 0) {
	&aggregate_score($aggregates, $runid, $scores->{LEVEL}, $scores);
	&aggregate_score($aggregates, $runid, 'ALL',            $scores);
      }
### DO NOT INCLUDE
      # FIXME
#      &print_scores_line($scores, $query->{LEVEL} ? "  #" : "") if $query->{LEVEL} == 0 || $show_components;
### DO INCLUDE
    }
  }
  $scores_printer;
}

# Keep aggregate scores for regular slots
my $aggregates = {};

my @runids = $submissions_and_assessments->get_all_runids();

foreach my $runid (@runids) {
  my $scores_printer = &score_runid($runid, $submissions_and_assessments, $aggregates, $queries, $use_tabs);

  # Only report on hops that are present in the run
  foreach my $level (sort keys %{$aggregates->{$runid}}) {
    # Print the micro-averaged scores
    $scores_printer->add_score($aggregates->{$runid}{$level});
  }

  $scores_printer->print_headers();
  $scores_printer->print_lines();
### DO NOT INCLUDE
  
  # Shahzad: This is the macro averaging code that doesn't work anymore
  # # Only report on hops that are present in the run
  # foreach my $level (sort keys %{$aggregates->{$runid}}) {
  #   # Print the macro-averaged scores
  #   foreach my $field (@fields_to_print) {
  #     my $value;
  #     if ($field->{NAME} eq 'QUERY_ID' ||
  # 	  $field->{NAME} eq 'EC' ||
  # 	  $field->{NAME} eq 'RUNID' ||
  # 	  $field->{NAME} eq 'LEVEL') {
  # 	$value = $aggregates->{$runid}{$level}->get($field->{NAME});
  #     }
  #     else {
  # 	$value = $aggregates->{$runid}{$level}->getmean($field->{NAME});
  #     }
  #     $value = 'ALL-macro' if $value eq 'ALL' && $field->{NAME} eq 'EC';
  #     my $text = sprintf($field->{MEAN_FORMAT} || $field->{FORMAT}, $value);
  #     $text = "" if 
  # 	print $program_output $text, ' ' x ($field->{WIDTH} - length($text)), ' ';
  #   }
  #   print $program_output "\n";
  # }
### DO INCLUDE
}

$logger->close_error_output();

################################################################################
# Revision History
################################################################################

# 2.1 - Initial version of scorer for 2015
# 2.0 - Rewrite to operate off of ground truth tree
# 1.1 - Merged with Shahzad's pseudoslot scoring; added fuzzy match hooks
# 1.0 - Initial version

1;
