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
# This program creates some LDC level scores for SF level scores for Cold Start 2015 
# submissions. These scores includes max, random, and mean.
#
# Authors: Shahzad Rajput
# Please send questions or comments to shahzadrajput "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.2";

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

sub projectRANDOM {
	my ($scores, $index, $evaluation_queries, $mapping_file, $logger) = @_;
	my @scores = @{$scores};
	my %index = %{$index};
	my %evaluation_queries = %{$evaluation_queries};
	my %sample_mapping;
	open(my $infile, "<:utf8", $mapping_file) or $logger->NIST_die("Could not open $mapping_file: $!");;
	while(<$infile>){
		chomp;
		my ($csldc_queryid, $cssf_queryid) = split;
		$sample_mapping{$csldc_queryid} = $cssf_queryid;
	}
	close($infile);
	my @new_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my $csldc_queryid = $index{$cssf_queryid};
	  my $csldc_query_ec = "$csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  $scores->{EC} = $csldc_query_ec;
	  next if $sample_mapping{$csldc_queryid} ne $cssf_queryid;
	  push(@new_scores, $scores) 
	  	if( (scalar keys %evaluation_queries > 0 && exists $evaluation_queries{$csldc_queryid})
	  		|| scalar keys %evaluation_queries == 0);
	}

	@new_scores;
}

sub projectMEAN {
	my ($scores, $index, $evaluation_queries) = @_;
	my @scores = @{$scores};
	my %index = %{$index};
	my %evaluation_queries = %{$evaluation_queries};
	my %new_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my $csldc_queryid = $index{$cssf_queryid};
	  my $csldc_query_ec = "$csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  
	  $new_scores{$csldc_query_ec}{$cssf_query_ec} = $scores 
	  	if( (scalar keys %evaluation_queries > 0 && exists $evaluation_queries{$csldc_queryid})
	  		|| scalar keys %evaluation_queries == 0);
	}

	my @combined_scores;
	foreach my $csldc_query_ec(sort keys %new_scores) {
	  my $combined_scores = Score->new;
	  my $i = 0;
	  foreach my $cssf_query_ec(keys %{$new_scores{$csldc_query_ec}}) {
	  	my $scores = $new_scores{$csldc_query_ec}{$cssf_query_ec};
   	    if(not exists $combined_scores->{EC}) {
  	  	  $combined_scores->put('EC', $csldc_query_ec);
  	  	  $combined_scores->put('RUNID', $scores->get('RUNID'));
  	  	  $combined_scores->put('LEVEL', $scores->get('LEVEL'));
  	  	  $combined_scores->put('NUM_GROUND_TRUTH', $scores->get('NUM_GROUND_TRUTH'));
  	  	  $combined_scores->put('NUM_CORRECT', "");
  	  	  $combined_scores->put('NUM_WRONG', "");
  	  	  $combined_scores->put('NUM_REDUNDANT', "");
  	  	  $combined_scores->put('PRECISION', "");
  	  	  $combined_scores->put('RECALL', "");	  	  	
  	  	  $combined_scores->put('F1', $scores->get('F1'));
  	    }
  	    else{
  	  	  my $f1 = $combined_scores->get('F1');
  	  	  $combined_scores->put('F1', $f1 + $scores->get('F1'));  	  	
  	    }
  	    $i++;
	  }
	  my $f1 = $combined_scores->get('F1');
	  $combined_scores->put('F1', $f1/$i);
	  	
	  push(@combined_scores, $combined_scores);
	}
	@combined_scores;
}


