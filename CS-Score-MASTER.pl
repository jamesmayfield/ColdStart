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

### DO NOT INCLUDE
# Shahzad: I have not upped any version numbers. We should up them all just prior to
# the release of the new code
### DO INCLUDE
my $version = "2.4.4";

# Filehandles for program and error output
my $program_output;
my $error_output;

# The default sequence of output fields
### DO NOT INCLUDE
# Shahzad: I've omitted some of our agreed upon default fields just to get it working.
# Something like the following is what we had discussed:
#my $default_fields = "EC:GT:CORRECT:INCORRECT:INEXACT:RIGHT:WRONG:REDUNDANT:IGNORED:P:R:F";
### DO INCLUDE
my $default_fields = "EC:RUNID:LEVEL:GT:SUBMITTED:CORRECT:INCORRECT:INEXACT:INCORRECT_PARENT:UNASSESSED:REDUNDANT:RIGHT:WRONG:IGNORED:P:R:F";
my $default_right = "CORRECT";
my $default_wrong = "INCORRECT:INCORRECT_PARENT:INEXACT:DUPLICATE";
my $default_ignore = "UNASSESSED";

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
# Hush up perl worrywart module. FIXME: Not sure this is still needed.
my $pattern = $main::comment_pattern;
### DO INCLUDE

package ScoresPrinter;

# This package converts scoring output to printable form.

### DO NOT INCLUDE
# Shahzad: the FNs in the following need to be kept in sync with the output of
# EvaluationQueryOutput::score_query(). Either the FIXMEs need to be replaced
# with the appropriate field name, or if we can calculate the value from that
# output, FN needs to do the calculation and return the appropriate string.
### DO INCLUDE
my %printable_fields = (
  EC => {
  	NAME => 'EC',
    DESCRIPTION => "Query or equivalence class name",
    HEADER => 'QID/EC',
    FORMAT => '%s',
    JUSTIFY => 'L',
    FN => sub { $_[0]{EC} },
  },
  RUNID => {
  	NAME => 'RUNID',
    DESCRIPTION => "Run ID",
    HEADER => 'Run ID',
    FORMAT => '%s',
    JUSTIFY => 'L',
    FN => sub { $_[0]{RUNID} },
  },
  LEVEL => {
  	NAME => 'LEVEL',
    DESCRIPTION => "Hop level",
    HEADER => 'Hop',
    FORMAT => '%s',
    JUSTIFY => 'L',
    FN => sub { $_[0]{LEVEL} },
  },
  GT => {
  	NAME => 'NUM_GROUND_TRUTH',
    DESCRIPTION => "Number of ground truth values",
    HEADER => 'GT',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_GROUND_TRUTH} },
  },
  CORRECT => {
  	NAME => 'NUM_CORRECT_PRE_POLICY',
    DESCRIPTION => "Number of assessed correct submissions (pre-policy)",
    HEADER => 'Correct',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_CORRECT} },
  },
  INCORRECT => {
  	NAME => 'NUM_INCORRECT_PRE_POLICY',
    DESCRIPTION => "Number of assessed incorrect submissions (pre-policy)",
    HEADER => 'Incorrect',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_INCORRECT} },
  },
  INEXACT => {
  	NAME => 'NUM_INEXACT_PRE_POLICY',
    DESCRIPTION => "Number of assessed inexact submissions (pre-policy)",
    HEADER => 'Inexact',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_INEXACT} },
  },
  REDUNDANT => {
  	NAME => 'NUM_REDUNDANT_POST_POLICY',
    DESCRIPTION => "Number of duplicate submitted values in equivalence clase (post-policy)",
    HEADER => 'Dup',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_REDUNDANT} },
  },
  RIGHT => {
  	NAME => 'NUM_CORRECT_POST_POLICY',
    DESCRIPTION => "Number of submitted values counted as right (post-policy)",
    HEADER => 'Right',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_RIGHT} },
  },
  WRONG => {
  	NAME => 'NUM_INCORRECT_POST_POLICY',
    DESCRIPTION => "Number of submitted values counted as wrong (post-policy)",
    HEADER => 'Wrong',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    FN => sub { $_[0]{NUM_WRONG} },
  },
  IGNORED => {
  	NAME => 'NUM_IGNORED_POST_POLICY',
    HEADER => 'Ignored',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',
    DESCRIPTION => "Number of submissions that were ignored (post-policy)",
    FN => sub { $_[0]{NUM_IGNORED} },
  },
  SUBMITTED => {
  	NAME => 'NUM_SUBMITTED',
    DESCRIPTION => "Total number of submitted entries",
    HEADER => 'Submitted',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',   
    FN => sub { $_[0]{NUM_SUBMITTED} },
  },
  UNASSESSED => {
  	NAME => 'NUM_UNASSESSED',
    DESCRIPTION => "Total number of unassessed submitted entries",
    HEADER => 'Unassessed',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',   
    FN => sub { $_[0]{NUM_UNASSESSED} },
  },
  INCORRECT_PARENT => {
  	NAME => 'INCORRECT_PARENT',
    DESCRIPTION => "Total number of submitted entries with parents incorrect",
    HEADER => 'PIncorrect',
    FORMAT => '%4d',
    JUSTIFY => 'R',
    MEAN_FORMAT => '%4.2f',   
    FN => sub { $_[0]{NUM_INCORRECT_PARENT} },
  },
  P => {
  	NAME => 'PRECISION',
    DESCRIPTION => "Precision",
    HEADER => 'Prec',
    FORMAT => '%6.4f',
    JUSTIFY => 'L',
    FN => sub { $_[0]->get('PRECISION') },
  },
  R => {
  	NAME => 'RECALL',
    DESCRIPTION => "Recall",
    HEADER => 'Recall',
    FORMAT => '%6.4f',
    JUSTIFY => 'L',
    FN => sub { $_[0]->get('RECALL') },
  },
  F => {
  	NAME => 'F1',
    DESCRIPTION => "F1 = 2PR/(P+R)",
    HEADER => 'F1',
    FORMAT => '%6.4f',
    JUSTIFY => 'L',
    FN => sub { $_[0]->get('F1') },
  },
);

my %policy_options = (
  CORRECT => {
  	NAME => 'CORRECT',
    DESCRIPTION => "Number of assessed correct submissions. Legal choice for -right.",
    VALUE_MAP => 'NUM_CORRECT',
    CHOICES => [qw(RIGHT)],
  },
  DUPLICATE=> {
  	NAME => 'DUPLICATE',
    DESCRIPTION => "Number of duplicate submissions. Legal choice for -right, -wrong and -ignore.",
    VALUE_MAP => 'NUM_IGNORED',
    CHOICES => [qw(RIGHT WRONG IGNORE)],
  },
  INCORRECT => {
  	NAME => 'INCORRECT',
    DESCRIPTION => "Number of assessed incorrect submissions. Legal choice for -wrong.",
    VALUE_MAP => 'NUM_INCORRECT',
    CHOICES => [qw(WRONG)],
  },
  INCORRECT_PARENT => {
  	NAME => 'INCORRECT_PARENT',
    DESCRIPTION => "Number of submissions that had incrorrect (grand-)parent. Legal choice for -wrong and -ignore.",
    VALUE_MAP => 'NUM_INCORRECT_PARENT',
    CHOICES => [qw(WRONG IGNORE)],
  },
  INEXACT => {
  	NAME => 'INEXACT',
    DESCRIPTION => "Number of assessed inexact submissions. Legal choice for -right, -wrong and -ignore.",
    VALUE_MAP => 'NUM_INEXACT',
    CHOICES => [qw(RIGHT WRONG IGNORE)],
  },
  UNASSESSED=> {
  	NAME => 'UNASSESSED',
    DESCRIPTION => "Number of unassessed submissions. Legal choice for -wrong and -ignore.",
    VALUE_MAP => 'NUM_UNASSESSED',
    CHOICES => [qw(WRONG IGNORE)],
  },
);

my %metrices = (
  SF => {
  	ORDER => 1,
  	NAME => "SF",
  	DESCRIPTION => "SF: Slot-filling score variant considering all entrypoints as a separate query",
  	AGGREGATES => [qw(MICRO MACRO)],
  },
  LDCMAX => {
  	ORDER => 2,
  	NAME => "LDC-MAX",
  	DESCRIPTION => "LDC-MAX: LDC level score variant considering the run's best entrypoint per LDC query",
  	AGGREGATES => [qw(MICRO MACRO)],
  },
  LDCMEAN => {
  	ORDER => 3,
  	NAME => "LDC-MEAN",
  	DESCRIPTION => "LDC-MEAN: LDC level score variant considering averaging scores for all coressponding entrypoints",
  	AGGREGATES => [qw(MACRO)],
  },
);