sub projectMAX {
	my ($scores, $index, $evaluation_queries) = @_;
	my @scores = @{$scores};
	my %index = %{$index};
	my %evaluation_queries = %{$evaluation_queries};
	# Get the max as the new score for the main query
	my %new_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my $csldc_queryid = $index{$cssf_queryid};
	  my $csldc_query_ec = "$csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  
	  push(@{$new_scores{$csldc_queryid}{$cssf_queryid}}, $scores) 
	  	if( (scalar keys %evaluation_queries > 0 && exists $evaluation_queries{$csldc_queryid})
	  		|| scalar keys %evaluation_queries == 0);
	}
	
	my %F1;
	foreach my $csldc_queryid(sort keys %new_scores) {
	  foreach my $cssf_queryid(keys %{$new_scores{$csldc_queryid}}) {
	  	my $combined_scores = Score->new;
	  	foreach my $scores(@{$new_scores{$csldc_queryid}{$cssf_queryid}}){
	  	  if(not exists $combined_scores->{EC}) {
	  	  	my $name = $scores->get('EC');
	  	  	$name =~ s/:.*?$//;
	  	  	$combined_scores->put('EC', $name);
	  	  	$combined_scores->put('RUNID', $scores->get('RUNID'));
	  	  	$combined_scores->put('LEVEL', 'ALL');
	  	  	$combined_scores->put('NUM_GROUND_TRUTH', $scores->get('NUM_GROUND_TRUTH'));
	  	  	$combined_scores->put('NUM_CORRECT', $scores->get('NUM_CORRECT'));
	  	  	$combined_scores->put('NUM_WRONG', $scores->get('NUM_WRONG'));
	  	  	$combined_scores->put('NUM_REDUNDANT', $scores->get('NUM_REDUNDANT'));
	  	  }
	  	  else{
	  	  	my $num_ground_truth = $combined_scores->get('NUM_GROUND_TRUTH');
	  	  	my $num_correct = $combined_scores->get('NUM_CORRECT');
	  	  	my $num_wrong = $combined_scores->get('NUM_WRONG');
	  	  	my $num_redundant = $combined_scores->get('NUM_REDUNDANT');
	  	  	$combined_scores->put('NUM_GROUND_TRUTH', $num_ground_truth + $scores->get('NUM_GROUND_TRUTH'));
	  	  	$combined_scores->put('NUM_CORRECT', $num_correct + $scores->get('NUM_CORRECT'));
	  	  	$combined_scores->put('NUM_WRONG', $num_wrong + $scores->get('NUM_WRONG'));
	  	  	$combined_scores->put('NUM_REDUNDANT', $num_redundant + $scores->get('NUM_REDUNDANT'));  	  	
	  	  }
	  	}
	  	if(not exists $F1{$csldc_queryid}) {
	  	  $F1{$csldc_queryid} = {QUERYID=>$cssf_queryid, F1=>$combined_scores->get('F1')};
	  	}
	  	else {
	  	  if($F1{$csldc_queryid}{F1} < $combined_scores->get('F1')) {
	  	  	$F1{$csldc_queryid} = {QUERYID=>$cssf_queryid, F1=>$combined_scores->get('F1')};
	  	  }
	  	}	
	  }
	}
	
	my @filtered_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my $csldc_queryid = $index{$cssf_queryid};
	  my $csldc_query_ec = "$csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  next if( not( (scalar keys %evaluation_queries > 0  && exists $evaluation_queries{$csldc_queryid})
	  		|| not scalar keys %evaluation_queries > 0 ) );
	  next if $F1{$csldc_queryid}{QUERYID} ne $cssf_queryid;
	  $scores->{EC} = $csldc_query_ec;
	  push(@filtered_scores, $scores);
	}
	
	@filtered_scores;
}

my %scoring_options = (
  MAX => {DESCRIPTION => "Pick the highest scoring entrypoint",
	  },
  RANDOM => {DESCRIPTION => "Pick a random entrypoint",
	  },
  MEAN => {DESCRIPTION => "Pick the mean across all entrypoints",
	  },
);

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Score one TAC Cold Start runs");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);

$switches->addVarSwitch('output_file', "Where should program output be sent? (filename, stdout or stderr)");
$switches->put('output_file', 'stdout');
$switches->addVarSwitch("error_file", "Where should error output be sent? (filename, stdout or stderr)");
$switches->put("error_file", "stdout");
$switches->addConstantSwitch("tabs", "true", "Use tabs to separate output fields instead of spaces");
$switches->addVarSwitch('queries', "File containing list of LDC queryids that should be reported in the evaluation");
$switches->addVarSwitch('score', "Specify scoring option. Legal values are: " . join(", ", map {"$_ ($scoring_options{$_}{DESCRIPTION})"} sort keys %scoring_options) . ".");
$switches->put("score", "MAX");
$switches->addVarSwitch('mapping', "File containing one SF queryid mapped to an LDC queryid. This option is required when using the random scoring option.");
$switches->addParam("index_file", "required", "Filename which contains mapping from output query name to original LDC query name");
$switches->addParam("score_file", "required", "CSSF Score file to be converted");

$switches->process(@ARGV);

my $logger = Logger->new();

my $scoring_option = uc $switches->get("score");
$logger->NIST_die("Unknown scoring option: $scoring_option (known options are [" . join(", ", keys %scoring_options) . "]")
  unless defined $scoring_options{$scoring_option};

my $mapping_file = $switches->get("mapping");
$logger->NIST_die("-mapping switch parameter required when using random scoring option.") 
  if ((not defined $mapping_file) && ($scoring_option eq "RANDOM"));

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

my $use_tabs = $switches->get("tabs");

my $evaluation_queries = $switches->get("queries");
my %evaluation_queries;

# Load evaluation queries
if($evaluation_queries) {
	my $input;
	open($input, "<:utf8", $evaluation_queries) or $logger->NIST_die("Could not open $evaluation_queries: $!");
	while(<$input>){
		chomp;
		$evaluation_queries{$_}++;
	}
	close($input);
}

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

my @scores;
my $cssf_score_file = $switches->get("score_file");
open(my $infile, "<:utf8", $cssf_score_file) or $logger->NIST_die("Could not open $cssf_score_file: $!");
<$infile>;
while(<$infile>) {
  chomp;
  my @elements = split(/\s+/);
  my ($name, $runid, $level, $num_ground_truth, $num_correct, $num_wrong, $num_redundant) = @elements;
  $num_wrong -= $num_redundant;
  next if($name =~ /ALL/);
  my $score = Score->new();
  $score->put('EC', $name);
  $score->put('RUNID', $runid);
  $score->put('LEVEL', $level);
  $score->put('NUM_GROUND_TRUTH', $num_ground_truth);
  $score->put('NUM_CORRECT', $num_correct);
  $score->put('NUM_WRONG', $num_wrong);
  $score->put('NUM_REDUNDANT', $num_redundant);
  push(@scores, $score);
}