sub get_fields_to_print {
  my ($spec, $logger) = @_;
  [map {$printable_fields{$_} || $logger->NIST_die("Unknown field: $_")} split(/:/, $spec)];
}

sub new {
  my ($class, $separator, $queries, $runid, $index, $queries_to_score, $spec, $verbose, $logger) = @_;
  my $fields_to_print = &get_fields_to_print($spec, $logger);
  my $ldc_mean_spec = "EC:RUNID:LEVEL:F";
  my $ldc_mean_fields_to_print = &get_fields_to_print($ldc_mean_spec, $logger);
  my $self = {RUNID => $runid,
  	      INDEX => $index,
  	      QUERIES => $queries,
  	      QUERIES_TO_SCORE => $queries_to_score,
  	      FIELDS_TO_PRINT => $fields_to_print,
  	      LDC_MEAN_FIELDS_TO_PRINT => $ldc_mean_fields_to_print,
	      WIDTHS => {map {$_->{NAME} => length($_->{HEADER})} @{$fields_to_print}},
	      HEADERS => [map {$_->{HEADER}} @{$fields_to_print}],
	      LINES => [],
	      VERBOSE => $verbose,
	     };
  $self->{SEPARATOR} = $separator if defined $separator;
  bless($self, $class);
  $self;
}

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