# Pick the highest scoring entrypoint
if($scoring_option eq "MAX") {
  @scores = projectMAX(\@scores, \%index, \%evaluation_queries);
}
elsif($scoring_option eq "RANDOM") {
  @scores = projectRANDOM(\@scores, \%index, \%evaluation_queries, $mapping_file, $logger);
}
elsif($scoring_option eq "MEAN") {
  @scores = projectMEAN(\@scores, \%index, \%evaluation_queries);
}

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;

package ScoresPrinter;

my @fields_to_print = (
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
  my ($self, $score, $scoring_option) = @_;
  my %elements_to_print;
  my %fields_to_print = map {$_=>1} qw(QUERY_ID EC RUNID LEVEL F1);
  foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
  	next if ($scoring_option eq "MEAN" && not exists $fields_to_print{$field->{NAME}}); 
    my $text = sprintf($field->{FORMAT}, $score->get($field->{NAME}));
    $elements_to_print{$field->{NAME}} = $text;
    $self->{WIDTHS}{$field->{NAME}} = length($text) if length($text) > $self->{WIDTHS}{$field->{NAME}};
  }
  push(@{$self->{LINES}}, \%elements_to_print);
}

sub print_line {
  my ($self, $line, $scoring_option) = @_;
  my %fields_to_print = map {$_=>1} qw(QUERY_ID EC RUNID LEVEL F1);
  my $separator = "";
  foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
	next if ($scoring_option eq "MEAN" && not exists $fields_to_print{$field->{NAME}});  	
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
  my ($self, $scoring_option) = @_;
  if(scalar @{$self->{LINES}} > 0) {
  	$self->print_line(undef, $scoring_option);
  }
}

sub print_lines {
  my ($self, $scoring_option) = @_;
  foreach my $line (@{$self->{LINES}}) {
    $self->print_line($line, $scoring_option);
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

# Keep aggregate scores for regular slots
my $aggregates = {};
my $scores_printer = ScoresPrinter->new($use_tabs ? "\t" : undef);
my $runid;
foreach my $scores (sort compare_ec_names @scores) {
  $scores_printer->add_score($scores, $scoring_option);
  $runid = $scores->{RUNID} unless $runid;
  &aggregate_score($aggregates, $runid, $scores->{LEVEL}, $scores);
  &aggregate_score($aggregates, $runid, 'ALL',            $scores);
}

if($scoring_option ne "MEAN") {
	if(not defined $runid){
		print "Missing run-id in $cssf_score_file\n";
	}
	else {
		# Only report on hops that are present in the run
		foreach my $level (sort keys %{$aggregates->{$runid}}) {
		  # Print the micro-averaged scores
		  $scores_printer->add_score($aggregates->{$runid}{$level}, $scoring_option);
		}
	}
}

$scores_printer->print_headers($scoring_option);
$scores_printer->print_lines($scoring_option);

my %macro_fields = map {$_=>1} qw(QUERY_ID EC RUNID LEVEL F1);
foreach my $level (sort keys %{$aggregates->{$runid}}) {
# Print the macro-averaged scores
my $separator = "";
foreach my $field (@fields_to_print) {
	next if ($scoring_option eq "MEAN" && not exists $macro_fields{$field->{NAME}});
	my $value;
	if ($field->{NAME} eq 'QUERY_ID' ||
	  $field->{NAME} eq 'EC' ||
	  $field->{NAME} eq 'RUNID' ||
	  $field->{NAME} eq 'LEVEL') {
	$value = $aggregates->{$runid}{$level}->get($field->{NAME});
	  }
	  else {
	  	$value = "";
		$value = sprintf($field->{FORMAT}, $aggregates->{$runid}{$level}->getadjustedmean($field->{NAME}))
			if exists $macro_fields{$field->{NAME}};
	  }
	  $value = 'ALL-Macro' if $value eq 'ALL-Micro' && $field->{NAME} eq 'EC';
	  print $program_output $separator;
      my $numspaces = defined $scores_printer->{SEPARATOR} ? 0 : $scores_printer->{WIDTHS}{$field->{NAME}} - length($value);
      print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'R' && !defined $scores_printer->{SEPARATOR};
      print $program_output $value;
      print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'L' && !defined $scores_printer->{SEPARATOR};
      $separator = defined $scores_printer->{SEPARATOR} ? $scores_printer->{SEPARATOR} : ' ';
	}
  print $program_output "\n";
}

$logger->close_error_output();

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Adding support for producing random, and mean scores. This is in 
#       addition to max scores. Also adding the support for producing micro, and  
#       macro averages. 
# 1.2 - Macro average denominator fixed. Only true non-nils being counted.  
1;