sub add_scores {
	my ($self, @scores) = @_;
	
	push(@{$self->{SCORES}}, @scores);
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
    eval(join(" || ", map {$a[$_] <=> $b[$_]} 0..&main::min($#a, $#b))) ||
    scalar @a <=> scalar @b;
}

sub get_line {
  my ($self, $score) = @_;
  my %line;
  foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
    my $value = &{$field->{FN}}($score);
    # FIXME: Is this always the appropriate default value?
    $value = 0 unless defined $value;
    my $text = sprintf($field->{FORMAT}, $value);
    $line{$field->{NAME}} = $text;
    $self->{WIDTHS}{$field->{NAME}} = length($text) if length($text) > $self->{WIDTHS}{$field->{NAME}};
  }
#  push(@{$self->{LINES}}, \%line);
  $self->{CATEGORIZED_SUBMISSIONS}{$score->{EC}} = $score->{CATEGORIZED_SUBMISSIONS}
  	if($score->{CATEGORIZED_SUBMISSIONS});
  %line;
}

sub print_line {
  my ($self, $line, $fields, $metric_name) = @_;
  my $separator = "";
  $fields = $self->{FIELDS_TO_PRINT} unless $fields;
  foreach my $field (@{$fields}) {
    my $value = (defined $line ? $line->{$field->{NAME}} : $field->{HEADER});
    $value = "$metric_name-$value" if $field->{NAME} eq "EC" && $metric_name;
    print $program_output $separator;
    my $numspaces = defined $self->{SEPARATOR} ? 0 : $self->{WIDTHS}{$field->{NAME}} - length($value);
    print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'R' && !defined $self->{SEPARATOR};
    print $program_output $value;
    print $program_output ' ' x $numspaces if $field->{JUSTIFY} eq 'L' && !defined $self->{SEPARATOR};
  	$separator = defined $self->{SEPARATOR} ? $self->{SEPARATOR} : ' ';
  }
  print $program_output "\n";
}

sub add_micro_average {
  my ($self, $metric, @scores) = @_;
  my $aggregates = {};	
  foreach my $score(sort compare_ec_names @scores ) {
  	&aggregate_score($aggregates, $score->{RUNID}, $score->{LEVEL}, $score);
  	&aggregate_score($aggregates, $score->{RUNID}, 'ALL', $score);
  }
  foreach my $level (sort keys %{$aggregates->{$self->{RUNID}}}) {
  	my %line = $self->get_line($aggregates->{$self->{RUNID}}{$level});
  	push(@{$self->{LINES}}, \%line);
  	push(@{$self->{SUMMARY}{$metric}}, \%line);
  }
}

sub add_macro_average {
  my ($self, $metric, @scores) = @_;
  my $aggregates = {};
  foreach my $score(sort compare_ec_names @scores ) {
  	&aggregate_score($aggregates, $score->{RUNID}, $score->{LEVEL}, $score);
  	&aggregate_score($aggregates, $score->{RUNID}, 'ALL', $score);
  }
  foreach my $level (sort keys %{$aggregates->{$self->{RUNID}}}) {
  	# Print the macro-averaged scores
  	my %line;
  	foreach my $field (@{$self->{FIELDS_TO_PRINT}}) {
  	  my $value = "";
  	  if ($field->{NAME} eq 'QUERY_ID' ||
  	  	$field->{NAME} eq 'EC' ||
		$field->{NAME} eq 'RUNID' ||
		$field->{NAME} eq 'LEVEL') {
		  $value = $aggregates->{$self->{RUNID}}{$level}->get($field->{NAME});
	  }
	  elsif ($field->{NAME} eq 'F1') {
	  	$value = $aggregates->{$self->{RUNID}}{$level}->getadjustedmean($field->{NAME});
	  }
	  $value = 'ALL-Macro' if $value eq 'ALL-Micro' && $field->{NAME} eq 'EC';
	  my $format = $field->{FORMAT};
	  $format =~ s/[df]/s/ if $value eq "";
	  my $text = sprintf($format, $value);
	  $line{$field->{NAME}} = $text;
	  $self->{WIDTHS}{$field->{NAME}} = length($text) if length($text) > $self->{WIDTHS}{$field->{NAME}};
  	}
  	push(@{$self->{LINES}}, \%line);
  	push(@{$self->{SUMMARY}{$metric}}, \%line);
  }
}

sub projectLDCMEAN {
	my ($self) = @_;
	my %index = %{$self->{INDEX}};
	my @scores = @{$self->{SCORES}};
	my %evaluation_queries = map {$_=>1} keys %{$self->{QUERIES_TO_SCORE}};
	my %new_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($full_cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my ($query_id_base, $cssf_queryid, $level, $expanded) 
  		= &Query::parse_queryid($full_cssf_queryid);  
	  my $csldc_queryid = $index{$cssf_queryid};
	  my $full_csldc_queryid = $self->{QUERIES}->get_full_queryid($index{$cssf_queryid});
	  my $csldc_query_ec = "$full_csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  
	  $new_scores{$csldc_query_ec}{$cssf_query_ec} = $scores 
	  	if( (scalar keys %evaluation_queries > 0 && exists $evaluation_queries{$cssf_queryid})
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

sub projectLDCMAX {
	my ($self) = @_;
	my %index = %{$self->{INDEX}};
	my @scores = @{$self->{SCORES}};
	my %evaluation_queries = map {$_=>1} keys %{$self->{QUERIES_TO_SCORE}};
	# Get the max as the new score for the main query
	my %new_scores;
	foreach my $scores(@scores){
	  my $cssf_query_ec = $scores->{EC};
	  my ($full_cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my ($query_id_base, $cssf_queryid, $level, $expanded) 
  		= &Query::parse_queryid($full_cssf_queryid);  
	  my $csldc_queryid = $index{$cssf_queryid};
	  	  
	  my $csldc_query_ec = "$csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  
	  push(@{$new_scores{$csldc_queryid}{$cssf_queryid}}, $scores) 
	  	if( (scalar keys %evaluation_queries > 0 && exists $evaluation_queries{$cssf_queryid})
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
	  	  	foreach my $key( grep {$_ =~ /^NUM_/} keys %{$scores} ) { 
	  	  	  $combined_scores->put($key, $scores->get($key));
	  	  	}
	  	  }
	  	  else{
	  	  	foreach my $key( grep {$_ =~ /^NUM_/} keys %{$scores} ) { 
	  	  	  $combined_scores->put($key, $combined_scores->get($key) + $scores->get($key));
	  	  	}
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
	foreach my $original_scores(@scores){
	  my $scores = $original_scores->duplicate("CATEGORIZED_SUBMISSIONS");
	  my $cssf_query_ec = $scores->{EC};
	  my ($full_cssf_queryid, $cssf_ec) = split(":", $cssf_query_ec);
	  my ($query_id_base, $cssf_queryid, $level, $expanded) 
  		= &Query::parse_queryid($full_cssf_queryid);  
  	  my $csldc_queryid = $index{$cssf_queryid};
	  my $full_csldc_queryid = $self->{QUERIES}->get_full_queryid($index{$cssf_queryid});
	  my $csldc_query_ec = "$full_csldc_queryid";
	  $csldc_query_ec .= ":$cssf_ec" if(defined $cssf_ec);
	  next if( not( (scalar keys %evaluation_queries > 0  && exists $evaluation_queries{$cssf_queryid})
	  		|| not scalar keys %evaluation_queries > 0 ) );
	  next if $F1{$csldc_queryid}{QUERYID} ne $cssf_queryid;
	  $scores->{EC} = $csldc_query_ec;
	  push(@filtered_scores, $scores);
	}
	
	@filtered_scores;
}


sub get_projected_scores {
  my ($self, $metric) = @_;
  return $self->projectLDCMAX() if($metric eq "LDCMAX");
  return $self->projectLDCMEAN() if($metric eq "LDCMEAN");
}

sub prepare_lines {
  my ($self, $metric) = @_;
  my @scores = @{$self->{SCORES}};
  if($metric eq "LDCMAX" || $metric eq "LDCMEAN") {
  	@scores = $self->get_projected_scores($metric);
  }
  foreach my $score(sort compare_ec_names @scores) {
  	my %line = $self->get_line($score);
  	push(@{$self->{LINES}}, \%line);
  }
  $self->add_micro_average($metric, @scores) 
  	if(grep {$_ =~ /MICRO/} @{$metrices{$metric}{AGGREGATES}});
  $self->add_macro_average($metric, @scores)
  	if(grep {$_ =~ /MACRO/} @{$metrices{$metric}{AGGREGATES}});
}
  
sub print_headers {
  my ($self, @args) = @_;
  $self->print_line( undef, @args );
}

sub print_lines {
  my ($self) = @_;
  foreach my $metric(sort {$metrices{$a}{ORDER}<=>$metrices{$b}{ORDER}} keys %metrices) {
  	
  	# Skip over if the sf-queries file passed as argument
  	# This is determined by looking up keys in %{$self->{INDEX}}
  	# which stores a mapping between LDC and SF query ids
  	next if( (($metric eq "LDCMAX")||($metric eq "LDCMEAN")) && (scalar keys %{$self->{INDEX}} == 0) );
  	my $description = $metrices{$metric}{DESCRIPTION};
  	my $fields_to_print;
  	$fields_to_print = $self->{LDC_MEAN_FIELDS_TO_PRINT} 
  		if $metric eq "LDCMEAN"; 
	$self->prepare_lines($metric);
	$self->print_details() if $self->{VERBOSE} && $metric eq "SF";
  	print $program_output "$description\n\n";
	$self->print_headers($fields_to_print) if @{$self->{LINES}};
	foreach my $line (@{$self->{LINES}}) {
	  $self->print_line($line, $fields_to_print);
	}
	@{$self->{LINES}} = ();
	print $program_output "\n";
  }
  print $program_output "SUMMARY: Summary of scores\n\n";
  $self->print_summary();
}

sub print_details {
  my ($self) = @_;
  foreach my $ec (sort keys %{$self->{CATEGORIZED_SUBMISSIONS}}) {
  	my %summary;
  	foreach my $label(grep {$_ ne "SUBMITTED"} keys %{$self->{CATEGORIZED_SUBMISSIONS}{$ec}}) {
  		foreach my $submission(@{$self->{CATEGORIZED_SUBMISSIONS}{$ec}{$label}}) {
  			my $assessment = ($submission->{ASSESSMENT}) ? $submission->{ASSESSMENT}{ASSESSMENT} : "UNASSESSED";
  			my $assessment_line = ($submission->{ASSESSMENT}) ? $submission->{ASSESSMENT}{LINE} : "-";
  			if($assessment ne $label) {
	  			my $postpolicy_assessment = $label;
	  			unless ($summary{$submission->{LINENUM}}) {
		  			$summary{$submission->{LINENUM}} = {
		  						LINE => $submission->{LINE},
		  						ASSESSMENT_LINE => $assessment_line,
		  						PREPOLICY_ASSESSMENT => $assessment,
		  						POSTPOLICY_ASSESSMENT => [$label] ,
		  					};
	  			}
	  			else {
	  				push (@{$summary{$submission->{LINENUM}}{POSTPOLICY_ASSESSMENT}}, $label);
	  			}
  			}
  		}
  	}
		
	print $program_output "="x80, "\n";
	print $program_output "$ec\n";
	
	foreach my $line_num(sort {$a<=>$b} keys %summary) {
		print $program_output "\tSUBMISSION:\t", $summary{$line_num}{LINE}, "\n";
		print $program_output "\tASSESSMENT:\t", $summary{$line_num}{ASSESSMENT_LINE}, "\n\n";
		print $program_output "\tPREPOLICY ASSESSMENT:\t", $summary{$line_num}{PREPOLICY_ASSESSMENT}, "\n";
		print $program_output "\tPOSTPOLICY ASSESSMENT:\t", join(",", sort @{$summary{$line_num}{POSTPOLICY_ASSESSMENT}}), "\n";
		print $program_output "."x80, "\n";
	}
  }
  print $program_output "\n";
}

sub print_summary {
  my ($self) = @_;
  my $fields_to_print = $self->{LDC_MEAN_FIELDS_TO_PRINT};
  $self->print_headers($fields_to_print);
  foreach my $metric(sort {$metrices{$a}{ORDER}<=>$metrices{$b}{ORDER}} keys %metrices) {
  	my $metric_name = $metrices{$metric}{NAME};
    foreach my $line (@{$self->{SUMMARY}{$metric}}) {
      $self->print_line($line, $fields_to_print, $metric_name);
    }
  }
}

# Determine which queries should be scored
sub get_queries_to_score {
  my ($logger, $spec, $queries) = @_;
  my %query_slots;
  # Spec can be empty (meaning score all queries), a colon-separated
  # list of IDs, or a filename
  if (!defined $spec) {
    my @query_ids = $queries->get_all_top_level_query_ids();
    %query_slots = map {$_=>scalar @{$queries->get($_)->{SLOTS}}-1} @query_ids;
  }
  elsif (-f $spec) {
    open(my $infile, "<:utf8", $spec) or $logger->NIST_die("Could not open $spec: $!");
    my %index;
    while(<$infile>) {
    	chomp;
    	my ($csldc_query_id, $cssf_query_id_full, $num_slots) = split(/\s+/, $_);
    	if (not exists $index{$csldc_query_id}) {
    		$index{$csldc_query_id} = defined $num_slots ? $num_slots : -1; 
    	}
    	else {
    		my $target_value = defined $num_slots ? $num_slots : -1;
    		$logger->NIST_die("$csldc_query_id has multiple/conflicting num_slots in $spec")
    			if($target_value != $index{$csldc_query_id});
    	}
    	my ($base, $cssf_query_id) = &Query::parse_queryid($cssf_query_id_full);
    	unless ($queries->get($cssf_query_id)) {
		  $logger->record_problem('UNKNOWN_QUERY_ID_WARNING', $cssf_query_id, 'NO_SOURCE');
		  next;
    	}
    	my $max_num_slot = scalar @{$queries->get($cssf_query_id)->{SLOTS}}-1;
    	$num_slots = $max_num_slot unless defined $num_slots;
    	
    	$logger->NIST_die("Unexpected num_slots value $num_slots for $csldc_query_id in $spec")
    		if $num_slots > $max_num_slot || $num_slots < 0;
    	
    	$query_slots{$cssf_query_id} = $num_slots;
    }
    close $infile;
  }
  else {
    my @query_ids = split(/:/, $spec);
    foreach my $full_query_id(@query_ids) {
      my ($base, $query_id) = &Query::parse_queryid($full_query_id);
      unless ($queries->get($query_id)) {
      	$logger->record_problem('UNKNOWN_QUERY_ID_WARNING', $query_id, 'NO_SOURCE');
      	next;
      }
      my $num_slots = scalar @{$queries->get($query_id)->{SLOTS}}-1;
      $query_slots{$query_id} = $num_slots;
    }
  }
  my %query_ids_to_score;
  foreach my $query_id (keys %query_slots) {
    my $root = $queries->get_ancestor($query_id);
    my $num_slots = $query_slots{$query_id}; 
    $query_ids_to_score{$root->get("QUERY_ID")} = $num_slots unless @{$root->get("EXPANDED_QUERY_IDS")};
    # If we've requested an unexpanded query ID, we need to add each of the expanded queries
    foreach my $expanded_query_id (@{$root->get("EXPANDED_QUERY_IDS")}) {
      $num_slots = $query_slots{$expanded_query_id}; 
      $query_ids_to_score{$expanded_query_id} = $num_slots;
    }
  }
  %query_ids_to_score;
}

# Handle run-time switches
my $switches = SwitchProcessor->new($0,
   "Score one or more TAC Cold Start runs",
   "-discipline is one of the following:\n" . EvaluationQueryOutput::get_all_disciplines() .
## DO NOT INCLUDE
# Removing COMBO
#
#
#   "-combo is one of the following:\n" . EvaluationQueryOutput::get_combo_options_description() .
#
### DO INCLUDE
   "-fields is a colon-separated list drawn from the following:\n" . &main::build_documentation(\%printable_fields) .
   "policy options are a colon-separated list drawn from the following:\n" . &main::build_documentation(\%policy_options) .
   "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);

$switches->addVarSwitch('output_file', "Where should program output be sent? (filename, stdout or stderr)");
$switches->put('output_file', 'stdout');
$switches->addVarSwitch("error_file", "Where should error output be sent? (filename, stdout or stderr)");
$switches->put("error_file", "stderr");
$switches->addConstantSwitch("tabs", "true", "Use tabs to separate output fields instead of spaces (useful for export to spreadsheet)");
$switches->addConstantSwitch("verbose", "true", "Print verbose output");
$switches->addVarSwitch("discipline", "Discipline for identifying ground truth (see below for options)");
$switches->put("discipline", 'ASSESSED');
$switches->addVarSwitch("expand", "Expand multi-entrypoint queries, using string provided as base for expanded query names");
### DO NOT INCLUDE
# Removing COMBO
#
#
#$switches->addVarSwitch("combo", "How scores should be combined (see below for options)");
#$switches->put("combo", "MICRO");
#
### DO INCLUDE

$switches->addVarSwitch("queries", "file (one LDC query ID, SF query ID pair, separated by space, per line with an optional number separated " .
					 	"by space representing the hop upto which evaluation is to be performed) " .
					 	"or colon-separated list of SF query IDs to be scored " .
			           "(if omitted, all query files in 'files' parameter will be scored)");
$switches->addVarSwitch("runids", "Colon-separated list of run IDs to be scored (if omitted, all runids will be scored)");
$switches->addVarSwitch("right", "Colon-separated list of assessment codes, submitted value corresponding to which to be counted as right (post-policy) (see policy options below for legal choices)");
$switches->put("right", $default_right);
$switches->addVarSwitch("wrong", "Colon-separated list of assessment codes, submitted value corresponding to which to be counted as wrong (post-policy) (see policy options below for legal choices)");
$switches->put("wrong", $default_wrong);
$switches->addVarSwitch("ignore", "Colon-separated list of assessment codes, submitted value corresponding to which to be ignored (post-policy) (see policy options below for legal choices)");
$switches->put("ignore", $default_ignore);
$switches->addVarSwitch("fields", "Colon-separated list of output fields to print (see below for options)");
$switches->put("fields", $default_fields);
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
### DO NOT INCLUDE
# Shahzad: Which of thes switches do we want to keep?
#$switches->addConstantSwitch('showmissing', 'true', "Show missing assessments");
# $switches->addConstantSwitch('components', 'true', "Show component scores for each query");
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
## DO NOT INCLUDE
# Removing COMBO
#
#
#my $combo = $switches->get('combo');
#
### DO INCLUDE
my $query_base = $switches->get('expand');
my $verbose = $switches->get('verbose');
my %policy_selected = (
  RIGHT => $switches->get('right'),
  WRONG => $switches->get('wrong'),
  IGNORE => $switches->get('ignore'),
);

# Validate selected policy options
foreach my $option(sort keys %policy_selected) {
  my @choices = split(":", $policy_selected{$option});
  foreach my $choice(@choices) {
  	$logger->NIST_die("Unexpected choice $choice for $option")
  	  if(!grep {$_ eq $option} @{$policy_options{$choice}{CHOICES}});
  }
}

my @filenames = @{$switches->get("files")};
my @queryfilenames = grep {/\.xml$/} @filenames;
my @runfilenames = grep {!/\.xml$/} @filenames;
my $queries = QuerySet->new($logger, @queryfilenames);
$queries->expand($query_base) if $query_base;

my %index = $queries->get_index();

#print STDERR "Original queries\n  ", join("\n  ", $queries->get_original_query_ids()), "\n";
#print STDERR "Expanded queries\n  ", join("\n  ", $queries->get_expanded_query_ids()), "\n";
#print STDERR "All queries\n  ", join("\n  ", $queries->get_all_query_ids()), "\n";

my %queries_to_score = &get_queries_to_score($logger, $switches->get("queries"), $queries);

my $submissions_and_assessments = EvaluationQueryOutput->new($logger, $discipline, $queries, @runfilenames);

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;

package main;

sub score_runid {
  my ($runid, $submissions_and_assessments, $queries, $queries_to_score, $use_tabs, $spec, $verbose, $policy_options, $policy_selected, $logger) = @_;
  my $scores_printer = ScoresPrinter->new($use_tabs ? "\t" : undef, $queries, $runid, \%index, $queries_to_score, $spec, $verbose, $logger);
  # Score each query, printing the query-by-query scores
 foreach my $query_id (sort keys %{$queries_to_score}) {
#print STDERR "Processing query $query_id\n";
    my $query = $queries->get($query_id);
#print STDERR "query is undef\n" unless defined $query;
    # Get the scores just for this query in this run
    my @scores = $submissions_and_assessments->score_query($query, $policy_options, $policy_selected,
							   DISCIPLINE => $discipline,
							   RUNID => $runid,
							   QUERY_BASE => $query_base);
	foreach my $score(@scores) {
	  my $full_query_id = $score->{EC};
	  if($full_query_id =~ /^(.*?):/) {
	  	$full_query_id = $1;
	  }
	  my ($base, $query_id) = &Query::parse_queryid($full_query_id);
	 $scores_printer->add_scores($score) 
	 		if($score->{LEVEL} <= $queries_to_score->{$query_id});
	}
  }
  $scores_printer;
}

my $runids = $switches->get("runids");
my @runids = $runids ? split(/:/, $runids) : $submissions_and_assessments->get_all_runids();
my $spec = $switches->get("fields");

foreach my $runid (@runids) {
  my $scores_printer = &score_runid($runid, $submissions_and_assessments, $queries, \%queries_to_score, $use_tabs, $spec, $verbose, \%policy_options, \%policy_selected, $logger);
  $scores_printer->print_lines();
}

$logger->close_error_output();

################################################################################
# Revision History
################################################################################

# 2.4.4 - -queries file format changed. Additional mandatory first column added 
#		  containing CSLDC queryid corresponding to the CSSF queryid mentioned on 
#		  that line, required for sanity checking. 
# 2.4.3 - -queries file format changed. Allows one to add an additional column 
#         per query id specifying the hop number upto which evaluation is performed
# 2.4.2 - LDC-MEAN Macro-averaging over only NON-NIL queries
# 2.4.1 - Reporting LDC level scores
# 2.4 - Added support for specifying policy (-right, -wrong, and -ignore)
#     - Removed -combo because this is not needed and all variant should be 
#       reported as part of the output, presently only CSSF-Micro being reported
#     - queryid and full_queryid have been separated
#     - Verbose output can be seen using -verbose
#     - cleanup 
# 2.3.1 - Fixed a bug that gave a warning when hop-1 answers were not assessed 
#         because the parent was incorrect. The scores remain unchanged.
# 2.3 - small modifications to implement SPEEDUP
# 2.2 - Added -queries switch
# 2.1j - Added -combo
# 2.0 - Rewrite to operate off of ground truth tree
# 1.1 - Merged with Shahzad's pseudoslot scoring; added fuzzy match hooks
# 1.0 - Initial version

1;
