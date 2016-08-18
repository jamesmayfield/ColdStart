#!/usr/bin/perl

use warnings;
use strict;
use Carp;
use utf8;
use JSON;

binmode(STDOUT, ":utf8");

#####################################################################################
# This library handles a variety of tasks needed to process TAC Cold Start
# submissions.
#
# Authors: James Mayfield, Shahzad Rajput
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
### DO NOT INCLUDE
# FIXME: Use github issue tracking or something else?
### DO INCLUDE
#####################################################################################

my $version = "3.9";        # (1) An error is thrown when the "full" CSSF query ID in
                            #     the submission file is missing from the queries.xml
                            #     file, previously only the hash was compared and
                            #     any change in prefix but not the hash went
                            #     undetected.

### BEGIN INCLUDE Switches

# I don't know where this script will be run, so pick a reasonable
# screen width for describing program usage (with the -help switch)
my $terminalWidth = 80;

### END INCLUDE Switches
### BEGIN INCLUDE Logger

#####################################################################################
# Reporting Problems
#####################################################################################

# The following is the default list of problems that can be checked
# for. A different list of problems can be specified as an argument to
# Logger->new(). WARNINGs can be corrected and do not prevent further
# processing. ERRORs permit further error checking, but processing
# does not proceed after that. FATAL_ERRORs cause immediate program
# termination when the error is reported.

my $problem_formats = <<'END_PROBLEM_FORMATS';

# Error Name                   Type     Error Message
# ----------                   ----     -------------

########## Provenance Errors
  FAILED_LANG_INFERENCE         WARNING  Unable to infer language from DOCID %s. Using default language %s.
  ILLEGAL_DOCID                 ERROR    DOCID %s is not a valid DOCID for this task
  ILLEGAL_OFFSET                ERROR    %s is not a valid offset
  ILLEGAL_OFFSET_IN_DOC         ERROR    %s is not a valid offset for DOCID %s
  ILLEGAL_OFFSET_PAIR           ERROR    (%s, %s) is not a valid offset pair
  ILLEGAL_OFFSET_PAIR_STRING    ERROR    %s is not a valid offset pair string
  ILLEGAL_OFFSET_TRIPLE_STRING  ERROR    %s is not a valid docid/offset pair string
  TOO_MANY_PROVENANCE_TRIPLES   WARNING  Too many provenance triples (%d) provided; only the first %d will be used
  TOO_MANY_CHARS                WARNING  Provenance contains too many characters; only the first %d will be used
  TOO_MANY_TOTAL_CHARS          ERROR    All provenance strings contain a total of more than %d characters

########## Knowledge Base Errors
  AMBIGUOUS_PREDICATE           ERROR    %s: ambiguous predicate
  COLON_OMITTED                 WARNING  Initial colon omitted from name of entity %s
  DUPLICATE_ASSERTION           WARNING  The same assertion is made more than once (%s)
  ILLEGAL_CONFIDENCE_VALUE      ERROR    Illegal confidence value: %s
  IMPROPER_CONFIDENCE_VALUE     WARNING  Confidence value in scientific format: %s 
  ILLEGAL_ENTITY_NAME           ERROR    Illegal entity name: %s
  ILLEGAL_ENTITY_TYPE           ERROR    Illegal entity type: %s
  ILLEGAL_LINK_SPECIFICATION    WARNING  Illegal link specification: %s
  ILLEGAL_PREDICATE             ERROR    Illegal predicate: %s
  ILLEGAL_PREDICATE_TYPE        ERROR    Illegal predicate type: %s
  MISSING_CANONICAL             WARNING  Entity %s has no canonical mention in document %s
  MISSING_MENTION               WARNING  Entity %s has no mention in document %s
  # This is the WARNING version of ILLEGAL_CONFIDENCE_VALUE:
  MISSING_DECIMAL_POINT         WARNING  Decimal point missing in confidence value: %s
  MISSING_INVERSE               WARNING  No inverse relation asserted for %s(%s, %s)
  MISSING_RUNID                 ERROR    The first line of the file does not contain a legal runid
  MISSING_TYPEDEF               ERROR    No type asserted for Entity %s
  MULTIPLE_CANONICAL            ERROR    More than one canonical mention for Entity %s in document %s
  MULTIPLE_FILLS_ENTITY         WARNING  Entity %s has multiple %s fills, but should be single-valued
  MULTIPLE_LINKS                WARNING  More than one link from entity %s to KB %s
  MULTIPLE_MENTIONS_NO_CANONICAL ERROR   Entity %s has more than one named/nominal mention in document %s but has no canonical mention
  MULTITYPED_ENTITY             ERROR    Entity %s has more than one type: %s
  NO_MENTIONS                   WARNING  Entity %s has no mentions
  PREDICATE_ALIAS               WARNING  Use of %s predicate; %s replaced with %s
  STRING_USED_FOR_ENTITY        ERROR    Expecting an entity, but got string %s
  SUBJECT_PREDICATE_MISMATCH    ERROR    Type of subject (%s) does not match type of predicate (%s)
  UNASSERTED_MENTION            WARNING  Failed to assert that %s in document %s is also a mention
  UNATTESTED_RELATION_ENTITY    ERROR    Relation %s uses entity %s, but that entity id has no mentions in provenance %s
  UNQUOTED_STRING               WARNING  String %s not surrounded by double quotes
  UNKNOWN_TYPE                  ERROR    Cannot infer type for Entity %s

########## Query File Errors
  DUPLICATE_QUERY               WARNING  Queries %s and %s share entry point(s)
  DUPLICATE_QUERY_ID            WARNING  Duplicate query ID %s
  DUPLICATE_QUERY_FIELD         WARNING  Duplicate <%s> tag
  MALFORMED_QUERY               ERROR    Malformed query %s
  MISMATCHED_HOP_SUBTYPES       WARNING  In %s, range of %s does not match domain of %s
  MISMATCHED_HOP_TYPES          WARNING  In %s, type of %s does not match domain of %s
  MISMATCHED_TAGS               WARNING  <%s> tag closed with </%s>
  MISSING_QUERY_FIELD           ERROR    Missing <%s> tag in query %s
  NO_QUERIES_LOADED             WARNING  No queries found
  POSSIBLE_DUPLICATE_QUERY      WARNING  Queries %s and %s are possibly duplicates, based on entrypoint %s
  QUERY_WITHOUT_LOADED_PARENT   ERROR    Query %s has parent %s that was not loaded
  UNKNOWN_QUERY_FIELD           WARNING  <%s> is not a recognized query field
  UNLOADED_QUERY                WARNING  Query %s is not present in the query files; skipping it

########## Submission File/Assessment File Errors
  BAD_QUERY                     WARNING  Response for illegal query %s skipped
  EMPTY_FIELD                   WARNING  Empty value for column %s
  EMPTY_FILE                    WARNING  Empty response or assessment file: %s
  ILLEGAL_VALUE_TYPE            ERROR    Illegal value type: %s
  MISMATCHED_RUNID              WARNING  Round 1 uses runid %s but Round 2 uses runid %s; selecting the former
  MULTIPLE_CORRECT_GROUND_TRUTH WARNING  More than one correct choice for ground truth for query %s
  MULTIPLE_FILLS_SLOT           WARNING  Multiple responses given to single-valued slot %s
  MULTIPLE_RUNIDS               WARNING  File contains multiple run IDs (%s, %s)
  OFF_TASK_SLOT                 WARNING  %s slot is not valid for task %s
  UNKNOWN_QUERY_ID              ERROR    Unknown query: %s
  UNKNOWN_QUERY_ID_WARNING      WARNING  Unknown query: %s
  UNKNOWN_RESPONSE_FILE_TYPE    FATAL_ERROR  %s is not a known response file type
  UNKNOWN_SLOT_NAME             ERROR    Unknown slot name: %s
  WRONG_SLOT_NAME               WARNING  Slot %s is not the requested slot for query %s (expected %s)

########## Multi-Use Errors
  WRONG_NUM_ENTRIES             ERROR    Wrong number of entries on line (expected %d, got %d)

END_PROBLEM_FORMATS


#####################################################################################
# Logger
#####################################################################################

package Logger;

use Carp;

# Create a new Logger object
sub new {
  my ($class, $formats, $error_output) = @_;
  $formats = $problem_formats unless $formats;
  my $self = {FORMATS => {}, PROBLEMS => {}, PROBLEM_COUNTS => {}};
  bless($self, $class);
  $self->set_error_output($error_output);
  $self->add_formats($formats);
  $self;
}

# Add additional error formats to an existing Logger
sub add_formats {
  my ($self, $formats) = @_;
  # Convert the problem formats list to an appropriate hash
  chomp $formats;
  foreach (grep {/\S/} grep {!/^\S*#/} split(/\n/, $formats)) {
    s/^\s+//;
    my ($problem, $type, $format) = split(/\s+/, $_, 3);
    $self->{FORMATS}{$problem} = {TYPE => $type, FORMAT => $format};
  }
}

# Get a list of warnings that can be ignored through the -ignore switch
sub get_warning_names {
  my ($self) = @_;
  join(", ", grep {$self->{FORMATS}{$_}{TYPE} eq 'WARNING'} sort keys %{$self->{FORMATS}});
}

# Do not report warnings of the specified type
sub ignore_warning {
  my ($self, $warning) = @_;
  $self->NIST_die("Unknown warning: $warning") unless $self->{FORMATS}{$warning};
  $self->NIST_die("$warning is a fatal error; cannot ignore it") unless $self->{FORMATS}{$warning}{TYPE} eq 'WARNING';
  $self->{IGNORE_WARNINGS}{$warning}++;
}

# Just use the ignore_warning mechanism to delete errors, but don't enforce the warnings-only edict
sub delete_error {
  my ($self, $error) = @_;
  $self->NIST_die("Unknown error: $error") unless $self->{FORMATS}{$error};
  $self->{IGNORE_WARNINGS}{$error}++;
}

# Is a particular error being ignored?
sub is_ignored {
  my ($self, $warning) = @_;
  $self->NIST_die("Unknown error: $warning") unless $self->{FORMATS}{$warning};
  $self->{IGNORE_WARNINGS}{$warning};
}

# Remember that a particular problem was encountered, for later reporting
sub record_problem {
  my ($self, $problem, @args) = @_;
  my $source = pop(@args);
  # Warnings can be suppressed here; errors cannot
  return if $self->{IGNORE_WARNINGS}{$problem};
  my $format = $self->{FORMATS}{$problem} ||
               {TYPE => 'INTERNAL_ERROR',
		FORMAT => "Unknown problem $problem: %s"};
  $self->{PROBLEM_COUNTS}{$format->{TYPE}}++;
  my $type = $format->{TYPE};
  my $message = "$type: " . sprintf($format->{FORMAT}, @args);
  my $where = (ref $source ? "$source->{FILENAME} line $source->{LINENUM}" : $source);
  $self->NIST_die("$message$where") if $type eq 'FATAL_ERROR' || $type eq 'INTERNAL_ERROR';
  $self->{PROBLEMS}{$problem}{$message}{$where}++;
}

# Send error output to a particular file or file handle
sub set_error_output {
  my ($self, $output) = @_;
  if (!$output) {
    $output = *STDERR{IO};
  }
  elsif (!ref $output) {
    if (lc $output eq 'stdout') {
      $output = *STDOUT{IO};
    }
    elsif (lc $output eq 'stderr') {
      $output = *STDERR{IO};
    }
    else {
      $self->NIST_die("File $output already exists") if -e $output;
      open(my $outfile, ">:utf8", $output) or $self->NIST_die("Could not open $output: $!");
      $output = $outfile;
      $self->{OPENED_ERROR_OUTPUT} = 'true';
    }
  }
  $self->{ERROR_OUTPUT} = $output
}

# Retrieve the file handle for error output
sub get_error_output {
  my ($self) = @_;
  $self->{ERROR_OUTPUT};
}

# Close the error output if it was opened here
sub close_error_output {
  my ($self) = @_;
  close $self->{ERROR_OUTPUT} if $self->{OPENED_ERROR_OUTPUT};
}

# Report all of the problems that have been aggregated to the selected error output
sub report_all_problems {
  my ($self) = @_;
  my $error_output = $self->{ERROR_OUTPUT};
  foreach my $problem (sort keys %{$self->{PROBLEMS}}) {
    foreach my $message (sort keys %{$self->{PROBLEMS}{$problem}}) {
      my $num_instances = scalar keys %{$self->{PROBLEMS}{$problem}{$message}};
      print $error_output "$message";
      my $example = (keys %{$self->{PROBLEMS}{$problem}{$message}})[0];
      if ($example ne 'NO_SOURCE') {
	print $error_output " ($example";
	print $error_output " and ", $num_instances - 1, " other place" if $num_instances > 1;
	print $error_output "s" if $num_instances > 2;
	print $error_output ")";
      }
      print $error_output "\n";
    }
  }
  # Return the number of errors and the number of warnings encountered
  ($self->{PROBLEM_COUNTS}{ERROR} || 0, $self->{PROBLEM_COUNTS}{WARNING} || 0);
}

sub get_num_errors {
  my ($self) = @_;
  $self->{PROBLEM_COUNTS}{ERROR} || 0;
}

sub get_num_warnings {
  my ($self) = @_;
  $self->{PROBLEM_COUNTS}{WARNING} || 0;
}

sub get_error_type {
  my ($self, $error_name) = @_;
  $self->{FORMATS}{$error_name}{TYPE};
}

# NIST submission scripts demand an error code of 255 on failure
my $NIST_error_code = 255;

### DO NOT INCLUDE
# FIXME: Inconsistency: sometimes NIST_die is called directly; other
# times record_problem is called with a FATAL_ERROR
### DO INCLUDE
sub NIST_die {
  my ($self, @messages) = @_;
  my $outfile = $self->{ERROR_OUTPUT};
  print $outfile "================================================================\n";
  print $outfile Carp::longmess();
  print $outfile "================================================================\n";
  print $outfile join("", @messages), " at (", join(":", caller), ")\n";
  exit $NIST_error_code;
}

### END INCLUDE Logger
### BEGIN INCLUDE Patterns

#####################################################################################
# Patterns
#####################################################################################

package main;

# Eliminate comments, ensuring that pound signs in the middle of
# strings are not treated as comment characters
# Here is the original slightly clearer syntax that unfortunately doesn't work with Perl 5.8
# s/^(
# 	(?:[^#"]*+		      # Any number of chars that aren't double quote or pound sign
# 	  (?:"(?:[^"\\]++|\\.)*+")?   # Any number of double quoted strings
# 	)*+			      # The pair of them repeated any number of times
#   )				      # Everything up to here is captured in $1
#   (\s*\#.*)$/x;		      # Pound sign through the end of the line is not included in the replacement
our $comment_pattern = qr/
      ^(
	(?>
	  (?:
	    (?>[^#"]*)		      # Any number of chars that aren't double quote or pound sign
	    (?:"		      # Beginning of double quoted string
	      (?>		      # Start a possessive match of the string body
		(?:(?>[^"\\]+)|\\.)*  # Possessively match any number of non-double quotes or match an escaped char
	      )"		      # Possessively match the above repeatedly, before the closing double quote
	    )?			      # There might or might not be a double quoted string
	  )*			      # The pair of them repeated any number of times
	)			      # Possessively match everything before a pound sign that starts the comment
      )				      # Everything up to here is captured in $1
      (\s*\#.*)$/x;		      # Pound sign through the end of the line is not included in the replacement

### END INCLUDE Patterns
### BEGIN INCLUDE Provenance

#####################################################################################
# Provenance
#####################################################################################

package Provenance;

# Bounds from "Task Description for English Slot Filling at TAC-KBP 2014"
my $max_chars_per_triple = 150;
my $max_total_chars = 600;
my $max_triples = 4;

{
  my $docids;

  sub set_docids {
    $docids = $_[0];
  }

  # Validate a particular docid/offset-pair entry. Return the updated
  # start/end pair in case it has been updated
  sub check_triple {
    my ($logger, $where, $docid, $start, $end) = @_;
    my %checks;
    # If the offset triple is illegible, the document ID is set to
    # NO_DOCUMENT. Return failure, but don't report it (as the
    # underlying error has already been reported)
    return if $docid eq 'NO_DOCUMENT';

    if ($start !~ /^\d+$/) {
      $logger->record_problem('ILLEGAL_OFFSET', $start, $where);
      $checks{START} = $logger->get_error_type('ILLEGAL_OFFSET');
    }
    if ($end !~ /^\d+$/) {
      $logger->record_problem('ILLEGAL_OFFSET', $end, $where);
      $checks{END} = $logger->get_error_type('ILLEGAL_OFFSET');
    }
    if (defined $docids && !$docids->{$docid}) {
      $logger->record_problem('ILLEGAL_DOCID', $docid, $where);
      $checks{DOCID} = $logger->get_error_type('ILLEGAL_DOCID');
    }
    if (($checks{START} || '') ne 'ERROR' && ($checks{END} || '') ne 'ERROR') {
      if ($end < $start) {
	$logger->record_problem('ILLEGAL_OFFSET_PAIR', $start, $end, $where);
	$checks{PAIR} = $logger->get_error_type('ILLEGAL_OFFSET_PAIR');
      }
      elsif ($end - $start + 1 > $max_chars_per_triple) {
	$logger->record_problem('TOO_MANY_CHARS', $max_chars_per_triple, $where);
	# Fix the problem by truncating
	$end = $start + $max_chars_per_triple - 1;
	$checks{LENGTH} = $logger->get_error_type('TOO_MANY_CHARS');
      }
    }
    if (defined $docids &&
	($checks{START} || '') ne 'ERROR' &&
	($checks{DOCID} || '') ne 'ERROR') {
      if ($start > $docids->{$docid}) {
	$logger->record_problem('ILLEGAL_OFFSET_IN_DOC', $start, $docid, $where);
	$checks{START_OFFSET} = $logger->get_error_type('ILLEGAL_OFFSET_IN_DOC');
      }
    }
    if (defined $docids &&
	($checks{END} || '') ne 'ERROR' &&
	($checks{DOCID} || '') ne 'ERROR') {
      if ($end > $docids->{$docid}) {
	$logger->record_problem('ILLEGAL_OFFSET_IN_DOC', $end, $docid, $where);
	$checks{END_OFFSET} = $logger->get_error_type('ILLEGAL_OFFSET_IN_DOC');
      }
    }
    foreach (values %checks) {
      return if $_ eq 'ERROR';
    }
    return($start, $end);
  }
}

# This is used to, among other things, get a consistent string
# representing the provenance for use in construction of a UUID
sub tostring {
  my ($self) = @_;
  # join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"}
  #      sort {$a->{DOCID} cmp $b->{DOCID} ||
  # 	     $a->{START} <=> $b->{START} ||
  # 	     $a->{END} cmp $b->{END}}
  #      @{$self->{TRIPLES}});
### SPEEDUP
  $self->{PROVENANCE_TOSTRING} = join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"}
				      sort {$a->{DOCID} cmp $b->{DOCID} ||
					      $a->{START} <=> $b->{START} ||
					      $a->{END} cmp $b->{END}}
				      @{$self->{TRIPLES}})
    unless $self->{PROVENANCE_TOSTRING};
### SPEEDUP
  $self->{PROVENANCE_TOSTRING};
}

# tostring() normalizes provenance entry order; this retains the original order
sub tooriginalstring {
  my ($self) = @_;
  join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"} @{$self->{TRIPLES}});
}

# Create a new Provenance object
sub new {
  my ($class, $logger, $where, $type, @values) = @_;
  my $self = {LOGGER => $logger, TRIPLES => [], WHERE => $where};
  my $total = 0;
  if ($type eq 'EMPTY') {
    # DO NOTHING
  }
  elsif ($type eq 'DOCID_OFFSET_OFFSET') {
    my ($docid, $start, $end) = @values;
    if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
      push(@{$self->{TRIPLES}}, {DOCID => $docid,
				 START => $start,
				 END => $end,
				 WHERE => $where});
      $total += $end - $start + 1;
    }
  }
  elsif ($type eq 'DOCID_OFFSETPAIRLIST') {
    my ($docid, $offset_pair_list) = @values;
    my $start;
    my $end;
    foreach my $pair (split(/,/, $offset_pair_list)) {
      unless (($start, $end) = $pair =~ /^\s*(\d+)-(\d+)\s*$/) {
	$logger->record_problem('ILLEGAL_OFFSET_PAIR_STRING', $pair, $where);
	$start = 0;
	$end = 0;
      }
      if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
	push(@{$self->{TRIPLES}}, {DOCID => $docid,
				   START => $start,
				   END => $end,
				   WHERE => $where});
	$total += $end - $start + 1;
      }
      else {
	return;
      }
    }
  }
  elsif ($type eq 'PROVENANCETRIPLELIST') {
    my ($triple_list) = @values;
    my @triple_list = split(/,/, $triple_list);
    if (@triple_list > $max_triples) {
      $logger->record_problem('TOO_MANY_PROVENANCE_TRIPLES',
			      scalar @triple_list, $max_triples, $where);
      $#triple_list = $max_triples - 1;
    }
    foreach my $triple (@triple_list) {
      my $docid;
      my $start;
      my $end;
      unless (($docid, $start, $end) = $triple =~ /^\s*([^:]+):(\d+)-(\d+)\s*$/) {
	$logger->record_problem('ILLEGAL_OFFSET_TRIPLE_STRING', $triple, $where);
	$docid = 'NO_DOCUMENT';
	$start = 0;
	$end = 0;
      }
      if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
	push(@{$self->{TRIPLES}}, {DOCID => $docid,
				   START => $start,
				   END => $end,
				   WHERE => $where});
	$total += $end - $start + 1;
      }
    }
  }
  if ($total > $max_total_chars) {
    $logger->record_problem('TOO_MANY_TOTAL_CHARS', $max_total_chars, $where);
  }
  bless($self, $class);
  $self;
}

sub get_docid {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return "NO DOCUMENT" unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{DOCID};
}

sub get_start {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return 0 unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{START};
}

sub get_end {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return 0 unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{END};
}

sub get_num_entries {
  my ($self) = @_;
  scalar @{$self->{TRIPLES}};
}


### END INCLUDE Provenance
### BEGIN INCLUDE Query

#####################################################################################
# Query
#####################################################################################

package Query;

my $predicate_set;
# $predicate_set = PredicateSet->new($logger);

### DO NOT INCLUDE
# FIXME: We'd probably be better off using an existing SGML parser of some sort here
### DO INCLUDE
# This table indicates how to parse XML queries
# ORD       indicates the output ordering of query fields
# TYPE      indicates whether a query may have only one or more than one of the field (some
#           years allow multiple entrypoints in a query)
# YEARS     indicates which TAC year(s) used that field (not currently used programmatically)
# REQUIRED  flags an error if an attempt is made to output a query that lacks the field
# REWRITE   changes the field name to the indicated name
my %tags = (
  ENTRYPOINTS => {ORD => 0, TYPE => 'single'},

  ENTTYPE =>     {ORD => 1, TYPE => 'single',   YEARS => '2014:2015', REQUIRED => 'yes'},
  NODEID =>      {ORD => 2, TYPE => 'single',	YEARS => '2016'},
  SLOT =>        {ORD => 3, TYPE => 'single',   YEARS => '2014:2015'},
  SLOT0 =>       {ORD => 4, TYPE => 'single',                        REQUIRED => 'yes'},
  SLOT1 =>       {ORD => 5, TYPE => 'single',   },
  SLOT2 =>       {ORD => 6, TYPE => 'single',   YEARS => '2012'},

  NAME =>        {ORD => 1, TYPE => 'multiple',                      REQUIRED => 'yes'},
  DOCID =>       {ORD => 2, TYPE => 'multiple',                      REQUIRED => 'yes'},
  BEG =>         {ORD => 3, TYPE => 'multiple',                      REQUIRED => 'yes', REWRITE => 'START'},
  END =>         {ORD => 4, TYPE => 'multiple',                      REQUIRED => 'yes'},
  OFFSET =>      {ORD => 5, TYPE => 'multiple', YEARS => '2012:2013'},
);


my %languages = (
  ENGLISH => {
    NAME => "ENGLISH",
    CODE => "ENG",
  },      
  SPANISH => {
    NAME => "SPANISH",
    CODE => "SPA",
  },      
  CHINESE => {
    NAME => "CHINESE",
    CODE => "CMN",
  },      
);

sub parse_queryid {
  my ($full) = @_;
  my ($base, $query_id, $level, $expanded, $prefix, $initial, $remainder, @components);
  if (($prefix, $initial, $remainder) = $full =~ /^(?:(.+)_)?([0-9A-F]{10})(_[0-9A-F]{12})*$/i) {
    $remainder ||= "";
    my @remainder = $remainder =~ /_([0-9A-F]{12})/gi;
    $level = scalar @remainder;
    $query_id = $level ? pop @remainder : $initial;
    $expanded = 'true';
   	@components = @remainder;
   	unshift(@components, $initial);
   	push(@components, $query_id) if($level);
   	$base = $components[0];
  }
  # If this function is invoked over LDC queryid
  elsif(($prefix, $initial) = $full =~ /^(?:(.+)_)?(\d+)$/i) {
  	$level = 0;
  	$query_id = $initial;
  	push(@components, $query_id);
  	$base = $query_id;
  }
  else {
  	die "unexpected argument: \"$full\" sent to parse_queryid\n";
  }
### DO NOT INCLUDE
    # FIXME: Handle PSEUDO, etc., as used to be in &get_query_id_base
### DO INCLUDE
  # FIXME: Eventually, let's completely separate base from query_id (by eliminating the following line)
  #$query_id = "${base}_$query_id" if $base;
  ($base, $query_id, $level, $expanded, $prefix, @components); 
}

sub put {
  my ($self, $fieldname, $value) = @_;
  $fieldname = uc $fieldname;
  $self->{$fieldname} = $value;
### DO NOT INCLUDE
  # FIXME: Can generalize to more than two levels, set LEVEL
### DO INCLUDE
  if ($fieldname eq 'QUERY_ID') {
    my (undef, $query_id) = &Query::parse_queryid($value);
    $self->{QUERY_ID} = $query_id;
  }
  elsif ($fieldname eq 'SLOTS') {
    $self->{SLOT} = $value->[0];
    foreach my $num (0..$#{$value}) {
      $self->put("SLOT$num", $value->[$num]);
    }
    $self->{LASTSLOT} = &main::max($self->{LASTSLOT} || 0, $#{$value});
  }
  elsif ($fieldname =~ /^SLOT(\d+)$/) {
    my $level = $1;
    $self->{SLOTS}[$level] = $value;
    $self->{LASTSLOT} = &main::max($self->{LASTSLOT} || 0, $level);
    # Split the domain name from the slot name
    $value =~ /^(.*?):(.*)$/;
    my $domain = $1;
    my $shortname = $2;
### SPEEDUP
    $predicate_set = PredicateSet->new($self->{LOGGER}) unless $predicate_set;
### SPEEDUP
    my @candidates = $predicate_set->lookup_predicate($shortname, $domain);
    unless (@candidates) {
      $self->{LOGGER}->record_problem('UNKNOWN_SLOT_NAME', $value, 'NO_SOURCE');
      return;
    }
    if (@candidates > 1) {
### DO NOT INCLUDE
      # FIXME: I'm not convinced this can happen with fully qualified
      # predicate names; it probably dates back to the time when
      # predicate specifications were not guaranteed to be qualified
      # with the domain name.
### DO INCLUDE
      print STDERR "Warning: more than one candidate predicate for $shortname in domain $domain\n";
    }
    $self->{PREDICATES}[$level] = $candidates[0];
    if ($level == 0) {
      $self->put('SLOT', $value);
      $self->put('QUANTITY', $candidates[0]{QUANTITY});
    }
    $self->put("${fieldname}_QUANTITY", $candidates[0]{QUANTITY});
  }
  $value;
}

sub get {
  my ($self, $fieldname) = @_;
  return $self->get_full_queryid() if(uc $fieldname eq 'FULL_QUERY_ID');
  $self->{uc $fieldname};
}

# Recursively get the complete QUERYID
sub get_full_queryid {
	my ($self) = @_;
		
	return "$self->{PREFIX}_$self->{QUERY_ID}" if(!$self->{PARENTQUERY});
	
	return $self->{PARENTQUERY}->get_full_queryid()."_".$self->{QUERY_ID};
}

### DO NOT INCLUDE
# sub get_query_id_base {
#   my ($query_id) = @_;
#   my $result = $query_id;
#   # Remove full UUIDs (from 2014)
#   $result = $1 if $query_id =~ /^(.*?)_\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/;
#   $result = $1 if $query_id =~ /^(.*?)_PSEUDO/;
#   # Remove longer short uuid (from 2015)
#   $result = $1 if $query_id =~ /^(.*?)_[0-9a-f]{12}$/i;
#   # Remove short uuid (from GenerateQueries)
#   $result = $1 if $query_id =~ /^(.*?_[0-9a-f]{10})$/i;
#   $result;
# }
### DO INCLUDE

# Calculate a hash of this query
sub get_short_uuid {
  my ($self) = @_;
### DO NOT INCLUDE
  # FIXME: Don't even try to UUID an unexpanded query?
### DO INCLUDE
  my $entrypoint = $self->get_entrypoint(0);
  my $string = "$entrypoint->{DOCID}:$entrypoint->{START}:$entrypoint->{END}:" . join(":", @{$self->{SLOTS}});
### DO NOT INCLUDE
  # FIXME: Don't hard-code the length
### DO INCLUDE
  &main::generate_uuid_from_string($string, 10);
}

# sub get_hashname {
#   my ($self) = @_;
#   my $short_uuid = $self->get_short_uuid();
#   my $query_base = $self->get('QUERY_ID_BASE');
#   "${query_base}_$short_uuid";
# }

# sub rename_query {
#   my ($self, $new_name) = @_;
#   $new_name = $self->get_hashname() unless defined $new_name;
#   $self->put('QUERY_ID', $new_name);
# }

sub get_entrypoint {
  my ($self, $pos) = @_;
  $pos = 0 unless defined $pos;
  $self->{ENTRYPOINTS}[$pos];
}

sub get_num_entrypoints {
  my ($self) = @_;
  scalar @{$self->{ENTRYPOINTS}};
}

sub get_all_entrypoints {
  my ($self) = @_;
  @{$self->{ENTRYPOINTS}};
}

sub add_entrypoint {
  my ($self, %entrypoint) = @_;
  unless (defined($entrypoint{PROVENANCE})) {
    $entrypoint{PROVENANCE} = Provenance->new($self->{LOGGER},
					      $entrypoint{WHERE} || 'NO_SOURCE',
					      'DOCID_OFFSET_OFFSET',
					      $entrypoint{DOCID},
					      $entrypoint{START},
					      $entrypoint{END});
  }
  my $provenance = $entrypoint{PROVENANCE};
  $entrypoint{DOCID} = $provenance->{TRIPLES}[0]{DOCID} unless defined $entrypoint{DOCID};
  $entrypoint{START} = $provenance->{TRIPLES}[0]{START} unless defined $entrypoint{START};
  $entrypoint{END} = $provenance->{TRIPLES}[0]{END} unless defined $entrypoint{END};
  $entrypoint{LANGUAGE} = $self->infer_language_from_documentid($entrypoint{DOCID}, $entrypoint{WHERE} || 'NO_SOURCE');
  push( @{$self->{LANGUAGES}}, $entrypoint{LANGUAGE} ) unless grep {$_ eq $entrypoint{LANGUAGE}} @{$self->{LANGUAGES}};
### DO NOT INCLUDE
  # FIXME: Don't hard-code the 12
### DO INCLUDE
  $entrypoint{UUID} = &main::generate_uuid_from_values($self->{QUERY_ID}, $entrypoint{NAME}, $provenance->tostring(), 12)
    unless defined $entrypoint{UUID};
  push(@{$self->{ENTRYPOINTS}}, \%entrypoint);
  \%entrypoint;
}

# Infer language from documentid 
sub infer_language_from_documentid{
  my ($self, $documentid, $where) = @_;
  my $language;
  if($documentid =~ /^CMN/i) {
  	$language = "CHINESE";
  }
  elsif($documentid =~ /^SPA/i) {
  	$language = "SPANISH";
  }
  elsif($documentid =~ /ENG/i) {
  	$language = "ENGLISH";
  }
  else {
  	$self->{LOGGER}->record_problem('FAILED_LANG_INFERENCE', $documentid, 'ENGLISH', $where);
  	$language = "ENGLISH";
  }
  return $language;
}

# Create a new Query object
sub new {
  my ($class, $logger, $text, $filename) = @_;
  my $self = {LOGGER => $logger, LEVEL => 0, ENTRYPOINTS => [], EXPANDED_QUERY_IDS => [], LANGUAGES => [], FILENAME => $filename};
  bless($self, $class);
  $self->populate_from_text($text) if defined $text;
  $self;
}

sub duplicate {
  my ($self, @fields_to_omit) = @_;
  my %fields_to_omit = map {$_ => 'true'} @fields_to_omit;
  my $class = ref $self;
  my $result = $class->new($self->{LOGGER});
  foreach my $key (keys %{$self}) {
    # Skip keys that are automatically generated
#    next if $key =~ /^(?:QUERY_ID_BASE|LASTSLOT|SLOT\d*|LOGGER)$/;
    next if $key =~ /^(?:LASTSLOT|SLOT\d*|LOGGER)$/;
    # Skip keys we were requested to skip (Note: this will not prevent automatic creation)
    next if $fields_to_omit{$key};
    $result->put($key, $self->get($key));
  }
  $result;
}

# Expand a single query with (possibly) multiple entry points to a
# QuerySet of queries, each with a single entry point. Rename the
# queries according to $query_base
sub expand {
  my ($self, $query_base, $queries) = @_;
  $queries = QuerySet->new($self->{LOGGER}) unless defined $queries;
  my $entrypoints = $self->get("ENTRYPOINTS");
  foreach my $entrypoint (@{$entrypoints}) {
    my $new_query = $self->duplicate(qw(ENTRYPOINTS ORIGINAL_QUERY_ID EXPANDED_QUERY_IDS QUERY_ID_BASE FROM_FILE PREFIX MENTIONS_TAGGED LANGUAGES));
    $new_query->add_entrypoint(%{$entrypoint});
### DO NOT INCLUDE
# FIXME: Why was SLOT being deleted?
#    delete $new_query->{SLOT};
### DO INCLUDE
    $new_query->put('QUERY_ID', $new_query->get_short_uuid());
    
### DO NOT INCLUDE
# FIXME: Jim, I have commented this because I think we are confusing query_base with 
# prefix.
    #$new_query->put('QUERY_ID_BASE', $query_base);
### DO INCLUDE
    my $language_code = $languages{$entrypoint->{LANGUAGE}}{CODE};
    $new_query->put('PREFIX', "$query_base\_$language_code");
    $new_query->put('ORIGINAL_QUERY_ID', $self->get('FULL_QUERY_ID'));
    push(@{$self->{EXPANDED_QUERY_IDS}}, $new_query->get('QUERY_ID'));
    $new_query->put('QUERY_ID_BASE', $new_query->get('QUERY_ID'));
    @{$new_query->{COMPONENTS}} = [$new_query->get('QUERY_ID')];
    $new_query->{EXPANDED} = 'false';
    $queries->add($new_query);
  }
  $self->{EXPANDED} = 'true';
  $queries;
}

sub truncate_slots {
  my ($self, $max_slot) = @_;
  my @truncated = @{$self->{SLOTS}}[0..$max_slot];
  $self->{SLOTS} = \@truncated;
  for (my $num = $max_slot + 1; defined $self->{"SLOT$num"}; $num++) {
    delete $self->{"SLOT$num"};
  }
  $self;
}

# Create a follow-on query for a given reponse
sub generate_query {
  my ($self, $value, $value_provenance) = @_;
  $self->{LOGGER}->NIST_die("Attempt to execute method generate_query on query $self->{QUERY_ID}, which has multiple entrypoints")
    if ($self->get_num_entrypoints() > 1);
  my $new_query = Query->new($self->{LOGGER});
  $new_query->{GENERATED} = 'true';
  # QUERY_ID
### DO NOT INCLUDE
  # FIXME: Don't hard-code the 12
### DO INCLUDE
  $new_query->put('QUERY_ID',
  		$self->get('FULL_QUERY_ID').'_'.
		  &main::generate_uuid_from_values($self->get('FULL_QUERY_ID'), $value, $value_provenance->tostring(), 12));
  # SLOTS, SLOTn, SLOT
  my @new_slots = @{$self->{SLOTS}};
  shift @new_slots;
  # If there are no slots left to fill, don't generate a query
  #return unless @new_slots;
  $new_query->put('SLOTS', \@new_slots) if @new_slots;
  # ENTRYPOINTS
  $new_query->add_entrypoint(NAME => $value, PROVENANCE => $value_provenance);
  # LEVEL
  $new_query->put('LEVEL', $self->{LEVEL} + 1);
  $new_query->put('PARENTQUERY', $self);
  $new_query;
}

### DO NOT INCLUDE
# FIXME: There's something on CPAN that does this for you
### DO INCLUDE
my %html_entities = (
  quot => '"',
  amp => '&',
  apos => "'",
  lt => '<',
  gt => '>',
);

# Convert the text of the query to a query object
sub populate_from_text {
  my ($self, $text) = @_;
  if ($text !~ /^\s*<query\s+id="(.*?)">\s*(.*?)\s*<\/query>\s*$/s) {
    $self->{LOGGER}->record_problem('MALFORMED_QUERY',
				    "Query starting with \"" . substr($text, 0, 25) . "\"" .
				    " in text beginning <<" . substr($text, 0, 25) . ">>",
				    'In file $filename');
    return;
  }
  my $id = $1;
  my $body = $2;
  # The (Full) Query ID is not a field, but comes from the <query> tag. So
  # we add it to the result explicitly
  ($self->{QUERY_ID_BASE}, $self->{QUERY_ID}, $self->{LEVEL}, $self->{EXPANDED}, $self->{PREFIX}, @{$self->{COMPONENTS}}) =
      &Query::parse_queryid($id);
  my $where = {FILENAME => $self->{FILENAME}, LINENUM => "In query $id"};
### DO NOT INCLUDE
  # FIXME: We don't currently store LEVEL in the query file, so there's no easy way to determine LEVEL
  # $self->{LEVEL} = 1 if $id ne $self->{QUERY_ID_BASE} && !$self->{LEVEL};
### DO INCLUDE
  my $entrypoint = {};
  # Find all tag pairs within the query

### DO NOT INCLUDE
  # FIXME: Handle the modification in 2016s LDC query format decently
### DO INCLUDE
  # Handle the modification in 2016 LDC query here
  # This is a poor-man fix. The good part however is that its a one-liner and its backward compatible
  $self->{MENTIONS_TAGGED} = "true" if $body=~/<\/?mentions?>/;
  $body =~ s/<\/?mentions?>//gs;

  while ($body =~ /<(.*?)>(.*?)<\/(.*?)>/gs) {
    my ($tag, $value, $closer) = (uc $1, $2, uc $3);
    $self->{LOGGER}->record_problem('MISMATCHED_TAGS', $tag, $closer, $where)
      unless $tag eq $closer;
    my $original_name;
    my $info = $tags{$tag};
    unless (defined $info) {
      $self->{LOGGER}->record_problem('UNKNOWN_QUERY_FIELD', $tag, $where);
      next;
    }
    # decode HTML entities
    if ($tag eq 'NAME') {
      $original_name = $value;
      $value =~ s/&(.+?);/$html_entities{$1}/ge;
    }
    # apply aliases and renamings
    $tag = $info->{REWRITE} if defined $info->{REWRITE};
    # 2013 and 2015 include more than one entrypoint per query. Here we
    # collect each such entrypoint into its own hash
    if ($info->{TYPE} eq 'multiple') {
      if (defined $entrypoint->{$tag}) {
	$self->add_entrypoint(%{$entrypoint}, WHERE => $where);
	$entrypoint = {};
      }
      $entrypoint->{$tag} = $value;
      $entrypoint->{ORIGINAL_NAME} = $original_name if $tag eq 'NAME';
    }
    else {
      if (defined $self->{$tag}) {
	$self->{LOGGER}->record_problem('DUPLICATE_QUERY_FIELD', $tag, $where);
      }
      else {
	$self->put($tag, $value);
      }
    }
  }
  $self->add_entrypoint(%{$entrypoint}, WHERE => $where) if keys %{$entrypoint};
  $self;
}

# Convert the query object back to the correct text file format
sub tostring {
  my ($self, $indent, $omit) = @_;
  $indent = "" unless defined $indent;
  $omit = [] unless defined $omit;
  my %omit = (ORIGINAL_NAME => 'true');
  foreach my $field (@{$omit}) {
    $omit{$field}++;
  }
  my $string = "$indent<query id=\"" . $self->get('FULL_QUERY_ID') . "\">\n";
  my $mention_tagged_indent = "";
  $mention_tagged_indent = "      " 
    if exists $self->{MENTIONS_TAGGED} && $self->{MENTIONS_TAGGED} eq 'true';
  foreach my $field (sort {$tags{$a}{ORD} <=> $tags{$b}{ORD}}
		     grep {$tags{$_}{TYPE} eq 'single'} keys %tags) {
    if ($field eq 'ENTRYPOINTS') {
      $string .= "$indent  <mentions>\n"
      	if exists $self->{MENTIONS_TAGGED} && $self->{MENTIONS_TAGGED} eq 'true';
      foreach my $entrypoint (@{$self->{ENTRYPOINTS}}) {
      $string .= "$indent    <mention>\n"
      	if exists $self->{MENTIONS_TAGGED} && $self->{MENTIONS_TAGGED} eq 'true';
	foreach my $subfield (sort {$tags{$a}{ORD} <=> $tags{$b}{ORD}}
			      grep {$tags{$_}{TYPE} eq 'multiple'} keys %tags) {
	  next if $omit{$subfield};
	  my $value = defined $tags{$subfield}{REWRITE} ?
	    $entrypoint->{$tags{$subfield}{REWRITE}} :
	    $subfield eq 'NAME' && defined $entrypoint->{ORIGINAL_NAME} ? $entrypoint->{ORIGINAL_NAME} :
	    $entrypoint->{$subfield};
	  if (defined $value) {
	    $string .= "$indent$mention_tagged_indent  <" . lc($subfield) . ">$value</" . lc($subfield) . ">\n";
	  }
	  elsif ($tags{$subfield}{REQUIRED}) {
	    $self->{LOGGER}->NIST_die("Missing query field: <$subfield>");
	  }
	  else {
	    # Just skip this field
	  }
	}
      $string .= "$indent    <\/mention>\n"
      	if exists $self->{MENTIONS_TAGGED} && $self->{MENTIONS_TAGGED} eq 'true';
      }
      $string .= "$indent  <\/mentions>\n"
      	if exists $self->{MENTIONS_TAGGED} && $self->{MENTIONS_TAGGED} eq 'true';
      
    }
    else {
      next if $omit{$field};
      if ($tags{$field}{REQUIRED} && !defined $self->{$field}) {
	$self->{LOGGER}->NIST_die("Missing query field: $field");
      }
      $string .= "$indent  <" . lc($field) . ">$self->{$field}</" . lc($field) . ">\n"
	if defined $self->{$field};
    }
  }
  $string .= "$indent</query>\n";
  $string;
}

### END INCLUDE Query
### BEGIN INCLUDE QuerySet

#####################################################################################
# QuerySet
#####################################################################################

package QuerySet;

# QuerySets have the following fields
#  CHILDREN ------------ Maps Query ID to list of child Queries
#  FILENAMES ----------- List of filenames (if any) from which queries were read
#  LOGGER -------------- Logs problems
#  PARENTS ------------- Maps Query ID to parent Query
#  QUERIES ------------- Maps Query ID to Query

# Create a new QuerySet object
sub new {
  my ($class, $logger, @filenames) = @_;
  my $self = {LOGGER => $logger, FILENAMES => \@filenames, QUERIES => {}};
  bless($self, $class);
  foreach my $filename (@filenames) {
### DO NOT INCLUDE
#print STDERR "*** Populating from $filename\n";
### DO INCLUDE
    # Slurp the entire text
    open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
    local($/);
    my $text = <$infile>;
    close $infile;
    $self->populate_from_text($text, $filename);
  }
  # Make sure that at least one query was found
  $logger->record_problem('NO_QUERIES_LOADED', "files(" . join(", ", @filenames) . ")")
    unless !@filenames || keys %{$self->{QUERIES}};
  $self;
}

# Convert an evaluation query file to a QuerySet
sub populate_from_text {
  my ($self, $text, $filename) = @_;
  # Repeatedly look for text that lies between <query> and </query> tags.
  while ($text =~ /(<query .*?>.*?<\/query>)/gs) {
    my $querytext = $1;
    my $query = Query->new($self->{LOGGER}, $querytext, $filename);
    $query->{FROM_FILE} = 'true';
### DO NOT INCLUDE
    # FIXME: Shahzad recommends adding the condition
    # <<&& !$query->get("LEVEL")>> for resolving queries
    # to restrict the queries to top-level queries read
    # from the file
### DO INCLUDE
    $self->add($query) if $query->{SLOTS};
  }
}

# Add a query to this QuerySet
sub add {
  my ($self, $query, $parent_query) = @_;
  return unless defined $query;
  my $id = $query->get("QUERY_ID");
  if ($self->{QUERIES}{$id}) {    
    # Prefer a query that's been read in to one that is automatically
    # generated (if only to ensure the GENERATED field is properly
    # set)
    $self->{QUERIES}{$id} = $query unless $query->{GENERATED};
### DO NOT INCLUDE
    # FIXME: Might want to flag a DUPLICATE_QUERY_ID here
### DO INCLUDE
  }
  else {
    $self->{QUERIES}{$id} = $query;
  }
  # No parent query is provided when loading queries directly, because
  # we can't know what our own parent is (unless we rely on having at
  # most two levels, and we munge the query id). But when we load
  # submissions and assessments, we can at that point know the
  # parent. So make the $parent_query parameter optional, and record
  # the parent/child relationship only if it's provided.
  if ($parent_query) {
    $self->{PARENTS}{$query->{QUERY_ID}} = $parent_query;
    push(@{$self->{CHILDREN}{$parent_query->{QUERY_ID}}}, $query);
  }
  # if ($query->{TYPE} eq 'ASSESSMENT' &&
  #     ($query->{ASSESSMENT} eq 'CORRECT' || $entry->{ASSESSMENT} eq 'INEXACT')) {
############################################################################################################################## FIXME

  #$query->expand("", $self) unless $query->{EXPANDED};
  $query;
}

sub expand {
  my ($self, $query_base) = @_;
#print STDERR "------- expand ---------\n";
  foreach my $query ($self->get_all_queries()) {
#print STDERR "     From QuerySet->expand Expanding query ", $query->get('QUERY_ID'), "\n";
    $query->expand($query_base, $self);
  }
  $self;
}

# Find the query with the provided query ID
sub get {
  my ($self, $queryid) = @_;
#print STDERR "get($queryid) from ", join(":", caller), "\n";

### DO NOT INCLUDE
# FIXME: Shahzad just uses undef here
### DO INCLUDE
  $self->{LOGGER}->NIST_die("queryid undefined in QuerySet->get()") unless defined $queryid;
  $self->{QUERIES}{$queryid};
}

sub get_filenames {
  my ($self) = @_;
  @{$self->{FILENAMES}};
}

sub get_all_queries {
  my ($self) = @_;
  values %{$self->{QUERIES}};
}

sub get_original_query_ids {
  my ($self) = @_;
  grep {$self->{QUERIES}{$_}{"EXPANDED"} eq "true"} sort keys %{$self->{QUERIES}};
}

sub get_expanded_query_ids {
  my ($self) = @_;
  grep {$self->{QUERIES}{$_}{"EXPANDED"} eq "false"} sort keys %{$self->{QUERIES}};
}

sub get_index {
  my ($self) = @_;
  my %index;
  my @original_query_ids = $self->get_original_query_ids();
  foreach my $original_query_id (@original_query_ids) {
  	foreach my $expanded_query_id (@{$self->{QUERIES}{$original_query_id}{"EXPANDED_QUERY_IDS"}}) {
  	  $index{$expanded_query_id} = $original_query_id;
  	}
  }
  %index;
}


sub get_all_query_ids {
  my ($self) = @_;
  sort keys %{$self->{QUERIES}};
}

sub get_all_top_level_query_ids {
  my ($self) = @_;
  grep {!$self->get_parent_id($_)} $self->get_all_query_ids();
}

sub get_full_queryid {
  my ($self, $queryid) = @_;
  $self->get($queryid)->get_full_queryid();
}

sub get_parent_id {
  my ($self, $query_id) = @_;
  $self->{PARENTS}{$query_id};
}

sub get_parent {
  my ($self, $query_id) = @_;
  my $parent_id = $self->get_parent_id($query_id);
  return unless $parent_id;
  $self->get($parent_id);
}

sub get_ancestor_id {
  my ($self, $query_id) = @_;
  my $parent_id = $self->get_parent_id($query_id);
  $parent_id ? $self->get_ancestor_id($parent_id) : $query_id;
}

sub get_ancestor {
  my ($self, $query_id) = @_;
  my $ancestor_id = $self->get_ancestor_id($query_id);
  return unless $ancestor_id;
  $self->get($ancestor_id);
}

sub get_child_ids {
  my ($self, $query_id) = @_;
  $self->{CHILDREN}{$query_id};
}

# Convert the QuerySet to text form, suitable for print as a TAC evaluation query file
sub tostring {
  my ($self, $indent, $queryids, $omit, $languages) = @_;
  $indent = "" unless defined $indent;
  my $string = "$indent<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$indent<query_set>\n";
  foreach my $query (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID}}
		     values %{$self->{QUERIES}}) {
    next if $query->{GENERATED};
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
    next unless !defined $queryids || $queryids->{$query->{QUERY_ID}};
    $string .= $query->tostring("$indent  ", $omit);
  }
  $string .= "$indent</query_set>\n";
  $string;
}

### END INCLUDE QuerySet
### BEGIN INCLUDE Predicates

#####################################################################################
##### Predicates
#####################################################################################

########################################################################################
# This table lists the legal predicates. An asterisk means the relation is single-valued
########################################################################################

my $predicates_spec = <<'END_PREDICATES';
# DOMAIN         NAME                             RANGE        INVERSE
# ------         ----                             -----        -------
  PER            age*                             STRING       none
  PER,ORG        alternate_names                  STRING       none
  GPE            births_in_city                   PER          city_of_birth*
  GPE            births_in_country                PER          country_of_birth*
  GPE            births_in_stateorprovince        PER          stateorprovince_of_birth*
  PER            cause_of_death*                  STRING       none
  PER            charges                          STRING       none
  PER            children                         PER          parents
  PER            cities_of_residence              GPE          residents_of_city
  PER            city_of_birth*                   GPE          births_in_city
  PER            city_of_death*                   GPE          deaths_in_city
  ORG            city_of_headquarters*            GPE          headquarters_in_city
  PER            countries_of_residence           GPE          residents_of_country
  PER            country_of_birth*                GPE          births_in_country
  PER            country_of_death*                GPE          deaths_in_country
  ORG            country_of_headquarters*         GPE          headquarters_in_country
  ORG            date_dissolved*                  STRING       none
  ORG            date_founded*                    STRING       none
  PER            date_of_birth*                   STRING       none
  PER            date_of_death*                   STRING       none
  GPE            deaths_in_city                   PER          city_of_death*
  GPE            deaths_in_country                PER          country_of_death*
  GPE            deaths_in_stateorprovince        PER          stateorprovince_of_death*
  PER            employee_or_member_of            ORG,GPE      employees_or_members
  ORG,GPE        employees_or_members             PER          employee_or_member_of
  ORG            founded_by                       PER,ORG,GPE  organizations_founded
  GPE            headquarters_in_city             ORG          city_of_headquarters*
  GPE            headquarters_in_country          ORG          country_of_headquarters*
  GPE            headquarters_in_stateorprovince  ORG          stateorprovince_of_headquarters*
  PER,ORG,GPE    holds_shares_in                  ORG          shareholders
  ORG,GPE        member_of                        ORG          members
  ORG            members                          ORG,GPE      member_of
  ORG            number_of_employees_members*     STRING       none
  PER,ORG,GPE    organizations_founded            ORG          founded_by
  PER            origin                           STRING       none
  PER            other_family                     PER          other_family
  PER            parents                          PER          children
  ORG            parents                          ORG,GPE      subsidiaries
  ORG            political_religious_affiliation  STRING       none
  PER            religion*                        STRING       none
  GPE            residents_of_city                PER          cities_of_residence
  GPE            residents_of_country             PER          countries_of_residence
  GPE            residents_of_stateorprovince     PER          statesorprovinces_of_residence
  PER            schools_attended                 ORG          students
  ORG            shareholders                     PER,ORG,GPE  holds_shares_in
  PER            siblings                         PER          siblings
  PER            spouse                           PER          spouse
  PER            stateorprovince_of_birth*        GPE          births_in_stateorprovince
  PER            stateorprovince_of_death*        GPE          deaths_in_stateorprovince
  ORG            stateorprovince_of_headquarters* GPE          headquarters_in_stateorprovince
  PER            statesorprovinces_of_residence   GPE          residents_of_stateorprovince
  ORG            students                         PER          schools_attended
  ORG,GPE        subsidiaries                     ORG          parents
  PER            title                            STRING       none
  PER            top_member_employee_of           ORG          top_members_employees
  ORG            top_members_employees            PER          top_member_employee_of
  ORG            website*                         STRING       none
# The following are not TAC slot filling predicates, but rather
# predicates required by the Cold Start task. FAC and LOC are included
# to support the export of a Cold Start Run as an EDL submission
  PER,ORG,GPE,FAC,LOC    mention                  STRING       none
  PER,ORG,GPE,FAC,LOC    canonical_mention        STRING       none
  PER,ORG,GPE,FAC,LOC    type                     TYPE         none
  PER,ORG,GPE,FAC,LOC    link                     STRING       none
# nominal mention is added here for those who want to convert Cold Start output to EDL
  PER,ORG,GPE,FAC,LOC            nominal_mention                  STRING       none
END_PREDICATES

#####################################################################################
# This table lists known aliases of the legal predicates.
#####################################################################################

my $predicate_aliases = <<'END_ALIASES';
# REASON        DOMAIN    ALIAS                               MAPS TO
# ------        ------    -----                               -------
  DEPRECATED    ORG       dissolved                           date_dissolved
  DEPRECATED    PER       employee_of                         employee_or_member_of
  DEPRECATED    ORG,GPE   employees                           employees_or_members
  DEPRECATED    ORG       founded                             date_founded
  DEPRECATED    PER       member_of                           employee_or_member_of
  DEPRECATED    ORG,GPE   membership                          employees_or_members
  DEPRECATED    ORG       number_of_employees/members         number_of_employees_members
  DEPRECATED    ORG       political/religious_affiliation     political_religious_affiliation
  DEPRECATED    PER       stateorprovinces_of_residence       statesorprovinces_of_residence
  DEPRECATED    ORG       top_members/employees               top_members_employees
  MISSPELLED    PER       ages                                age
  MISSPELLED    ANY       canonical_mentions                  canonical_mention
  MISSPELLED    PER       city_of_residence                   cities_of_residence
  MISSPELLED    PER       country_of_residence                countries_of_residence
  MISSPELLED    ANY       mentions                            mention
  MISSPELLED    PER       spouses                             spouse
  MISSPELLED    PER       stateorprovince_of_residence        statesorprovinces_of_residence
  MISSPELLED    PER       titles                              title
END_ALIASES

package PredicateSet;

# Populate the set of predicate aliases from $predicate_aliases (defined at the top of this file)
my %predicate_aliases;
foreach (grep {!/^\s*#/} split(/\n/, lc $predicate_aliases)) {
  my ($reason, $domains, $alias, $actual) = split;
  foreach my $domain (split(/,/, $domains)) {
    $predicate_aliases{$domain}{$alias} = {REASON => $reason, REPLACEMENT => $actual};
  }
}

sub build_hash { map {$_ => 'true'} @_ }
# Set of legal range types (e.g., {PER, ORG, GPE})
our %legal_range_types = &build_hash(qw(per gpe org string type));
# Set of types that are entities
our %legal_entity_types = &build_hash(qw(per gpe org fac loc));

# Is one type specification compatible with another?  The second
# argument must be a hash representing a set of types. The first
# argument may either be the same representation, or a single type
# name. The two are compatible if the second is a (possibly improper)
# superset of the first.
sub is_compatible {
  my ($type, $typeset) = @_;
  my @type_names;
  if (ref $type) {
    @type_names = keys %{$type};
  }
  else {
    @type_names = ($type);
  }
  foreach (@type_names) {
    return unless $typeset->{$_};
  }
  return "compatible";
}

# Find all predicates with the given name that are compatible with the
# domain and range given, if any
sub lookup_predicate {
  my ($self, $name, $domain, $range) = @_;
  my @candidates = @{$self->{$name} || []};
  @candidates = grep {&is_compatible($domain, $_->get_domain())} @candidates if defined $domain;
  @candidates = grep {&is_compatible($range, $_->get_range())} @candidates if defined $range;
  @candidates;
}

# Create a new PredicateSet object
sub new {
  my ($class, $logger, $label, $spec) = @_;
  $label = 'TAC' unless defined $label;
  $spec = $predicates_spec unless defined $spec;
  my $self = {LOGGER => $logger};
  bless($self, $class);
  $self->add_predicates($label, $spec) if defined $spec;
  $self;
}

# Populate the predicates tables from $predicates, which is defined at
# the top of this file, or from a user-defined specification
sub add_predicates {
  my ($self, $label, $spec) = @_;
  chomp $spec;
  foreach (grep {!/^\s*#/} split(/\n/, lc $spec)) {
    my ($domain, $name, $range, $inverse) = split;
    # The "single-valued" marker (asterisk) is handled by Predicate->new
    my $predicate = Predicate->new($self, $domain, $name, $range, $inverse, $label);
    $self->add_predicate($predicate);
  }
  $self;
}

sub add_predicate {
  my ($self, $predicate) = @_;
  # Don't duplicate predicates
  foreach my $existing (@{$self->{$predicate->{NAME}}}) {
    return if $predicate == $existing;
  }
  push(@{$self->{$predicate->{NAME}}}, $predicate);
}

# Find the correct predicate name for this (verb, subject, object)
# triple, performing a variety of error checks
sub get_predicate {
  # The source appears as the last argument passed; preceding
  # arguments are not necessarily present
  my $source = pop(@_);
  my ($self, $verb, $subject_type, $object_type) = @_;
  return $verb if ref $verb;
  $subject_type = lc $subject_type if defined $subject_type;
  $object_type = lc $object_type if defined $object_type;
  my $domain_string = $subject_type;
  my $range_string = $object_type;
  if ($verb =~ /^(.*?):(.*)$/) {
    $domain_string = lc $1;
    $verb = $2;
    unless($PredicateSet::legal_entity_types{$domain_string}) {
      $self->{LOGGER}->record_problem('ILLEGAL_PREDICATE_TYPE', $domain_string, $source);
      return;
    }
  }
  if (defined $domain_string &&
      defined $subject_type &&
      $PredicateSet::legal_entity_types{$subject_type} &&
      $domain_string ne $subject_type) {
    $self->{LOGGER}->record_problem('SUBJECT_PREDICATE_MISMATCH',
				    $subject_type,
				    $domain_string,
				    $source);
    return;
  }
  $verb = $self->rewrite_predicate($verb, $domain_string || $subject_type || 'any', $source);
  my @candidates = $self->lookup_predicate($verb, $domain_string, $range_string);
  unless (@candidates) {
    $self->{LOGGER}->record_problem('ILLEGAL_PREDICATE', $verb, $source);
    return 'undefined';
  }
  return $candidates[0] if @candidates == 1;
  $self->{LOGGER}->record_problem('AMBIGUOUS_PREDICATE', $verb, $source);
  return 'ambiguous';
}

# Rewrite this predicate name if it is an alias
sub rewrite_predicate {
  my ($self, $predicate, $domain, $source) = @_;
  my $alias = $predicate_aliases{lc $domain}{$predicate} ||
              $predicate_aliases{'any'}{$predicate};
  return $predicate unless defined $alias;
  $self->{LOGGER}->record_problem('PREDICATE_ALIAS',
				  $alias->{REASON},
				  $predicate,
				  $alias->{REPLACEMENT},
				  $source);
  $alias->{REPLACEMENT};
}

# Load predicates from a file. This allows additional user-defined predicates.
sub load {
  my ($self, $filename) = @_;
  my $base_filename = $filename;
  $base_filename =~ s/.*\///;
  $self->{LOGGER}->NIST_die("Filename for predicates files should be <label>.predicates.txt")
    unless $base_filename =~ /^(\w+)\.predicates.txt$/;
  my $label = uc $1;
  open(my $infile, "<:utf8", $filename)
    or $self->{LOGGER}->NIST_die("Could not open $filename: $!");
  local($/);
  my $predicates = <$infile>;
  close $infile;
  $self->add_predicates($label, $predicates);
}

#####################################################################################
# Predicate
#####################################################################################

package Predicate;

# Create a new Predicate object
sub new {
  my ($class, $predicates, $domain_string, $original_name, $range_string, $original_inverse_name, $label) = @_;
  # Convert the comma-separated list of types to a hash
  my $domain = {map {$_ => 'true'} split(/,/, lc $domain_string)};
  # Make sure each type is legal
  foreach my $type (keys %{$domain}) {
    $predicates->{LOGGER}->NIST_die("Illegal domain type: $type")
      unless $PredicateSet::legal_entity_types{$type};
  }
  # Do the same for the range
  my $range = {map {$_ => 'true'} split(/,/, lc $range_string)};
  foreach my $type (keys %{$range}) {
    $predicates->{LOGGER}->NIST_die("Illegal range type: $type")
      unless $PredicateSet::legal_range_types{$type};
  }
  my $name = $original_name;
  my $inverse_name = $original_inverse_name;
  my $quantity = 'list';
  my $inverse_quantity = 'list';
  # Single-valued slots are indicated by a trailing asterisk in the predicate name
  if ($name =~ /\*$/) {
    substr($name, -1, 1, '');
    $quantity = 'single';
  }
  if ($inverse_name =~ /\*$/) {
    substr($inverse_name, -1, 1, '');
    $inverse_quantity = 'single';
  }
  # If this predicate has already been defined, make sure that
  # definition is compatible with the current one, then return it
  my @predicates = $predicates->lookup_predicate($name, $domain, $range);
  $predicates->{LOGGER}->NIST_die("More than one predicate defined for " .
				  "$name($domain_string, $range_string)")
    if @predicates > 1;
  my $predicate;
  if (@predicates) {
    $predicate = $predicates[0];
    my $current_inverse_name = $predicate->get_inverse_name();
    $predicates->{LOGGER}->NIST_die("Attempt to redefine inverse of predicate " .
				    "$domain_string:$name from $current_inverse_name " .
				    "to $inverse_name")
      unless $current_inverse_name eq $inverse_name;
    $predicates->{LOGGER}->NIST_die("Attempt to redefine quantity of predicate " .
				    "$domain_string:$name from $predicate->{QUANTITY} " .
				    "to $quantity")
	unless $predicate->{QUANTITY} eq $quantity;
    my @inverses = $predicates->lookup_predicate($inverse_name, $range, $domain);
    $predicates->{LOGGER}->NIST_die("Multiple inverses with form " .
				    "$inverse_name($range_string, $domain_string)")
      if (@inverses > 1);
    if (@inverses) {
      my $current_inverse = $inverses[0];
      $predicates->{LOGGER}->NIST_die("Attempt to redefine inverse of $domain_string:$name")
	if defined $predicate->{INVERSE} && $predicate->{INVERSE} ne $current_inverse;
    }
    return $predicate;
  }
  # This predicate has not been defined already, so build it. INVERSE is added below.
  $predicate = bless({NAME         => $name,
		      LABEL        => $label,
		      DOMAIN       => $domain,
		      RANGE        => $range,
		      INVERSE_NAME => $inverse_name,
		      QUANTITY     => $quantity},
		     $class);
  # Save the new predicate in $predicates
  $predicates->add_predicate($predicate);
  # Automatically generate the inverse predicate
  $predicate->{INVERSE} = $class->new($predicates, $range_string,
				      $original_inverse_name, $domain_string,
				      $original_name, $label)
    unless $inverse_name eq 'none';
  $predicate;
}

# Handy selectors
sub get_name {$_[0]->{NAME}}
sub get_domain {$_[0]->{DOMAIN}}
sub get_range {$_[0]->{RANGE}}
sub get_inverse {$_[0]->{INVERSE}}
sub get_inverse_name {$_[0]->{INVERSE_NAME}}
sub get_quantity {$_[0]->{QUANTITY}}

### END INCLUDE Predicates
### BEGIN INCLUDE Scoring

#####################################################################################
##### Equivalence Class Tree
#####################################################################################

package EquivalenceClassTree;

# This class represents a ground truth tree, decorated with
# submissions that are placed at the appropriate node in the
# tree. Each node in the tree represents an equivalence class, and has
# the following fields:
#   ASSESSMENTS: Assessment entries for the equivalence class
#   SUBMISSIONS: Submission entries representing the equivalence class
#   BIN_IS_INCORRECT: Does this bin represent a set of incorrect values
#                     (and thus this is not a true equivalence class).
#                     Note that this value could be calculated by looking
#                     for a zero in the equivalence class name
#   NAME: The name of the equivalence class for this bin
#   QUANTITY: {single, list}
#   ECS: The child nodes of this node, indexed by equivalence class name


# Create a new Equivalence Class tree
sub new {
  my ($class, $logger, $assessments, @assessments) = @_;
  my $self = {
    LOGGER => $logger,
    STATS => {},
    QUERIES => {},
  };
  bless($self, $class);
  $self->add_assessments($assessments, @assessments) if @assessments;
  $self;
}

# Retrieve or create the EquivalenceClassTree node corresponding to a particular assessment
sub get_node_for_assessment {
  my ($self, $assessment, $assessments) = @_;
#&main::dump_structure($assessment, 'Assessment', [qw(LOGGER)]) unless defined $assessment->{VALUE_EC};
  my $ec = $assessment->{VALUE_EC};
  # If the EC is not 0, then it contains all the information necessary to identify the correct node
  return $self->get($ec, $assessment->{QUANTITY}) unless $ec eq '0';
  # A 0 at the top level is handled directly
  return $self->get("$assessment->{FULL_QUERY_ID}:0", $assessment->{QUANTITY}) if $assessment->{QUERY}{LEVEL} == 0;
  # If this is not a top level 0, we need to recreate the entire path
  # down to this zero. First, find the parent assessment
  
  my $parent_assessment = $assessments->get_parent_assessment($assessment->{QUERY_ID});
  # Recursively identify the node corresponding to the parent assessment
  my $parent_node = $self->get_node_for_assessment($parent_assessment, $assessments);
  # and glom a :0 onto the end
  $self->get("$parent_node->{NAME}:0", $assessment->{QUANTITY});
}

## DO NOT INCLUDE
# Removing COMBO
#
#
#sub already_contains {
#  my ($list, $entry) = @_;
#  foreach my $existing (@{$list}) {
#### DO-NOT INCLUDE
#    # FIXME: We could use %matchers here
#    # FIXME: Should we require match on RELATION_PROVENANCE?
#### DO-INCLUDE
#    return 'true' if $existing->{VALUE} eq $entry->{VALUE} &&
#                     $existing->{RELATION_PROVENANCE}->tostring() eq $entry->{RELATION_PROVENANCE}->tostring() &&
#		     $existing->{VALUE_PROVENANCE}->tostring() eq $entry->{RELATION_PROVENANCE}->tostring();
#  }
#  return;
#}
#
### DO INCLUDE


# This routine adds a list of assessments to the tree, building out
# the tree as new nodes are required
sub add_assessments {
  my ($self, $assessments, @assessments) = @_;
  foreach my $assessment (@assessments) {
    $self->{LOGGER}->NIST_die("Submission given as argument to add_assessments") unless $assessment->{TYPE} eq 'ASSESSMENT';
### DO NOT INCLUDE
    # # Only look at correct assessments to build the ground truth tree
    # next unless $assessment->{JUDGMENT} eq 'CORRECT';
    ## next unless $assessment->{VALUE_EC};
### DO INCLUDE
    # Lookup (or create) the correct node
    my $node = $self->get_node_for_assessment($assessment, $assessments);
    
## DO NOT INCLUDE
# Removing COMBO
#
#    next if  &already_contains($node->{ASSESSMENTS}, $assessment);
#
### DO INCLUDE

    # Add this assessment to that node
    push(@{$node->{ASSESSMENTS}}, $assessment);
    # Add the quantity
    $node->{QUANTITY} = $assessment->{TARGET_QUERY}{QUANTITY} unless $node->{QUANTITY};
    # Remember the appropriate tree node in the assessment
    $assessment->{EC_TREE} = $node;
    # Check assessment file for entries that have equivalence class without correct parent entry
    if ($assessment->{JUDGMENT} eq "CORRECT") {
      my $ec = $node->{NAME};
      my @ec_components = split(/:/, $ec);
      my $base_query_id = shift @ec_components;
      if (@ec_components > 1) {
		my $parent_ec = $base_query_id;
		pop @ec_components;
		$parent_ec .= ":". join( ":", @ec_components) if @ec_components;
		my $parent_ectree = $self->get($parent_ec);
		$self->{LOGGER}->NIST_die("Equivalence class without correct parent entry:\n\t$assessment->{LINE}\n")
		  unless grep {$_->{ASSESSMENT} eq "CORRECT" || $_->{ASSESSMENT} eq "INEXACT"} @{$parent_ectree->{ASSESSMENTS}};
      }
    }
  }
}

# Add a submission to the appropriate node in the tree, using the
# corresponding assessment (we require the equivalence class and
# assessment as input so that finding the appropriate assessment is
# localized to EvaluationQueryOutput
sub add_submission {
### DO NOT INCLUDE
  # FIXME: We should add a submission only if any lower-hop submissions that lead up to it are present
### DO INCLUDE
  my ($self, $submission, $ec, $assessment) = @_;
  $self->{LOGGER}->NIST_die("Assessment given as argument to add_submission") unless $submission->{TYPE} eq 'SUBMISSION';
  if ($assessment) {
    $submission->{ASSESSMENT} = $assessment;
    my $ec_tree = $assessment->{EC_TREE};
    if ($ec_tree) {
      # Added &already_contains throughout to support UNION scoring
      push(@{$ec_tree->{SUBMISSIONS}}, $submission) 
## DO NOT INCLUDE
# Removing COMBO
#
#
#      		unless &already_contains($ec_tree->{SUBMISSIONS}, $submission)
#
### DO INCLUDE
      ;
    }
    else {
      # An assessment with no associated ec_tree has no equivalence class, and is
      # therefore incorrect
      my $node = $self->get($ec, $assessment->{QUANTITY});
      push(@{$node->{SUBMISSIONS}}, $submission) 
## DO NOT INCLUDE
# Removing COMBO
#
#
#      		unless &already_contains($node->{SUBMISSIONS}, $submission)
#
### DO INCLUDE
      ;
    }
  }
  else {
    # If no assessment is found, treat the submission as incorrect. If
    # this is not the desired behavior, it's probably better to fix it
    # in &get_ground_truth_for_submission rather than here
    $self->{STATS}{NUM_UNASSESSED}++;
    my $node = $self->get($ec, $submission->{QUANTITY});
    push(@{$node->{SUBMISSIONS}}, $submission) 
## DO NOT INCLUDE
# Removing COMBO
#
#
#      		unless &already_contains($node->{SUBMISSIONS}, $submission)
#
### DO INCLUDE
    ;
  }
}

# Get (or create) the node of the tree that corresponds to a
# particular equivalence class
sub get {
  my ($self, $ec, $quantity) = @_;
  # Don't create a single top-level error class
### DO NOT INCLUDE
  # FIXME: Might want to report attempt to use old style assessment file here
### DO INCLUDE
  # The equivalence class name encodes the path to the correct node
  my @ec_components = split(/:/, $ec);
  my $full_queryid = shift @ec_components;  
  my ($query_id_base, $query_id, $level, $expanded) 
  		= &Query::parse_queryid($full_queryid);  
  # Look up or create the node for this top level query
  my $result = $self->{QUERIES}{$full_queryid} || {QUANTITY => $quantity};
  $self->{QUERIES}{$full_queryid} = $result;
  # At each step down through the tree we add one component to the
  # current equivalence class name
  my $name = $full_queryid;
#  my $name = $query_id;
  # Keep track of whether this node represents incorrect entries (and
  # thus is not truly an equivalence class, but rather a set of
  # unrelated incorrect answers)
  my $bin_is_incorrect;
  while (@ec_components) {
    # A bin represents incorrect answers if it or any of its ancestors
    # has equivalence class 0
    $bin_is_incorrect = 'true' if $ec_components[0] eq '0';
    # Add on to the name to get the name of the current equivalence class
    $name .= ":" . shift @ec_components;
    # Look up or create the tree node for this equivalence class
    my $nextlevel = $result->{ECS}{$name} ||
      {BIN_IS_INCORRECT => $bin_is_incorrect, NAME => $name};
    $result->{ECS}{$name} = $nextlevel;
    $result = $nextlevel;
  }
  $result;
}

# Calculate all scores for a portion of the ground truth tree
sub score_subtree {
  my ($self, $name, $subtree, $runid, $policy_options, $policy_selected) = @_;
  # This is a bit of a cheesy hack to get the level
  my @colons = $name =~ /(:)/g;
  my $level = @colons;
  # Score each subtree rooted here
  while (my ($child_name, $child_tree) = each %{$subtree->{ECS}}) {
    $self->score_subtree($child_name, $child_tree, $runid, $policy_options, $policy_selected);
  }
  # Build a score for this node
  my $score = Score->new();
  $score->put('EC', $name);
  $score->put('RUNID', $runid);
  $score->put('LEVEL', $level);
  # Ground truth is the number of distinct ECs, or one if this is a single-valued field
  my $num_ground_truth = grep {!$subtree->{ECS}{$_}{BIN_IS_INCORRECT}} keys %{$subtree->{ECS}};
### DO NOT INCLUDE
  # FIXME: Why whouldn't QUANTITY be defined?
### DO INCLUDE
  $num_ground_truth = 1 
  		if defined $subtree->{QUANTITY} 
  			&& $subtree->{QUANTITY} eq 'single' && $num_ground_truth > 1;
  			
  my ($num_incorrect, $num_correct, $num_redundant, $num_submitted, $num_inexact, 
  		$num_unassessed, $num_incorrect_parent, $num_right, $num_wrong, $num_ignored)
  			= (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  # Look through the submissions for this node
  my %categorized_submissions;
  foreach my $ec (keys %{$subtree->{ECS}}) {
    # Gather stats for this EC independently in case we want to report stats by EC
    my %ec_categorized_submissions = $self->categorize_submissions($ec, $policy_options, $policy_selected);
	push(@{$ec_categorized_submissions{'SUBMITTED'}}, @{$subtree->{ECS}{$ec}{SUBMISSIONS} || []});
    
    foreach my $key(keys %ec_categorized_submissions) {
    	push(@{$categorized_submissions{$key}}, @{$ec_categorized_submissions{$key}});
    } 
  }
  if (defined $subtree->{QUANTITY} && $subtree->{QUANTITY} eq 'single' && @{$categorized_submissions{'RIGHT'} || []}) {
  	my $right_submission = pop @{$categorized_submissions{RIGHT}};
  	push(@{$categorized_submissions{REDUNDANT}}, @{$categorized_submissions{RIGHT}});
  	
  	delete $categorized_submissions{RIGHT};
  	push (@{$categorized_submissions{RIGHT}}, $right_submission);
  	
  	# Categorize RIGHT, WRONG and IGNORED 
  	my @post_policy_metrics = qw(RIGHT WRONG IGNORE);
  
  	# Categorize REDUNDANT into RIGHT, WRONG and IGNORED
  	my $selected_duplicate_category;
  	foreach my $post_policy_metric(@post_policy_metrics) {
  	  if($policy_selected->{$post_policy_metric} =~ /DUPLICATE/) {
  	  	$selected_duplicate_category = $post_policy_metric;
  	  }
  	}
  	push(@{$categorized_submissions{$selected_duplicate_category}}, @{$categorized_submissions{REDUNDANT}});
  }
  
  
  # Ignore the correct entry if the mention was a nominal but a named mention exists somewhere
  # This rule came in 2016
  # Begin
  
  my @right;
  my $altered = 0;
  foreach my $submission( @{$categorized_submissions{'RIGHT'} || []} ) {
  	next if not exists $submission->{ASSESSMENT}{VALUE_MENTION_TYPE}
  		or not exists $submission->{ASSESSMENT}{EC_MENTION_TYPE};
  	$altered = 1;
  	my $value_mention_type = $submission->{ASSESSMENT}{VALUE_MENTION_TYPE};
  	my $ec_mention_type = $submission->{ASSESSMENT}{EC_MENTION_TYPE};
  	$ec_mention_type = "NAM" if $ec_mention_type ne "NOM";
  	if($value_mention_type eq "NOM" && $ec_mention_type eq "NAM") {
  		push(@{$categorized_submissions{'IGNORE'}}, $submission);
  	}
  	else{
  		push(@right, $submission);
  	}
  }
  @{$categorized_submissions{'RIGHT'}} = @right if $altered;
  
  # End

  $num_correct = @{$categorized_submissions{'CORRECT'} || []};
  $num_ignored = @{$categorized_submissions{'IGNORE'} || []};
  $num_incorrect = @{$categorized_submissions{'INCORRECT'} || []};
  $num_incorrect_parent = @{$categorized_submissions{'INCORRECT_PARENT'} || []};
  $num_inexact = @{$categorized_submissions{'INEXACT'} || []};
  $num_redundant = @{$categorized_submissions{'REDUNDANT'} || []};
  $num_right = @{$categorized_submissions{'RIGHT'} || []};
  $num_submitted = @{$categorized_submissions{'SUBMITTED'} || []};
  $num_unassessed = @{$categorized_submissions{'UNASSESSED'} || []};
  $num_wrong = @{$categorized_submissions{'WRONG'} || []};

  # Add the counts to the Score, and store it in the tree
  $score->put('CATEGORIZED_SUBMISSIONS', \%categorized_submissions);
  $score->put('NUM_CORRECT', $num_correct);
  $score->put('NUM_GROUND_TRUTH', $num_ground_truth);
  $score->put('NUM_IGNORED', $num_ignored);
  $score->put('NUM_INCORRECT', $num_incorrect);
  $score->put('NUM_INCORRECT_PARENT', $num_incorrect_parent);
  $score->put('NUM_INEXACT', $num_inexact);
  $score->put('NUM_REDUNDANT', $num_redundant);
  $score->put('NUM_RIGHT', $num_right);
  $score->put('NUM_SUBMITTED', $num_submitted);
  $score->put('NUM_WRONG', $num_wrong);
  $score->put('NUM_UNASSESSED', $num_unassessed);
  $score->put('QUANTITY', $subtree->{QUANTITY});
  $subtree->{SCORE} = $score;
}

# To categorize submissions
# In addition to keeping count of various categories the output of this 
# function would help in verbose output.

sub categorize_submissions {
  my ($self, $ec, $policy_options, $policy_selected) = @_;
  my %retVal;
  my $subtree = $self->get($ec);
  foreach my $submission ( @{$subtree->{SUBMISSIONS} || []} ) {
    if(!$self->is_path_correct($ec, $submission->{QUERY_ID})) {
      # record that the (grand-)parent is incorrect
      push(@{$retVal{INCORRECT_PARENT}}, $submission);
    }
    else{
      if(not exists $submission->{ASSESSMENT}) {
      	# record that the entry is unassessed
      	push(@{$retVal{UNASSESSED}}, $submission);
      }
      else{
      	# record the entry with its assessment
      	push(@{$retVal{$submission->{ASSESSMENT}{ASSESSMENT}}}, $submission);
      }    	
    }
  }
  
  # Categorize RIGHT, WRONG and IGNORED 
  my @post_policy_metrics = qw(RIGHT WRONG IGNORE);
  foreach my $post_policy_metric(@post_policy_metrics) {
  	my @selected_options = split(":", $policy_selected->{$post_policy_metric});
  	foreach my $selected_option(@selected_options) {
  	  push(@{$retVal{$post_policy_metric}}, @{$retVal{$selected_option}}) 
  	  	if $retVal{$selected_option};
  	}
  }
  
  # Categorize REDUNDANT based on post-policy RIGHT submissions
  if($retVal{RIGHT} && @{$retVal{RIGHT}} > 1) {
    my @named_mentions = @{$retVal{RIGHT}};
    my @nominal_mentions = [];

    if( grep {exists $_->{ASSESSMENT}{VALUE_MENTION_TYPE}} @{$retVal{RIGHT}} ){
      @named_mentions = grep {$_->{ASSESSMENT}{VALUE_MENTION_TYPE} ne "NOM"} @{$retVal{RIGHT}};
      @nominal_mentions = grep {$_->{ASSESSMENT}{VALUE_MENTION_TYPE} eq "NOM"} @{$retVal{RIGHT}};
    }

	# Prefer a named_mention over nominal
    $retVal{RIGHT} = @named_mentions ? [shift @named_mentions] : [shift @nominal_mentions];

    push(@{$retVal{REDUNDANT}}, @named_mentions);
    push(@{$retVal{REDUNDANT}}, @nominal_mentions);
  }
  
  # Categorize REDUNDANT into RIGHT, WRONG and IGNORED
  if($retVal{REDUNDANT}) {
  	my $selected_duplicate_category;
  	foreach my $post_policy_metric(@post_policy_metrics) {
  	  if($policy_selected->{$post_policy_metric} =~ /DUPLICATE/) {
  	    $selected_duplicate_category = $post_policy_metric;
  	  }
  	}
  	push(@{$retVal{$selected_duplicate_category}}, @{$retVal{REDUNDANT}});
  }
  
  %retVal;
}

# To determine correctness of the path of a submission
sub is_path_correct {
  my ($self, $ec, $query_id) = @_;
  my @ec_components = split(/:/, $ec);
  my $base_query_id = shift @ec_components;
  # The path is correct if you hit the top node
  return 'true' if @ec_components == 1;
  my $parent_ec = $base_query_id;
  pop @ec_components;
  $parent_ec .= ":". join(":", @ec_components) if @ec_components;
  my $parent_ectree = $self->get($parent_ec);
  foreach my $parent_submission (@{$parent_ectree->{SUBMISSIONS} || []} ) {
    # Parent submission must not only be correct but its path should also be correct
    # Check this recursively
    if ($parent_submission->{ASSESSMENT}{JUDGMENT} eq 'CORRECT' &&
	$parent_submission->{TARGET_QUERY_ID} eq $query_id) {
      return $self->is_path_correct($parent_ec, $parent_submission->{QUERY_ID});
    }
    elsif ($parent_submission->{TARGET_QUERY_ID} eq $query_id) {
      return 0;
    }
  }
}

# To score a set of queries, score the subtree for each query
sub score {
  my ($self, $runid, $policy_options, $policy_selected) = @_;
  foreach my $query_id (keys %{$self->{QUERIES}}) {
    $self->score_subtree($query_id, $self->{QUERIES}{$query_id}, $runid, $policy_options, $policy_selected);
  }
}

# Build a list of all the scores found in this tree
sub get_all_subtree_scores {
  my ($tree) = @_;
  my @result;
  # First, recursively collect scores from this tree's subtrees
  foreach my $subtree (values %{$tree->{ECS}}) {
    push(@result, &get_all_subtree_scores($subtree));
  }
  # Now add the score for this node
### DO NOT INCLUDE
  # FIXME: Need to know the hash actually exists
### DO INCLUDE
  push(@result, $tree->{SCORE}) if scalar keys %{$tree->{ECS}};
  @result;
}

# Build a list of all scores from all queries
sub get_all_scores {
  my ($self) = @_;
  my @result;
  foreach my $query_id (keys %{$self->{QUERIES}}) {
    push(@result, &get_all_subtree_scores($self->{QUERIES}{$query_id}));
  }
  @result;
}

### END INCLUDE Scoring
### BEGIN INCLUDE EvaluationQueryOutput

#####################################################################################
##### Evaluation Query Output
#####################################################################################

# This class is used to represent Slot Filling Variant output, the
# result of applying evaluation queries to a knowledge base, and
# assessment output from LDC

package EvaluationQueryOutput;

my $comments_allowed;

sub enable_comments {
  $comments_allowed = 'true';
}

sub disable_comments {
  $comments_allowed = undef;
}

# Maps LDC judgments to one of {CORRECT, INCORRECT, IGNORE, NOT_ASSESSED}
my %correctness_map = (
  CORRECT =>       'CORRECT',
  INCORRECT =>     'INCORRECT',
  INEXACT =>       'INCORRECT',
  INEXACT_SHORT => 'INCORRECT',
  INEXACT_LONG =>  'INCORRECT',
  IGNORE =>        'IGNORE',
  NOT_ASSESSED =>  'NOT_ASSESSED',
);

# The schemas for the submission and assessment files have changed
# over the years. This table specifies each such format, and allows
# code that calculates or normalizes fields
my %schemas = (
### DO NOT INCLUDE
#   '2012submissions' => {
#     YEAR => 2012,
#     TYPE => 'SUBMISSION',
#     SAMPLES => ["01284_78128269	CS_ENG_000_00	NIL	org:employees	PENN_SAS_ENG_24177	DEAN	203	206	259	403",
# 	       ],
#     COLUMNS => [qw(
#       ID
#       QUERY_AND_HOP
#       PARENT_ID
#       SLOT_NAME
#       DOCID
#       VALUE
#       OBJECT_OFFSET_START
#       OBJECT_OFFSET_END
#       PREDICATE_OFFSET_START
#       PREDICATE_OFFSET_END
#     )],
#   },

#   '2012assessments' => {
#     YEAR => 2012,
#     TYPE => 'ASSESSMENT',
#     SAMPLES => ["T03357	CS_ENG_000_01	T00784	per:title	PENN_SAS_ENG_07905	dean	1354	1357	1329	1626	1	3	CS_ENG_000_entity2",
# 	       ],
#     COLUMNS => [qw(
#       ID
#       QUERY_AND_HOP
#       PARENT_ID
#       SLOT_NAME
#       DOCID
#       VALUE
#       OBJECT_OFFSET_START
#       OBJECT_OFFSET_END
#       PREDICATE_OFFSET_START
#       PREDICATE_OFFSET_END
#       VALUE_ASSESSMENT
#       RELATION_ASSESSMENT
#       VALUE_EC
#     )],
#     COLUMN_TO_JUDGE => 'OBJECT_ASSESSMENT',
#     ASSESSMENT_CODES => {
#       '-1' => 'WRONG',
#        '1' => 'CORRECT',
#        '3' => 'INEXACT',
#        '4' => 'NOT_ASSESSED',
#     },
#   },

#   '2013submissions' => {
#     YEAR => 2013,
#     TYPE => 'SUBMISSION',
#     SAMPLES => ["0000085	CS13_ENG_001_00	1334360640-319fafbb063007185528cf40af76e4bc	QUERY	John Lofgren	223-234	223-234	223-336",
# 		"0003967	CS13_ENG_001_PSEUDO_02	1334360640-319fafbb063007185528cf40af76e4bc	QUERY	director	260-267	223-234	223-336",
# 	       ],
#     COLUMNS => [qw(
#       ID
# ;Id8elvis
# ;      QUERY_AND_HOP
#       DOCID
#       PARENT_ID
#       VALUE
#       OBJECT_OFFSETS
#       SUBJECT_OFFSETS
#       PREDICATE_OFFSETS
#     )],
#   },

#   '2013assessments' => {
#     YEAR => 2013,
#     TYPE => 'ASSESSMENT',
#     SAMPLES => ["0000085	CS13_ENG_001_00	1334360640-319fafbb063007185528cf40af76e4bc	QUERY	John Lofgren	223-234	223-234	223-336	C	W	L	C	2",
# 		"0003967	CS13_ENG_001_PSEUDO_02	1334360640-319fafbb063007185528cf40af76e4bc	QUERY	director	260-267	223-234	223-336	C	C	C	C	2",
# 	       ],
#     COLUMNS => [qw(
#       ID
#       QUERY_AND_HOP
#       DOCID
#       PARENT_ID
#       VALUE
#       OBJECT_OFFSETS
#       SUBJECT_OFFSETS
#       PREDICATE_OFFSETS
#       OBJECT_ASSESSMENT
#       SUBJECT_ASSESSMENT
#       RELATION_ASSESSMENT
#       VALUE_ASSESSMENT
#       VALUE_EC
#     )],
#     COLUMN_TO_JUDGE => 'VALUE_ASSESSMENT',
#     ASSESSMENT_CODES => {
#       C => 'CORRECT',
#       W => 'WRONG',
#       X => 'INEXACT',
#       I => 'IGNORE',
#       S => 'INEXACT_SHORT',
#       L => 'INEXACT_LONG',
#     },
#   },
### DO INCLUDE
  '2014SFsubmissions' => {
    YEAR => 2014,
    TYPE => 'SUBMISSION',
    SAMPLES => ["CS14_ENG_003	per:other_family	hltcoe1-tinykb	NYT_ENG_20101103.0024:705-834	George Hickenlooper	NYT_ENG_20101103.0024:815-833	1.0"],
    COLUMNS => [qw(
      QUERY_ID
      SLOT_NAME
      RUNID
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_PROVENANCE_TRIPLES
      CONFIDENCE
    )],
  },

  '2014-2015assessments' => {
    YEAR => "2014:2015",
    TYPE => 'ASSESSMENT',
    SAMPLES => ["000001	CS14_ENG_003:per:other_family	NYT_ENG_20101103.0024:705-834	George Hickenlooper	NYT_ENG_20101103.0024:815-833	C	C	1",
                "CSSF15_ENG_091cbb89ca_0_014	CSSF15_ENG_091cbb89ca:per:schools_attended	f797cc01eec730a6139c010f44409cb0:834-844	Harvard	f797cc01eec730a6139c010f44409cb0:838-844	C	S	CSSF15_ENG_091cbb89ca:1",
		"CSSF15_ENG_091cbb89ca_0_007	CSSF15_ENG_091cbb89ca:per:schools_attended	93fe47faea9e03a0ce683f69e932ad6a:131-280	Harvard	93fe47faea9e03a0ce683f69e932ad6a:291-297	W	W	0"],
    COLUMNS => [qw(
      ASSESSMENT_ID
      QUERY_AND_SLOT_NAME
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_PROVENANCE_TRIPLES
      VALUE_ASSESSMENT
      PROVENANCE_ASSESSMENT
      VALUE_EC
    )],
    COLUMN_TO_JUDGE => 'VALUE_ASSESSMENT',
    ASSESSMENT_CODES => {
      C => 'CORRECT',
      W => 'INCORRECT',
      X => 'INEXACT',
      I => 'IGNORE',
      S => 'INEXACT_SHORT',
      L => 'INEXACT_LONG',
    },
  },

  '2014-2015-expanded-assessments' => {
    YEAR => "2014:2015",
    TYPE => 'ASSESSMENT',
    SAMPLES => [],
    COLUMNS => [qw(
      ASSESSMENT_ID
      LDC_QUERY_ID
      QUERY_AND_SLOT_NAME
      SUBJECT
      SUBJECT_PROVENANCE_TRIPLE
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_PROVENANCE_TRIPLES
      VALUE_ASSESSMENT
      PROVENANCE_ASSESSMENT
      VALUE_EC
    )],
    COLUMN_TO_JUDGE => 'VALUE_ASSESSMENT',
    ASSESSMENT_CODES => {
      C => 'CORRECT',
      W => 'INCORRECT',
      X => 'INEXACT',
      I => 'IGNORE',
      S => 'INEXACT_SHORT',
      L => 'INEXACT_LONG',
    },
  },

  '2016assessments' => {
    YEAR => "2016",
    TYPE => 'ASSESSMENT',
    SAMPLES => [],
    COLUMNS => [qw(
      ASSESSMENT_ID
      QUERY_AND_SLOT_NAME
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_PROVENANCE_TRIPLES
      VALUE_ASSESSMENT
      VALUE_MENTION_TYPE
      PROVENANCE_ASSESSMENT
      VALUE_EC
      EC_MENTION_TYPE
    )],
    COLUMN_TO_JUDGE => 'VALUE_ASSESSMENT',
    ASSESSMENT_CODES => {
      C => 'CORRECT',
      W => 'INCORRECT',
      X => 'INEXACT',
      I => 'IGNORE',
      S => 'INEXACT_SHORT',
      L => 'INEXACT_LONG',
    },
  },

  '2015SFsubmissions' => {
    YEAR => 2015,
    TYPE => 'SUBMISSION',
    SAMPLES => ["CS14_ENG_003	per:other_family	hltcoe1-tinykb	NYT_ENG_20101103.0024:705-834	George Hickenlooper	PER	NYT_ENG_20101103.0024:815-833	1.0"],
    COLUMNS => [qw(
      FULL_QUERY_ID
      SLOT_NAME
      RUNID
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_TYPE
      VALUE_PROVENANCE_TRIPLES
      CONFIDENCE
    )],
  },

);

# Build a pattern that will recognize assessment codes (we just build
# a single one for all years)
my %all_assessment_codes;
foreach my $schema (values %schemas) {
  next unless $schema->{ASSESSMENT_CODES};
  foreach my $key (keys %{$schema->{ASSESSMENT_CODES}}) {
    $all_assessment_codes{$key}++;
  }
}
my $assessment_code_string = join("|", keys %all_assessment_codes);
my $assessment_code_pattern = qr/$assessment_code_string/o;
# Build other patterns that will be helpful in recognizing file types
my $provenance_triple_pattern = qr/[^:]+:\d+-\d+/;
my $provenance_triples_pattern = qr/(?:[^:]+:\d+-\d+,){0,3}[^:]+:\d+-\d+/;
my $anything_pattern = qr/.+/;
my $digits_pattern = qr/\d+/;

# Build inverse assessment code tables
foreach my $schema (values %schemas) {
  next unless $schema->{ASSESSMENT_CODES};
  $schema->{INVERSE_ASSESSMENT_CODES} = {};
  while (my ($key, $value) = each %{$schema->{ASSESSMENT_CODES}}) {
    $schema->{INVERSE_ASSESSMENT_CODES}{$value} = $key;
  }
}

# Columns in an EvaluationQueryOutput. Some columns are read from
# submission or assessment files; others are generated. Each TAC year
# thus far has used a slightly different inventory of columns. Our
# purpose here is to allow each year's submissions and assessments to
# be read, and to normalize them all so that certain columns may be
# reliably accessed.

# Each column description comprises a subset of the following fields:
#  DESCRIPTION -  documentation for the column; not used programmatically
#  YEARS -        documentation for the column; not used programmatically
#  PATTERN -      A pattern that will match the column with 100% recall (but
#                 not necessarily 100% precision)
#  GENERATOR -    A function that will generate the appropriate column value
#  DEPENDENCIES - A list of other columns that must be present before the
#                 generator is invoked
#  REQUIRED -     Is this column required to be filled in? One of {ASSESSMENT,
#                 ALL}. The generator will be invoked if the column is not
#                 present and REQUIRED is ALL, or if REQUIRED is ASSESSMENT
#                 and this is a ground truth entry.

my %columns = (

  ASSESSMENT => {
    # Note: ASSESSMENT is a normalized LDC conclusion; JUDGMENT maps
    # ASSESSMENT onto {CORRECT, INCORRECT, IGNORE, NOT_ASSESSED}
    DESCRIPTION => "{CORRECT, INCORRECT, INEXACT, IGNORE, INEXACT_SHORT, INEXACT_LONG}",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if ($schema->{COLUMN_TO_JUDGE}) {
	my $assessment_code = $entry->{$schema->{COLUMN_TO_JUDGE}};
	my $assessment = $schema->{ASSESSMENT_CODES}{$assessment_code};
	$entry->{ASSESSMENT} = $assessment;
	# Verify that equivalence classes are in synch with CORRECT judgments
	$logger->NIST_die("Correct entry without equivalence class, query = $entry->{QUERY_ID} at line $where->{LINENUM}")
	  if ($assessment eq 'CORRECT' || $assessment eq 'INEXACT') && !$entry->{VALUE_EC};
	$logger->NIST_die("Equivalence class without correct entry, query = $entry->{QUERY_ID}, judgment = $entry->{JUDGMENT}, ec = $entry->{VALUE_EC}")
	  if $assessment ne 'CORRECT' && $assessment ne 'INEXACT' && $entry->{VALUE_EC};
### DO NOT INCLUDE
	# FIXME: Handle duplicate assessment here
### DO INCLUDE
      }
    },
    DEPENDENCIES => [qw(QUERY_ID VALUE_EC)],
    REQUIRED => 'ASSESSMENT',
  },      

  ASSESSMENT_ID => {
    DESCRIPTION => "ID of line in assessments file; probably don't need it",
    YEARS => [2014],
    PATTERN => $anything_pattern,
  },

  COMMENT => {
    DESCRIPTION => "Any comment from the input line; added by load",
  },

  CONFIDENCE => {
    DESCRIPTION => "System confidence in entry, taken from submission",
    YEARS => [2014, 2015],
    # We're lenient here. Guidelines state there must be a decimal
    # point, but we want a warning only for a missing decimal point
    PATTERN => qr/\d+(?:\.\d+(e[-+]?\d\d)?)?/,
    NORMALIZE => sub {
      my ($logger, $where, $value) = @_;
      my $original_value = $value;
      if ($value eq '1') {
	$logger->record_problem('MISSING_DECIMAL_POINT', $value, $where);
	$value = '1.0';
      }
      elsif($value =~ /^\d+\.\d+e[-+]?\d\d$/) {
     $logger->record_problem('IMPROPER_CONFIDENCE_VALUE', $value, $where);
     	$value = sprintf("%.12f", $value);
      }
      unless ($value =~ /^(?:1\.0*)$|^(?:0?\.[0-9]*[1-9][0-9]*)$/) {
	$logger->record_problem('ILLEGAL_CONFIDENCE_VALUE', $original_value, $where);
	$value = '1.0';
      }
      $value;
    },
  },

  DOCID => {
    DESCRIPTION => "Document ID for provenance, from 2012 and 2013 submissions",
    YEARS => [2012, 2013],
    PATTERN => $anything_pattern,
  },

  EC_MENTION_TYPE => {
    DESCRIPTION => "The mention type of the equivalence class",
    YEARS => [2016],
    PATTERN => qr/NAM|NOM|0/i,
  },

  FILENAME => {
    DESCRIPTION => "The name of the file from which the description of the entry was read; added by load",
  },
  
  FULL_QUERY_ID => {
  	DESCRIPTION => "Complete Query ID",
  	PATTERN => $anything_pattern,
  },

  ID => {
    # FIXME
    DESCRIPTION => "ID from ...",
    YEARS => [2012],
    PATTERN => $anything_pattern,
  },

  JUDGMENT => {
    # Note: ASSESSMENT is a normalized LDC conclusion; JUDGMENT maps
    # ASSESSMENT onto {CORRECT, INCORRECT, IGNORE, NOT_ASSESSED}
    DESCRIPTION => "{CORRECT, INCORRECT, IGNORE, NOT_ASSESSED}",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if ($schema->{COLUMN_TO_JUDGE}) {
	$entry->{JUDGMENT} = $correctness_map{$entry->{ASSESSMENT}};
      }
    },
    DEPENDENCIES => [qw(ASSESSMENT)],
    REQUIRED => 'ASSESSMENT',
  },

  LDC_QUERY_ID => {
    DESCRIPTION => "Name of the top-level (multi-entrypoint) query",
    PATTERN => $anything_pattern
  },

  LINE => {
    DESCRIPTION => "the input line that generated this entry - added by load",
  },

  LINENUM => {
    DESCRIPTION => "The line number in FILENAME containing LINE - added by load",  },

  OBJECT_ASSESSMENT => {
    DESCRIPTION => "Additional assessment",
    YEARS => [2013],
    PATTERN => $assessment_code_pattern,
  },

  OBJECT_OFFSETS => {
    DESCRIPTION => "Provenance START and END",
    YEARS => [2013],
    PATTERN => qr/\d+-\d+(?:,\d+-\d+)?/,
  },

  OBJECT_OFFSET_END => {
    DESCRIPTION => "Provenance END",
    YEARS => [2012],
    PATTERN => $digits_pattern,
  },

  OBJECT_OFFSET_START => {
    DESCRIPTION => "Provenance START",
    YEARS => [2012],
    PATTERN => $digits_pattern,
  },

### DO NOT INCLUDE
  # PARENT_EC => {
  #   DESCRIPTION => "The global equivalence class (e.g., Query42:0, Query42:1, or Query42:1:3) this entry fills",
  #   GENERATOR => sub {
  #     my ($logger, $where, $queries, $schema, $entry) = @_;
  #     # FIXME
  #   },
  #   DEPENDENCIES => [qw()],
  #   REQUIRED => 'ASSESSMENT',
  # },

### DO INCLUDE
  PREDICATE_OFFSETS => {
    DESCRIPTION => "Additional provenance START and END",
    YEARS => [2013],
    PATTERN => qr/\d+-\d+(?:,\d+-\d+)?/,
  },

  PREDICATE_OFFSET_END => {
    DESCRIPTION => "Additional provenance END",
    YEARS => [2012],
    PATTERN => $digits_pattern,
  },

  PREDICATE_OFFSET_START => {
    DESCRIPTION => "Additional provenance START",
    PATTERN => $digits_pattern,
  },

  PREDICATE_PROVENANCE => {
    DESCRIPTION => "Provenance supporting entire predicate",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{DOCID} &&
	  defined $entry->{PREDICATE_OFFSET_START} &&
	  defined $entry->{PREDICATE_OFFSET_END}) {
	$entry->{PREDICATE_PROVENANCE} = Provenance->new($logger, $where, 'DOCID_OFFSET_OFFSET',
							 $entry->{DOCID},
							 $entry->{PREDICATE_OFFSET_START},
							 $entry->{PREDICATE_OFFSET_END});
      }
      elsif (defined $entry->{DOCID} &&
	     defined $entry->{PREDICATE_OFFSETS}) {
	$entry->{PREDICATE_PROVENANCE} = Provenance->new($logger, $where, 'DOCID_OFFSETPAIRLIST',
							 $entry->{DOCID},
							 $entry->{PREDICATE_OFFSETS});
      }
    },
    DEPENDENCIES => [qw(DOCID PREDICATE_OFFSET_START PREDICATE_OFFSET_END PREDICATE_OFFSETS)],
  },

  PROVENANCE_ASSESSMENT => {
    DESCRIPTION => "Correctness of value/provenance pair",
    YEARS => [2014],
    PATTERN => $assessment_code_pattern,
  },

  QUANTITY => {
    DESCRIPTION => "{single, list}, depending on whether the slot being filled may have just a single answer or multiple answers",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      # Split the domain name from the slot name
      $entry->{SLOT_NAME} =~ /^(.*?):(.*)$/;
      my $shortname = $2;
### SPEEDUP (Don't do this repeatedly)
      $predicate_set = PredicateSet->new($logger) unless $predicate_set;
### SPEEDUP
      my @candidates = $predicate_set->lookup_predicate($shortname, $entry->{SLOT_TYPE});
      unless (@candidates) {
	$logger->record_problem('UNKNOWN_SLOT_NAME', $entry->{SLOT_NAME}, $where);
	return;
      }
      my $quantity = $candidates[0]{QUANTITY};
      $entry->{QUANTITY} = $quantity;
    },
    DEPENDENCIES => [qw(SLOT_NAME QUERY_ID)],
    REQUIRED => 'ALL',
  },

  QUERY => {
    DESCRIPTION => "A pointer to the appropriate query structure",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      my $query = $queries->get($entry->{QUERY_ID});
      unless (defined $query && $query->get("FULL_QUERY_ID") eq $entry->{FULL_QUERY_ID}) {
	# Generate the query if this is an assessment
#&main::dump_structure($entry, 'Entry', [qw(LOGGER SCHEMA)]);
	$logger->record_problem('UNLOADED_QUERY', $entry->{QUERY_ID}, $where);
	$logger->NIST_die("Query $entry->{FULL_QUERY_ID} not loaded; caller = " . join(":", caller) . "");
      }
      else {
	$entry->{QUERY} = $query;
      }
    },
    DEPENDENCIES => [qw(QUERY_ID)],
    REQUIRED => 'ALL',
  },

  QUERY_AND_HOP => {
    DESCRIPTION => "Query ID concatenated with hop number",
    YEARS => [2012, 2013],
    PATTERN => qr/.+_\d+/,
  },

  QUERY_AND_SLOT_NAME => {
    DESCRIPTION => "Query ID concatenated with slot name",
    YEARS => [2014, 2015],
    PATTERN => qr/.+:.+:.+/,
  },

  QUERY_ID => {
    DESCRIPTION => "Query ID of query this entry is responding to. Explicit in 2014, generated in other years",
    YEARS => [2014, 2015],
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
#print STDERR "QUERY_ID generator: q&h is ", defined $entry->{QUERY_AND_HOP} ? "" : "NOT ", "defined. q&sl is ", defined $entry->{QUERY_AND_SLOT_NAME} ? "" : "NOT ", "defined. q is ", defined $entry->{QUERY} ? "" : "NOT ", "defined.\n";
      if (defined $entry->{QUERY_AND_HOP}) {
	if ($entry->{QUERY_AND_HOP} =~ /^(.*)_PSEUDO_(\d+)$/) {
### DO NOT INCLUDE
	  # FIXME: Should eliminate PSEUDO
### DO INCLUDE
	  $entry->{QUERY_ID} = $entry->{QUERY_AND_HOP};
	}
	elsif ($entry->{QUERY_AND_HOP} =~ /^(.*)_(\d+)$/) {
	  $entry->{QUERY_ID} = $1;
	  $entry->{HOP} = $2;
	}
	else {
	  $logger->NIST_die("Bad query and hop: $entry->{QUERY_AND_HOP}");
	}
      }
      elsif (defined $entry->{QUERY_AND_SLOT_NAME}) {
	$entry->{QUERY_AND_SLOT_NAME} =~ /^(.*?):(.*)$/;
	$entry->{SLOT_NAME} = $2;
	my $full_queryid = $1;
	$entry->{FULL_QUERY_ID} = $full_queryid;
### DO NOT INCLUDE
# Eventually let's separate query_id_base from query_id completely
	# my $query_id_num;
	# ($entry->{QUERY_ID_BASE}, $query_id_num, $entry->{LEVEL}, $entry->{EXPANDED}) =
	#   &Query::parse_queryid($full_queryid);
	# $entry->{QUERY_ID} = "$entry->{QUERY_ID_BASE}_$query_id_num";
### DO INCLUDE
	($entry->{QUERY_ID_BASE}, $entry->{QUERY_ID}, $entry->{LEVEL}, $entry->{EXPANDED}) =
	  &Query::parse_queryid($full_queryid);
      }
      elsif (defined $entry->{FULL_QUERY_ID}) {
      	($entry->{QUERY_ID_BASE}, $entry->{QUERY_ID}, $entry->{LEVEL}, $entry->{EXPANDED}) =
	  &Query::parse_queryid($entry->{FULL_QUERY_ID});
      }
      elsif (defined $entry->{QUERY}) {
      	$entry->{QUERY_ID} = $entry->{QUERY}{QUERY_ID};
      }
    },
    DEPENDENCIES => [qw(QUERY_AND_HOP QUERY_AND_SLOT_NAME)],
    PATTERN => $anything_pattern,
    REQUIRED => 'ALL',
  },

  QUERY_ID_BASE => {
    DESCRIPTION => "The query name stripped of any UUID (We may need to remove _PSEUDO (for 2013 queries) or a UUID (for 2014 queries) to get the base query name)",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      my $full_queryid = $queries->get($entry->{QUERY_ID})->get('FULL_QUERY_ID');
      ($entry->{QUERY_ID_BASE}) = &Query::parse_queryid($full_queryid);
    },
    DEPENDENCIES => [qw(QUERY_ID QUERY)],
    REQUIRED => 'ALL',
  },

  QUERY_UUID => {
    DESCRIPTION => "UUID of source query",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      $entry->{QUERY_UUID} = $entry->{QUERY}{UUID};
    },
    DEPENDENCIES => [qw(QUERY)],
  },

  RELATION_ASSESSMENT => {
    DESCRIPTION => "Additional assessment",
    YEARS => [2012, 2013],
    PATTERN => $assessment_code_pattern,
  },

  RELATION_PROVENANCE => {
    DESCRIPTION => "Provenance for entire relation",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{RELATION_PROVENANCE_TRIPLES}) {
	$entry->{RELATION_PROVENANCE} = Provenance->new($logger, $where, 'PROVENANCETRIPLELIST',
							$entry->{RELATION_PROVENANCE_TRIPLES});
      }
    },
    DEPENDENCIES => [qw(RELATION_PROVENANCE_TRIPLES)],
    REQUIRED => 'ALL',
  },

  RELATION_PROVENANCE_TRIPLES => {
    DESCRIPTION => "Original string representation of RELATION_PROVENANCE",
    YEARS => [2013, 2014, 2015],
    PATTERN => $provenance_triples_pattern,
  },

  RUNID => {
    DESCRIPTION => "Run ID for this entry",
    YEARS => [2014, 2015],
    PATTERN => $anything_pattern,
  },

  SCHEMA => {
    DESCRIPTION => "Entry from \%schemas",
  },

  SLOT_NAME => {
    DESCRIPTION => "The name of the slot being filled by the entry",
    YEARS => [2012, 2014],
    PATTERN => qr/[^:]+:[^:]+/,
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{QUERY_AND_SLOT_NAME}) {
	$entry->{QUERY_AND_SLOT_NAME} =~ /^(.*?):(.*)$/;
	$entry->{FULL_QUERY_ID} = $1;
	$entry->{SLOT_NAME} = $2;
      }
      else {
	$logger->NIST_die("Can't create SLOT_NAME");
      }
    },
    REQUIRED => 'ALL',
  },

  SLOT_TYPE => {
    DESCRIPTION => "{PER, ORG, GPE}",
    DEPENDENCIES => [qw(SLOT_NAME)],
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{SLOT_NAME}) {
	$entry->{SLOT_NAME} =~ /^(.*?):(.*)$/;
	$entry->{SLOT_TYPE} = $1;
      }
      else {
	$logger->NIST_die("Can't create SLOT_TYPE");
      }
    },
    REQUIRED => 'ALL',
  },

  SUBJECT_ASSESSMENT => {
    DESCRIPTION => "Additional assessment",
    YEARS => [2013],
    PATTERN => $assessment_code_pattern,
  },

  SUBJECT => {
    DESCRIPTION => "The query string",
    YEARS => [2014, 2015],
    PATTERN => $anything_pattern,
  },

  SUBJECT_OFFSETS => {
    DESCRIPTION => "Provenance offsets for subject of relation",
    YEARS => [2013],
    PATTERN => qr/\d+-\d+(?:,\d+-\d+)?/,
  },

  SUBJECT_PROVENANCE => {
    DESCRIPTION => "Provenance for subject of relation",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{DOCID} &&
	  defined $entry->{SUBJECT_OFFSETS}) {
	$entry->{SUBJECT_PROVENANCE} = Provenance->new($logger, $where, 'DOCID_OFFSETPAIRLIST',
						       $entry->{DOCID},
						       $entry->{SUBJECT_OFFSETS});
      }
    },
    DEPENDENCIES => [qw()],
  },

  SUBJECT_PROVENANCE_TRIPLE => {
    DESCRIPTION => "Provenance for subject of relation",
    PATTERN => $provenance_triple_pattern,
  },

  TARGET_QUERY => {
    DESCRIPTION => "A pointer to the query structure for the query generated from this entry",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      my $query = $queries->get($entry->{TARGET_QUERY_ID});
      unless ($query) {
### DO NOT INCLUDE
#	$logger->record_problem('UNLOADED_QUERY', $entry->{QUERY_ID}, $where);
	# FIXME: die here?
### DO INCLUDE
    	# Add the query corresponding to this entry to the set of queries
#print STDERR "Generating target query for ", $entry->{QUERY}->get("QUERY_ID"), " with value = $entry->{VALUE} and provenance $entry->{VALUE_PROVENANCE}\n";
    	$query = $entry->{QUERY}->generate_query($entry->{VALUE}, $entry->{VALUE_PROVENANCE});
    	$queries->add($query, $entry->{QUERY});	
      }
	  $entry->{TARGET_QUERY} = $query;
    },
    DEPENDENCIES => [qw(TARGET_QUERY_ID QUERY)],
    REQUIRED => 'ALL',
  },

  TARGET_QUERY_ID => {
    DESCRIPTION => "Query ID of query generated from this entry",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      #$entry->{TARGET_QUERY_ID} = "$entry->{QUERY_ID_BASE}_$entry->{TARGET_UUID}";
      $entry->{TARGET_QUERY_ID} = "$entry->{TARGET_UUID}";
    },
    DEPENDENCIES => [qw(QUERY_ID_BASE TARGET_UUID)],
    REQUIRED => 'ALL',
  },

  TARGET_UUID => {
    DESCRIPTION => "UUID of query generated from this entry",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
### DO NOT INCLUDE
      # FIXME: Don't hard-code the 12
### DO INCLUDE
	  my $full_queryid = $queries->get($entry->{QUERY_ID})->get('FULL_QUERY_ID');
      $entry->{TARGET_UUID} = &main::generate_uuid_from_values($full_queryid,
							       $entry->{VALUE},
							       $entry->{VALUE_PROVENANCE}->tostring(),
							       12);
    },
    DEPENDENCIES => [qw(QUERY_ID QUERY VALUE VALUE_PROVENANCE)],
  },

  TYPE => {
    DESCRIPTION => "{ASSESSMENT, SUBMISSION} - from schema",
  },

  VALUE => {
    DESCRIPTION => "The slot fill",
    YEARS => [2012, 2013, 2014, 2015],
    PATTERN => $anything_pattern,
    REQUIRED => 'ALL',
  },

  VALUE_ASSESSMENT => {
    DESCRIPTION => "Correctness of this value",
    YEARS => [2012, 2013, 2014],
    PATTERN => $assessment_code_pattern,
  },

  VALUE_EC => {
    DESCRIPTION => "LDC equivalence class for this value/provenance pair",
    YEARS => [2012, 2013, 2014],
    PATTERN => $anything_pattern,
  },

  VALUE_MENTION_TYPE => {
    DESCRIPTION => "Mention type of this value",
    YEARS => [2016],
    PATTERN => qr/NAM|NOM|0/i,
  },

### DO NOT INCLUDE
  # VALUE_EC_NORMALIZED => {
  #   DESCRIPTION => "Equivalence class for this value/provenance pair, guaranteed to be of the form QID{:\d+}+",
  #   YEARS => [2012, 2013, 2014],
  #   REQUIRED => 'ASSESSMENT',
  #   DEPENDENCIES => [qw(VALUE_EC 

### DO INCLUDE
  VALUE_PROVENANCE => {
    DESCRIPTION => "Where the VALUE was found in the document collection",
    GENERATOR => sub {
      my ($logger, $where, $queries, $schema, $entry) = @_;
      if (defined $entry->{DOCID} &&
	  defined $entry->{OBJECT_OFFSET_START} &&
	  defined $entry->{OBJECT_OFFSET_END}) {
	$entry->{VALUE_PROVENANCE} = Provenance->new($logger, $where, 'DOCID_OFFSET_OFFSET',
						     $entry->{DOCID},
						     $entry->{OBJECT_OFFSET_START},
						     $entry->{OBJECT_OFFSET_END});
      }
      elsif (defined $entry->{DOCID} &&
	       defined $entry->{OBJECT_OFFSETS}) {
	$entry->{VALUE_PROVENANCE} = Provenance->new($logger, $where, 'DOCID_OFFSETPAIRLIST',
						     $entry->{DOCID},
						     $entry->{OBJECT_OFFSETS});
      }
      elsif (defined $entry->{VALUE_PROVENANCE_TRIPLES}) {
	$entry->{VALUE_PROVENANCE} = Provenance->new($logger, $where, 'PROVENANCETRIPLELIST',
						     $entry->{VALUE_PROVENANCE_TRIPLES});
      }
    },
    DEPENDENCIES => [qw(DOCID OBJECT_OFFSET_START OBJECT_OFFSET_END
			OBJECT_OFFSETS VALUE_PROVENANCE_TRIPLES)],
    REQUIRED => 'ALL',
  },

  VALUE_PROVENANCE_TRIPLES => {
    DESCRIPTION => "Original string representation of VALUE_PROVENANCE",
    YEARS => [2013, 2014, 2015],
    PATTERN => $provenance_triples_pattern,
  },
  
  VALUE_TYPE => {
    DESCRIPTION => "{PER, ORG, GPE, STRING}",
    YEARS => [2015],
    PATTERN => qr/^(PER|ORG|GPE|STRING)$/i,
    NORMALIZE => sub {
      my ($logger, $where, $value) = @_;
      $logger->record_problem('ILLEGAL_VALUE_TYPE', $value, $where)
        if ($value !~ qr/^(PER|ORG|GPE|STRING)$/i);
      uc $value;
    },
  },

  YEAR => {
    DESCRIPTION => "TAC year (according to format of submission) - from schema",
  },

);

# Useful during development:
sub display_all_columns {
  my $longest = "";
  foreach my $column (keys %columns) {
    $longest = $column if length($column) > length($longest);
  }
  foreach my $column (sort keys %columns) {
    print "$column:", ' ' x (length($longest) - length($column) + 1),
          $columns{$column}{GENERATOR} ? 'G ' : '  ',
          "$columns{$column}{DESCRIPTION}\n";
  }
}
### DO NOT INCLUDE
# &display_all_columns();
# exit;
### DO INCLUDE

# Try to determine the type of the file containing this line
sub identify_line_type {
  my ($logger, $line) = @_;
  # Go through each tab-separated element, seeing whether it is
  # compatible with the field required by this schema
  my @elements = split(/\t/, $line);
 schema:
  foreach my $type (keys %schemas) {
    my $schema = $schemas{$type};
    next unless @elements == @{$schema->{COLUMNS}};
    my @current_elements = @elements;
    foreach my $column_name (@{$schema->{COLUMNS}}) {
      my $column = $columns{$column_name};
      $logger->NIST_die("Unknown column: $column_name") unless defined $column;
      my $element = shift @current_elements;
      my $pattern = $column->{PATTERN};
      $logger->NIST_die("Internal error: no pattern found for column $column_name")
	unless $pattern;
      next schema unless $element =~ /^$pattern$/;
    }
    return $type;
  }
  return;
}

# Try to determine what type of TSV file this is, based on how the
# first line of entries matches field patterns
sub identify_file_type {
  my ($logger, $filename) = @_;
  open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
  while (<$infile>) {
    chomp;
    # A pound sign at the start of a line is always a comment; later
    # in the line, $comments_allowed must be enabled
    s/^\s*#.*$//;
    my $comment = "";
    if ($comments_allowed) {
      s/$main::comment_pattern/$1/;
      $comment = $2;
    }
    # Skip blank lines
    next unless /\S/;
    # Kill carriage returns (FIXME: We might need to replace them with
    # \ns in some strange Microsoft future)
    s/\r//gs;
    my $type = &identify_line_type($logger, $_);
    $logger->NIST_die("Unknown file type: $filename") unless defined $type;
    close $infile;
    return $type;
  }
  $logger->NIST_die("Empty file: $filename");
}

### DO NOT INCLUDE
#####################################################################
# FIXME: The following patches are in place solely for the original #
# release of the 2014 assessments. When updated assessments are     #
# released by LDC, these patches should probably be removed.        #
#####################################################################

# A UTF-8 encoding error caused a few anomalies in the 2014 assessment
# data; they are corrected by the entries in this table. Necessitates
# use of 'use utf8' at the top of this file
# my %fix_utf8 = (
#   "Blaise CompaorÃ©" => "Blaise Compaoré",
#   "Ahmet ErtegÃ¼n" =>   "Ahmet Ertegün",
#   "Janet MurguÃ­a" =>   "Janet Murguía",
# );

# A few of the original assessment entries are inconsistent; this repairs them
my %repairs = (
#   # Don't conflate MP and representative
#   #002066	CS14_ENG_199_db93190d-f793-3aba-a56d-74e38915589f:per:title	XIN_ENG_20100822.0023:613-760	MP	XIN_ENG_20100822.0023:747-748	C	C	2
#   '002067	CS14_ENG_199_db93190d-f793-3aba-a56d-74e38915589f:per:title	AFP_ENG_20100830.0294:420-569	representative	AFP_ENG_20100830.0294:488-501	C	C	2' =>
#   '002067	CS14_ENG_199_db93190d-f793-3aba-a56d-74e38915589f:per:title	AFP_ENG_20100830.0294:420-569	representative	AFP_ENG_20100830.0294:488-501	C	C	3',
#   '002068	CS14_ENG_199_db93190d-f793-3aba-a56d-74e38915589f:per:title	AFP_ENG_20100830.0294:421-568	representative	AFP_ENG_20100830.0294:488-501	C	C	2' =>
#   '002068	CS14_ENG_199_db93190d-f793-3aba-a56d-74e38915589f:per:title	AFP_ENG_20100830.0294:421-568	representative	AFP_ENG_20100830.0294:488-501	C	C	3',

#   # In other places, 'fellow' and 'research fellow' are not conflated
#   #001631	CS14_ENG_157_249a707e-bee6-360e-8e13-eaf6cf9a4f95:per:title	XIN_ENG_20090929.0273:2794-2885	fellow	XIN_ENG_20090929.0273:2809-2814	C	C	1
#   '001632	CS14_ENG_157_249a707e-bee6-360e-8e13-eaf6cf9a4f95:per:title	AFP_ENG_20100110.0351:3219-3319	research fellow	AFP_ENG_20100110.0351:3238-3252	C	C	1' =>
#   '001632	CS14_ENG_157_249a707e-bee6-360e-8e13-eaf6cf9a4f95:per:title	AFP_ENG_20100110.0351:3219-3319	research fellow	AFP_ENG_20100110.0351:3238-3252	C	C	3',

#   # Ken Pollack and Kenneth Pollack should be conflated
#   #002187	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	eng-NG-31-131701-8426151:2809-2862	Ken Pollack	eng-NG-31-131701-8426151:2809-2819	C	C	34
#   '002191	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	eng-NG-31-126841-8221710:444-482,eng-NG-31-142265-10040928:1464-1507,eng-NG-31-142265-8693536:1463-1506,eng-NG-31-151724-8810400:1521-1564	Kenneth Pollack	eng-NG-31-151724-8810400:1521-1535	C	L	36' =>
#   '002191	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	eng-NG-31-126841-8221710:444-482,eng-NG-31-142265-10040928:1464-1507,eng-NG-31-142265-8693536:1463-1506,eng-NG-31-151724-8810400:1521-1564	Kenneth Pollack	eng-NG-31-151724-8810400:1521-1535	C	L	34',

#   # Conflate Billy and Billy A.
#   #002226	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	APW_ENG_20101116.0207:3602-3658,APW_ENG_20101116.0207:3624-3658,XIN_ENG_20100512.0269:3526-3620,XIN_ENG_20100611.0178:641-713	William A. Galston	APW_ENG_20101116.0207:3214-3231	C	L	58
#   '002229	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	NYT_ENG_20090928.0180:2837-2880,NYT_ENG_20100218.0167:4637-4680,WPB_ENG_20100922.0073:4776-4820,XIN_ENG_20101027.0256:4109-4152	William Galston	NYT_ENG_20090928.0180:2837-2851	C	L	61' =>
#   '002229	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	NYT_ENG_20090928.0180:2837-2880,NYT_ENG_20100218.0167:4637-4680,WPB_ENG_20100922.0073:4776-4820,XIN_ENG_20101027.0256:4109-4152	William Galston	NYT_ENG_20090928.0180:2837-2851	C	L	58',

#   # Conflate Bill and Bill H.
#   #002227	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	NYT_ENG_20100917.0015:3728-3783,WPB_ENG_20100611.0066:2331-2386,WPB_ENG_20101214.0095:2190-2230,WPB_ENG_20101223.0018:3597-3652	William Frey	WPB_ENG_20101214.0095:2190-2201	C	L	59
#   '002230	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	APW_ENG_20101214.0641:835-874,LTW_ENG_20091224.0051:1817-1858,NYT_ENG_20091027.0123:3655-3694	William H. Frey	NYT_ENG_20091027.0123:3655-3669	C	S	62' =>
#   '002230	CS14_ENG_203_645a1602-2395-3e1c-9133-08bd2fd7a293:org:employees_or_members	APW_ENG_20101214.0641:835-874,LTW_ENG_20091224.0051:1817-1858,NYT_ENG_20091027.0123:3655-3694	William H. Frey	NYT_ENG_20091027.0123:3655-3669	C	S	59',

#   # Current inconsistency in judgments
#   #000767  CS14_ENG_099_439f0e71-3388-3890-a09d-79e699a3a5f8:per:title	eng-NG-31-138596-9810529:3460-3605	spokesman	eng-NG-31-138596-9810529:3527-3535	C	C	1
#   '000776	CS14_ENG_099_6252fd06-ab6c-3b1b-88a1-e8f6b01082e4:per:title	eng-NG-31-138596-9810529:3460-3605	spokesman	eng-NG-31-138596-9810529:3527-3535	X	L	0' =>
#   '000776	CS14_ENG_099_6252fd06-ab6c-3b1b-88a1-e8f6b01082e4:per:title	eng-NG-31-138596-9810529:3460-3605	spokesman	eng-NG-31-138596-9810529:3527-3535	C	C	2',

#   # Current inconsistency in judgments
#   #000896  CS14_ENG_117_4ab1e67e-6ac0-3d83-a3b5-ea90266166b3:per:title     XIN_ENG_20100526.0378:914-922,XIN_ENG_20100526.0378:914-922     executive       XIN_ENG_20100526.0378:914-922   C       S       4
#   '000916	CS14_ENG_117_5f8e2951-0ad9-3e1c-8cdb-8b3bb865518f:per:title	XIN_ENG_20100526.0378:914-922,XIN_ENG_20100526.0378:914-922	executive	XIN_ENG_20100526.0378:914-922	X	S	0' =>
#   '000916	CS14_ENG_117_5f8e2951-0ad9-3e1c-8cdb-8b3bb865518f:per:title	XIN_ENG_20100526.0378:914-922,XIN_ENG_20100526.0378:914-922	executive	XIN_ENG_20100526.0378:914-922	C	S	5',
);

# #####################################################################
# # END patches                                                       #
# #####################################################################

### DO INCLUDE
# Generate a slot filler if the slot is required and does not currently have a value.
sub generate_slot {
  my ($logger, $where, $queries, $schema, $entry, $slot) = @_;
#print STDERR "gs($slot)\n";
  return if defined $entry->{$slot};
  my $spec = $columns{$slot};
  $logger->NIST_die("No information available for $slot column") unless defined $spec;
  my $dependencies = $spec->{DEPENDENCIES};
  if (defined $dependencies) {
    foreach my $dependency (@{$dependencies}) {
      &generate_slot($logger, $where, $queries, $schema, $entry, $dependency);
### DO NOT INCLUDE
      # FIXME: Might want to indicate which dependencies are required
### DO INCLUDE
    }
  }
  my $generator = $spec->{GENERATOR};
  if (defined $generator) {
#print STDERR "  calling generator for $slot\n";
    &{$generator}($logger, $where, $queries, $schema, $entry);
#print STDERR "  DONE.\n";
  }
}

# Load an evaluation query output file or an assessment file
sub load {
  my ($self, $logger, $queries, $filename, $schema) = @_;
### DO NOT INCLUDE
#print STDERR ">>>>>>>>>>>>>>>>>> Loading $filename\n";
### DO INCLUDE
  open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
  my $columns = $schema->{COLUMNS};
  input_line:
  while (<$infile>) {
    chomp;
### DO NOT INCLUDE
#    # Repair known problems in the assessment files
#    my $repair = $repairs{$_};
#    $_ = $repair if defined $repair;
### DO INCLUDE
    # Kill carriage returns (FIXME: We might need to replace them with
    # \ns in some strange Microsoft future)
    s/\r//gs;
    # A pound sign at the start of a line is always a comment; later
    # in the line, $comments_allowed must be enabled
    s/^\s*#.*$//;
    # Eliminate comments, ensuring that pound signs in the middle of
    # strings are not treated as comment characters
    my $comment = "";
    if ($comments_allowed) {
      s/$main::comment_pattern/$1/;
      $comment = $2;
    }
    # Skip blank lines
    next unless /\S/;
    # Note the current location for use by the logger
    my $where = {FILENAME => $filename, LINENUM => $.};
    # Align the tab-separated elements on the line with the expected set of columns
    my @elements = split(/\t/);
    if (@elements != @{$columns}) {
### DO NOT INCLUDE
print STDERR "Wrong number of elements: <<", join(">> <<", @elements), ">>\n";
print STDERR "   columns = (<<", join(">> <<", @{$columns}), ">>)\n";
### DO INCLUDE
      $logger->record_problem('WRONG_NUM_ENTRIES', scalar @{$columns}, scalar @elements, $where);
      next;
    }
    my $entry = {map {$columns->[$_] => $elements[$_]} 0..$#elements};

    # Normalize elements
    foreach my $column_name (keys %{$entry}) {
      $entry->{$column_name} = &{$columns{$column_name}{NORMALIZE}}($logger, $where, $entry->{$column_name})
	if defined $columns{$column_name}{NORMALIZE};
    }

    # Remember where this entry came from
    $entry->{LINE} = $_;
    $entry->{FILENAME} = $filename;
    $entry->{LINENUM} = $.;
    $entry->{SCHEMA} = $schema;
    $entry->{COMMENT} = $comment;
    
### DO NOT INCLUDE
#    my $replacement = $fix_utf8{$entry->{VALUE}};
#    $entry->{VALUE} = $replacement if defined $replacement;
#
### DO INCLUDE
    # Remember the year and type of the entry
    $entry->{YEAR} = $schema->{YEAR};
    $entry->{TYPE} = uc $schema->{TYPE};

    # Generate any required slots that don't yet exist
    foreach my $column_name (keys %columns) {
      my $column = $columns{$column_name};
      if ($column->{REQUIRED} &&
	  ($column->{REQUIRED} eq $schema->{TYPE} ||
	   $column->{REQUIRED} eq 'ALL')) {
	&generate_slot($logger, $where, $queries, $schema, $entry, $column_name);
      }
    }

    foreach my $column_name (@{$columns}) {
      unless ($entry->{$column_name} =~ /\S/) {
	$logger->record_problem('EMPTY_FIELD', $column_name, $where);
	$self->{BAD_QUERIES}{$entry->{TARGET_QUERY_ID}}++;
	next input_line;
      }
    }

    # Make sure that the submitted slot matches the slot requested by the query
    if ($entry->{SLOT_NAME} ne $entry->{QUERY}{SLOT}) {
      $logger->record_problem('WRONG_SLOT_NAME', $entry->{SLOT_NAME}, $entry->{QUERY_ID}, $entry->{QUERY}{SLOT}, $where);
      $self->{BAD_QUERIES}{$entry->{TARGET_QUERY_ID}}++;
      next;
    }

    # Keep track of all RUNIDs
    $self->{RUNIDS}{$entry->{RUNID}}++ if defined $entry->{RUNID};
### DO NOT INCLUDE
    # FIXME: Record MULTIPLE_RUNIDS problem here?
### DO INCLUDE
    my $current_runid = $self->get_runid();
    if (defined $current_runid) {
      if (defined $entry->{RUNID} && $entry->{RUNID} ne $current_runid) {
	$logger->record_problem('MULTIPLE_RUNIDS', $current_runid, $entry->{RUNID}, $entry);
### DO NOT INCLUDE
		# Commenting the following line. We don't want to overwrite the RUNID field for entries belonging to different runs.
		# FIXME: Is that OK, Jim?
		    
	    #$entry->{RUNID} = $current_runid;
	    
### DO INCLUDE
      }
    }
    else {
      $self->set_runid($entry->{RUNID});
    }

    # Allow recovery of parent query ID and equivalence class
    if ($entry->{TYPE} eq 'ASSESSMENT' &&
	($entry->{ASSESSMENT} eq 'CORRECT' || $entry->{ASSESSMENT} eq 'INEXACT')) {
      $self->{QUERYID2PARENTASSESSMENT}{$entry->{TARGET_QUERY_ID}} = $entry;
    }

    # Allow recovery of parent query ID for all queries
    $self->{QUERYID2PARENTQUERYID}{$entry->{TARGET_QUERY_ID}} = $entry->{QUERY_ID};

    # Map assessments onto a standard set valid across years
    foreach my $key (keys %{$entry}) {
      next unless $key =~ /_ASSESSMENT$/;
      $entry->{$key} = $schema->{ASSESSMENT_CODES}{$entry->{$key}}
	or $logger->NIST_die("Unknown assessment code: $entry->{$key}");
    }

    push(@{$self->{ENTRIES_BY_TYPE}{$schema->{TYPE}}}, $entry);
    push(@{$self->{ENTRIES_BY_QUERY_ID_BASE}{$schema->{TYPE}}{$entry->{QUERY_ID_BASE}}}, $entry);
    push(@{$self->{ENTRIES_BY_ANSWER}{$entry->{QUERY_ID}}{$entry->{TARGET_QUERY_ID}}{$schema->{TYPE}}}, $entry);
    push(@{$self->{ENTRIES_BY_EC}{$entry->{QUERY_ID}}{$entry->{VALUE_EC}}}, $entry)
	if $entry->{TYPE} eq 'ASSESSMENT' &&
	   ($entry->{ASSESSMENT} eq 'CORRECT' || $entry->{ASSESSMENT} eq 'INEXACT');
    push(@{$self->{ALL_ENTRIES}}, $entry);
### DO NOT INCLUDE
    # Add the query corresponding to this entry to the set of queries
    #my $new_query = $entry->{QUERY}->generate_query($entry->{VALUE}, $entry->{VALUE_PROVENANCE});
    #$queries->add($new_query, $entry->{QUERY});
### DO INCLUDE
  }
  close $infile;
}

sub get_parent_assessment {
  my ($self, $query_id) = @_;
  $self->{QUERYID2PARENTASSESSMENT}{$query_id};
}

sub get_parent_query_id {
  my ($self, $query_id) = @_;
  $self->{QUERYID2PARENTQUERYID}{$query_id};
}

sub query_id2normalized_ec {
  my ($self, $query_id, $discipline) = @_;
  $self->entry2normalized_ec($self->get_parent_assessment($query_id), $discipline);
}
### DO NOT INCLUDE

# sub entry2normalized_ec {
#   my ($self, $entry, $discipline) = @_;
#   # Get the corresponding assessment if this is a submission
#   # FIXME: ggtfs returns two items
#   my $assessment = $entry->{TYPE} eq 'ASSESSMENT' ? $entry : $self->get_ground_truth_for_submission($entry, $discipline);
#   return $assessment->{VALUE_EC} unless $assessment->{VALUE_EC} =~ /^\d+$/;
#   # Only INCORRECT entries should have numeric equivalence classes
#   $self-{LOGGER}->NIST_die("Numeric equivalence class other than zero (probably loaded assessments without global ECs)")
#     if $assessment->{VALUE_EC};
#   my $parent_assessment = $assessments->get_parent_assessment($entry->{QUERY_ID});
#   return "$entry->{QUERY_ID}:0" unless $parent_assessment;
#   return $self->entry2normalized_ec($parent_assessment, $discipline) . ":0";
# }
### DO INCLUDE

sub get_all_runids {
  my ($self) = @_;
  sort keys %{$self->{RUNIDS}};
}

sub get_all_entries {
  my ($self) = @_;
  @{$self->{ALL_ENTRIES}};
}

sub get_all_child_ids {
  my ($self, $query_id) = @_;
  keys %{$self->{ENTRIES_BY_ANSWER}{$query_id}};
}

sub get_submissions_by_child_id {
  my ($self, $query_id, $child_id) = @_;
  @{$self->{ENTRIES_BY_ANSWER}{$query_id}{$child_id}{'SUBMISSION'} || []};
}

# These are the various disciplines that might be used to match a
# submission to a ground truth entry. Any new nugget-based or fuzzy
# matching would go here
my %matchers = (
  ASSESSED => {
    DESCRIPTION => "No match unless this exact entry appears in the assessments",
    MATCHER => sub {
      my ($submission, $assessment) = @_;
      return unless $submission->{QUERY_ID} eq $assessment->{QUERY_ID};
### DO NOT INCLUDE
#      return unless $submission->{QUERY}{LEVEL} == $assessment->{QUERY}{LEVEL};
### DO INCLUDE
      return unless $submission->{VALUE} eq $assessment->{VALUE};
      return unless $submission->{RELATION_PROVENANCE}->tostring() eq $assessment->{RELATION_PROVENANCE}->tostring();
      return unless $submission->{VALUE_PROVENANCE}->tostring() eq $assessment->{VALUE_PROVENANCE}->tostring();
      return 'true';
    },
  },
  STRING_EXACT => {
    DESCRIPTION => "Exact string match, but provenance need not match",
    MATCHER => sub {
### DO NOT INCLUDE
      # FIXME: ECs need to match too. Otherwise, if Bart attended
      # Springfield Elementary but Lisa didn't, nonetheless Lisa would
      # get credit for Springfield Elementary. Find out whether EC
      # matches before this matcher is called.
### DO INCLUDE
      my ($submission, $assessment) = @_;
      return unless $submission->{QUERY_ID_BASE} eq $assessment->{QUERY_ID_BASE};
      return unless $submission->{QUERY}{LEVEL} == $assessment->{QUERY}{LEVEL};
      $submission->{VALUE} eq $assessment->{VALUE};
    },
  },
  STRING_CASE => {
    DESCRIPTION => "String matches modulo case differences; provenance need not match",
    MATCHER => sub {
### DO NOT INCLUDE
      # FIXME: Ditto STRING_EXACT FIXME
### DO INCLUDE
      my ($submission, $assessment) = @_;
      return unless $submission->{QUERY_ID_BASE} eq $assessment->{QUERY_ID_BASE};
      return unless $submission->{QUERY}{LEVEL} == $assessment->{QUERY}{LEVEL};
      lc $submission->{VALUE} eq lc $assessment->{VALUE};
    },
  },
);

# Build a list of all the known disciplines; for documentation
sub get_all_disciplines {
  &main::build_documentation(\%matchers);
}

# Find the assessment that is appropriate for this
# submission. $discipline is from %matchers
sub get_ground_truth_for_submission {
  my ($self, $submission, $discipline) = @_;
  my $ec = $self->entry2parentec($submission);
  my $matcher = $matchers{$discipline};
  $self->{LOGGER}->NIST_die("No matcher called $discipline") unless $matcher;
  my @choices;
  my @assessed_choices;
  # Always prefer assessed choices to matched choices
### DO NOT INCLUDE
  # FIXME: Perhaps there's a better way to index the assessments?
### DO INCLUDE
  foreach my $assessment (grep {$self->entry2parentec($_) eq $ec}
			  @{$self->{ENTRIES_BY_QUERY_ID_BASE}{ASSESSMENT}{$submission->{QUERY_ID_BASE}} || []}) {
    if (&{$matchers{ASSESSED}{MATCHER}}($submission, $assessment)) {
      push(@assessed_choices, $assessment);
    }
    # See whether this answer matches by the matcher, but only if we don't yet have any assessed matches
    elsif (!@assessed_choices && &{$matcher->{MATCHER}}($submission, $assessment)) {
      push(@choices, $assessment);
    }
  }
  # If we found any assessed choices, ignore all the unassessed ones
  if (@assessed_choices) {
    @choices = @assessed_choices;
    $discipline = 'ASSESSED';
  }
  return ($choices[0], $discipline) if @choices == 1;
  return unless @choices;
  my @correct_choices = grep {$_->{VALUE_ASSESSMENT} eq 'CORRECT'} @choices;
  # If there is only one correct assessment, return it
  return ($correct_choices[0], $discipline) if @correct_choices == 1;
  # If there are no correct assessments, return any incorrect assessment
  return ($choices[0], $discipline) unless @correct_choices;
### DO NOT INCLUDE
  # FIXME: Might not fuzzy matching correctly result in this condition?
### DO INCLUDE
  $self->{LOGGER}->record_problem('MULTIPLE_CORRECT_GROUND_TRUTH', $submission->{QUERY_ID}, $submission);
  return ($correct_choices[0], $discipline);
}

# Return the name of the equivalence class for this query ID
sub query_id2ec {
  my ($self, $full_queryid) = @_;
  my ($query_id_base, $query_id, $level, $expanded) 
  		= &Query::parse_queryid($full_queryid); 
  my $query = $self->{QUERIES}->get($query_id);
  if (defined $query->{LEVEL}) {
  return $full_queryid if $query->{LEVEL} == 0;
}
  my $parent_assessment = $self->get_parent_assessment($query_id);
  if ($parent_assessment) {
    return $parent_assessment->{VALUE_EC};
  }
  else {
    # Parent assessment is incorrect, so EC component is 0
    my $parent_query_id = $self->{QUERIES}->get($self->get_parent_query_id($query_id))->get("FULL_QUERY_ID");
    return $self->query_id2ec($parent_query_id) . ":0";
  }
}

# Return the name of the equivalence class for this entry
sub entry2ec {
  my ($self, $entry) = @_;
  $self->query_id2ec($entry->{TARGET_QUERY}->get("FULL_QUERY_ID"));
}

# Return the name of the equivalence class for the parent of this entry
sub entry2parentec {
  my ($self, $entry) = @_;
  $self->query_id2ec($entry->{FULL_QUERY_ID});
}
### DO NOT INCLUDE

# For debugging: prints assessment tree and exits
# &main::dump_structure($tree, 'Tree', [qw(LOGGER SCHEMA RELATION_PROVENANCE VALUE_PROVENANCE PROVENANCE ASSESSMENT_ID EC_TREE FILENAME LINE LINENUM PROVENANCE_ASSESSMENT DOCID START END WHERE LASTSLOT SLOT SLOTS QUERY_AND_SLOT_NAME RELATION_PROVENANCE_TRIPLES TARGET_UUID VALUE_PROVENANCE_TRIPLES YEAR CONFIDENCE QUERY_ID_BASE QUERY RUNID SLOT_NAME SLOT_TYPE TARGET_QUERY VALUE_ASSESSMENT SLOT_NAME)]);
# exit 0;
### DO INCLUDE

## DO NOT INCLUDE
# Removing COMBO
#
#
#my %combo_options = (
#  MICRO => {DESCRIPTION => "Micro-average scores across entrypoints"},
#  MACRO => {DESCRIPTION => "Macro-average scores across entrypoints"},
#  UNION => {DESCRIPTION => "Estimate performance if system took union of answers for all entrypoints"},
#);
#
### DO INCLUDE

## DO NOT INCLUDE
# Removing COMBO
#
#
#sub get_combo_options_description {
#  &main::build_documentation(\%combo_options);
#}
#
### DO INCLUDE

# These are the keyword arguments that can be given to score_query
my %scoring_options = (
  RUNID =>      {DESCRIPTION => "ID of run to be scored",
		 REQUIRED => 'true',
		},
  DISCIPLINE => {DESCRIPTION => "{" . join(", ", sort keys %matchers) . "} - controls how submissions are matched to ground truth",
		 DEFAULT =>     'ASSESSED',
		},
  QUERY_BASE => {DESCRIPTION => "Multiple entrypoints are expanded to use this as the base name"},
### DO NOT INCLUDE
# Removing COMBO
#
#
#  COMBO =>      {DESCRIPTION => "{" . join(", ", sort keys %combo_options) . "} - controls how multiple entry point entries are scored",
#		 DEFAULT =>     'MICRO',
#		},
#
### DO INCLUDE
);

# Build a list of all the known scoring options
sub get_scoring_options_description {
  &main::build_documentation(\%scoring_options);
}

# Score a query by building the equivalence class tree for that query,
# placing each submission at the correct point in the tree, scoring
# each node of the tree, and collecting the resulting scores
sub score_query {
  my ($self, $original_query, $policy_options, $policy_selected, %options) = @_;
#print STDERR "score_query(", defined $original_query ? $original_query : 'undef', ") from ", join(":", caller), "\n";
  # Validate the scoring options
  foreach my $key (keys %options) {
    $self->NIST_die("Unknown scoring option: $key") unless $scoring_options{$key};
  }
  # Set option defaults, and ensure required options are present
  foreach my $key (keys %scoring_options) {
    $options{$key} = $scoring_options{$key}{DEFAULT}
      if defined $scoring_options{$key}{DEFAULT} && !defined $options{$key};
    $self->{LOGGER}->NIST_die("No $key provided")
      if $scoring_options{$key}{REQUIRED} && !defined $options{$key};
  }
  my @queries_to_score = ($original_query);
  my $new_query_base = $options{QUERY_BASE};
  if ($new_query_base) {
    my $subqueries = $original_query->expand($new_query_base);
    @queries_to_score = $subqueries->get_all_queries();
  }
  # Maintain a list of lists, each of which contains the submissions
  # for one query. If COMBO is UNION, we put them all together into a
  # single list
  my @submission_lists;
  my @ectrees;
  foreach my $query (@queries_to_score) {
    my $query_id = $query->{QUERY_ID};
    my $query_id_base = $query->get('QUERY_ID_BASE');
    my $assessment_list = $self->{ENTRIES_BY_QUERY_ID_BASE}{ASSESSMENT}{$query_id_base};
    my @submissions_for_query = grep {$_->{RUNID} eq $options{RUNID}} @{$self->{ENTRIES_BY_QUERY_ID_BASE}{SUBMISSION}{$query_id_base}};
## DO NOT INCLUDE
# Removing COMBO
#
#    if ($options{COMBO} eq 'UNION') {
#print STDERR "UNION\n";
#      # Make sure there's a single list of submissions, and a single ectree
#      push(@submission_lists, []) unless @submission_lists;
#      push(@{$submission_lists[0]}, @submissions_for_query);
#      push(@ectrees, EquivalenceClassTree->new($self->{LOGGER}, $self)) unless @ectrees;
#      $ectrees[0]->add_assessments($self, @{$assessment_list});
#    }
#    else {
#
### DO INCLUDE
    
#print STDERR "non-UNION\n";
      push(@submission_lists, \@submissions_for_query);
      my $ectree = EquivalenceClassTree->new($self->{LOGGER}, $self);
      $ectree->add_assessments($self, @{$assessment_list});
      push(@ectrees, $ectree);

## DO NOT INCLUDE
# Removing COMBO
#
#  }
#
### DO INCLUDE

    }


  # @submission_lists now contains all the submissions to be scored,
  # and @ectrees contains a parallel set of ectrees
  $self->{LOGGER}->NIST_die("Mismatch in score_query") unless @submission_lists == @ectrees;
#print STDERR "submission_lists has ", 0 + @submission_lists, " entries\n";
  my @scores;
  foreach my $i (0..$#ectrees) {
    my $submission_list = $submission_lists[$i];
    my $ectree = $ectrees[$i];
    foreach my $submission (@{$submission_list}) {
      my ($ground_truth, $discipline_used) = $self->get_ground_truth_for_submission($submission, $options{DISCIPLINE});
      $ectree->add_submission($submission,
			      $self->entry2ec($submission),
			      $ground_truth);
    }
    $ectree->score($options{RUNID}, $policy_options, $policy_selected);
    my @subscores = $ectree->get_all_scores();
### DO NOT INCLUDE
    # Shahzad -- This is where we either return the entire list of result vectors (for micro averagering)
    # or a single vector that averages the list (for macro averaging). It's probably more complicated to
    # communicate the policy now.
### DO INCLUDE

## DO NOT INCLUDE
# Removing COMBO
#
#    if ($options{COMBO} eq 'UNION' || $options{COMBO} eq 'MICRO') {
#
### DO INCLUDE

      push(@scores, @subscores);

## DO NOT INCLUDE
# Removing COMBO
#
#    }
#    elsif ($options{COMBO} eq 'MACRO') {
#      push(@scores, ScoreSet->new(@subscores)->toscore());
#    }
#    else {
#      $self->{LOGGER}->NIST_die("Unknown Scoring COMBO type: $options{COMBO}");
#    }
#
### DO INCLUDE
  }
  @scores;
}

# Create a new EvaluationQueryOutput object
sub new {
  my ($class, $logger, $discipline, $queries, @rawfilenames) = @_;
  $logger->NIST_die("$class->new called with no filenames") unless @rawfilenames;
  # Poor man's find
### DO NOT INCLUDE
  # FIXME: Need to escape blanks in the directory name
### DO INCLUDE
  my @filenames = map {-d $_ ? <$_/*.tab.txt> : $_} @rawfilenames;
  my $self = {QUERIES => $queries,
	      DISCIPLINE => $discipline,
	      RAW_FILENAMES => \@rawfilenames,
	      LOGGER => $logger};
  bless($self, $class);
  foreach my $filename (@filenames) {
    # Skip empty files
    if (-z $filename) {
      $logger->record_problem('EMPTY_FILE', $filename, 'NO_SOURCE');
      next;
    }
    my $type = &identify_file_type($logger, $filename);
    my $schema = $schemas{$type};
    unless ($schema) {
      $logger->record_problem('UNKNOWN_RESPONSE_FILE_TYPE', $type, 'NO_SOURCE');
      next;
    }
    $self->load($logger, $queries, $filename, $schema);
  }
  $self;
}

# Map a particular column entry to its string representation
sub column2string {
  my ($self, $entry, $schema, $column) = @_;
  if ($column =~ /^(.*)_TRIPLES$/) {
    my $provenance_column = $1;
    # NOTE: This outputs normalized provenance. That should be fine
    # for now, but might be a problem in the future.
    return $entry->{$provenance_column}->tostring();
  }
  elsif ($column eq 'RUNID') {
    return $self->{RUNID};
  }
  elsif ($column eq 'CONFIDENCE') {
    return $self->{CONFIDENCE} if defined $self->{CONFIDENCE};
    my $confidence = $entry->{$column};
    if($entry->{$column} =~ /^\d+\.\d+e-?\d\d$/) {
    	$self->{LOGGER}->record_problem('IMPROPER_CONFIDENCE_VALUE', $confidence, 
    				{FILENAME => $entry->{FILENAME}, LINENUM => $entry->{LINENUM}}
    			);
    	$confidence = sprintf("%0.12f", $confidence);
    }
    return $confidence;
  }
  elsif ($column =~ /_ASSESSMENT$/) {
### DO NOT INCLUDE
    # FIXME: Shahzad added the 0 return, but I'm not sure I see why 0 is the appropriate return
### DO INCLUDE
    return exists $entry->{$column} ? $schema->{INVERSE_ASSESSMENT_CODES}{$entry->{$column}} : 0;
  }
  elsif (defined $entry->{QUERY}{$column}) {
    return $entry->{QUERY}{$column};
  }
  elsif (defined $entry->{$column}) {
    return $entry->{$column};
  }
  else {
    die "No value present for column $column";
  }
}

# Convert this EvaluationQueryOutput back to its proper printed representation
sub tostring {
  my ($self, $schema_name) = @_;
  # Prevent duplicate adjacent lines from appearing in output
  my $previous = "";
  $schema_name = '2015SFsubmissions' unless defined $schema_name;
  my $schema = $schemas{$schema_name};
  $self->{LOGGER}->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my $string = "";
  if (defined $self->{ENTRIES_BY_TYPE}) {
### DO NOT INCLUDE
    # FIXME: Might be preferable to keep a top-level query together with its children
### DO INCLUDE
    foreach my $entry (sort {$a->{QUERY}{LEVEL} <=> $b->{QUERY}{LEVEL} ||
			     $a->{QUERY_ID} cmp $b->{QUERY_ID} ||
			     lc $a->{VALUE} cmp lc $b->{VALUE} ||
			     $a->{VALUE_PROVENANCE}->tostring() cmp $b->{VALUE_PROVENANCE}->tostring()}
		       @{$self->{ENTRIES_BY_TYPE}{$schema->{TYPE}}}) {
      my $query_id = $entry->{QUERY}{QUERY_ID};
      if ($self->{BAD_QUERIES}{$query_id}) {
	$self->{LOGGER}->record_problem('BAD_QUERY', $query_id, 'NO_SOURCE');
	next;
      }
      my $entry_string = join("\t", map {$self->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}});
      # Could use hash here to prevent duplicates
      $string .= "$entry_string\n" unless $entry_string eq $previous;
      $previous = $entry_string;
    }
  }
  $string;
}

sub get_runid {
  my ($self) = @_;
  $self->{RUNID};
}

sub set_runid {
  my ($self, $new_runid) = @_;
  $self->{RUNID} = $new_runid;
}

sub set_confidence {
  my ($self, $confidence) = @_;
  $self->{CONFIDENCE} = $confidence;
}

### END INCLUDE EvaluationQueryOutput

### BEGIN INCLUDE Scoring

#####################################################################################
##### Scorable
#####################################################################################

### Scorable is the base class for scoring. It defines get and set
### operations that invoke a method or return a field, as
### appropriate. It also calculates precision, recall, and F1, given
### that an object of type Scorable has NUM_GROUND_TRUTH, NUM_CORRECT,
### and NUM_INCORRECT values. Note that NUM_INCORRECT typically
### comprises NUM_WRONG and NUM_REDUNDANT.

package Scorable;

# Return the field if it's defined. Otherwise, invoke the corresponding get method
sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

# Invoke the corresponding put method if it's defined; otherwise set the field
sub put {
  my ($self, $field, $value) = @_;
  my $method = $self->can("put_$field");
  return $method->($self, $value) if $method;
  $self->{$field} = $value;
}

# A Scorable object must define NUM_RIGHT, NUM_IGNORED and
# NUM_GROUND_TRUTH, or implement get_NUM_RIGHT, get_NUM_IGNORED
# and get_NUM_GROUND_TRUTH

sub get_PRECISION {
  my ($self) = @_;
  my $num_right = $self->get('NUM_RIGHT');
  my $num_ignored = $self->get('NUM_IGNORED');
  my $num_responses = $self->get('NUM_SUBMITTED');
  return 0.0 unless ($num_responses-$num_ignored);
  return $num_right/($num_responses-$num_ignored);
}

sub get_RECALL {
  my ($self) = @_;
  my $num_right = $self->get('NUM_RIGHT');
  my $num_ground_truth = $self->get('NUM_GROUND_TRUTH');
  return 0.0 unless $num_ground_truth;
  return $num_right / $num_ground_truth;
}

sub get_F1 {
  my ($self) = @_;
  my $precision = $self->get('PRECISION');
  my $recall = $self->get('RECALL');
  return 0.0 unless $precision || $recall;
  return 2 * $precision * $recall / ($precision + $recall);
}

package Score;

### This package implements a single score, allows any field to be
### incremented, and defines NUM_INCORRECT as the sum of NUM_WRONG and
### NUM_REDUNDANT

# Inherit from Scorable. Use -norequire because Scorable is defined in this file.
use parent -norequire, 'Scorable';

sub new {
  my ($class) = @_;
  my $self = {NUM_RIGHT => 0,
	      NUM_IGNORED => 0,
	      NUM_SUBMITTED => 0,
	      NUM_GROUND_TRUTH => 0,
	     };
  bless($self, $class);
  $self;
}

sub duplicate {
  my ($self, @fields_to_omit) = @_;
  my %fields_to_omit = map {$_ => 'true'} @fields_to_omit;
  my $class = ref $self;
  my $result = $class->new($self->{LOGGER});
  foreach my $key (keys %{$self}) {
    # Skip keys we were requested to skip (Note: this will not prevent automatic creation)
    next if $fields_to_omit{$key};
    $result->put($key, $self->get($key));
  }
  $result;
}

sub increment {
  my ($self, $field, $value) = @_;
  $value = 1 unless defined $value;
  $self->{$field} += $value;
}

#sub get_NUM_INCORRECT {
#  my ($self) = @_;
#  $self->get('NUM_WRONG') + $self->get('NUM_REDUNDANT');
#}

package ScoreSet;

### A ScoreSet is a set of scores that implements get for most numeric
### fields as the sum of the value of that field across the component
### scores. It allows new Scorables to be added as components of the
### set, and provides methods getsum and getmean to access aggregate
### statistics

# Inherit from Scorable. Use -norequire because Scorable is defined in this file.
use parent -norequire, 'Scorable';

sub new {
  my ($class, @components) = @_;
  my $self = {COMPONENTS => [@components], NUM_BOSONS => 0};
  bless($self, $class);
  $self;
}

sub add {
  my ($self, @components) = @_;
  foreach my $component(@components) {
  	foreach my $key (grep {$_ =~ /^NUM_/} keys %{$component}) {
  		$self->{$key} += $component->{$key};
  	}
  }
  
  push(@{$self->{'COMPONENTS'}}, @components);
}

### DO NOT INCLUDE
# FIXME: I added this in anticipation that it might be used to correct
# the macro-averaging bug, but I didn't get much beyond that
sub add_boson {
  my ($self, $component) = @_;
  $self->add($component);
  $self->{NUM_BOSONS}++;
}
### DO INCLUDE

sub get_NON_NIL_NUM_COMPONENTS {
  my ($self) = @_;
  my $result = 0;
  foreach my $component (@{$self->{COMPONENTS}}) {
  	my $num_ground_truth = $component->get("NUM_GROUND_TRUTH");
  	next if($num_ground_truth == 0);
    my $method = $component->can("get_NUM_COMPONENTS");
    if ($method) {
      $result += $method->($component);
    }
    else {
      $result++;
    }
  }
  $result - $self->{NUM_BOSONS};
}

sub get_NUM_COMPONENTS {
  my ($self) = @_;
  my $result = 0;
  foreach my $component (@{$self->{COMPONENTS}}) {
    my $method = $component->can("get_NUM_COMPONENTS");
    if ($method) {
      $result += $method->($component);
    }
    else {
      $result++;
    }
  }
  $result - $self->{NUM_BOSONS};
}

sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  my $sum = 0;
  foreach my $component (@{$self->{COMPONENTS}}) {
    $sum += $component->get($field);
  }
  $sum;
}

sub getsum {
  my ($self, $field) = @_;
  my $sum = 0;
  foreach my $component (@{$self->{COMPONENTS}}) {
    $sum += $component->get($field);
  }
  $sum;
}

sub getmean {
  my ($self, $field) = @_;
  $self->getsum($field) / $self->get('NUM_COMPONENTS');
}

sub getadjustedmean {
  my ($self, $field) = @_;
  my $retVal = 0;
  $retVal = $self->getsum($field) / $self->get('NON_NIL_NUM_COMPONENTS')
		if $self->get('NON_NIL_NUM_COMPONENTS') > 0;
  $retVal;
}

## DO NOT INCLUDE
# Removing COMBO
#
#sub toscore {
#  my ($self) = @_;
#  my $result = Score->new();
#  foreach (qw(NUM_GROUND_TRUTH NUM_CORRECT NUM_INCORRECT NUM_REDUNDANT)) {
#    $result->put($_, $self->getmean($_));
#  }
#  $result;
#}
#
### DO INCLUDE

### END INCLUDE Scoring

### BEGIN INCLUDE Stats

#####################################################################################
##### Stats
#####################################################################################

package Histogram;

# Build a histogram of a statistic. Bins are as specified in
# @initial_bins (which must be in descending order), or double each
# following bin. At least one bin value must be specified.

sub new {
  my ($class, $description, @initial_bins) = @_;
  die "No initial bin size given" unless @initial_bins;
  die "Initial bin size must be positive" unless $initial_bins[0] > 0;
  push(@initial_bins, 0);
  my $self = {DESCRIPTION => $description, BINS => \@initial_bins, COUNTS => []};
  bless($self, $class);
  $self;
}

sub add {
  my ($self, $value) = @_;
  return if $value <= 0;
  # Add any missing bins
  while ($self->{BINS}[0] < $value) {
    unshift(@{$self->{BINS}}, 2 * $self->{BINS}[0]);
  }
  # Find the correct bin and increment its value
  for (my $i = 0; $i < $#{$self->{BINS}}; $i++) {
    if ($value > $self->{BINS}[$i + 1]) {
      $self->{COUNTS}[$i]++;
      return;
    }
  }
  die "Couldn't find proper bin for $value";
}

sub print {
  my ($self) = @_;
  print "Histogram of $self->{DESCRIPTION}:\n\t";
  for (my $i = 0; $i < @{$self->{COUNTS}}; $i++) {
    print "$self->{BINS}[$i]\t";
  }
  print "\n\t";
  for (my $i = 0; $i < @{$self->{COUNTS}}; $i++) {
    print "$self->{COUNTS}[$i]\t";
  }
  print "\n";
}

package Statistic;

sub new {
  my ($class, $name, $description, @bins) = @_;
  my $self = {NAME => $name,
	      COUNT => 0,
	      SUM => 0,
	      MIN => 0,
	      MAX => 0,
	      DESCRIPTION => $description,
	     };
  $self->{HISTOGRAM} = Histogram->new($description, @bins) if @bins;
  bless($self, $class);
  $self;
}

sub add {
  my ($self, $value) = @_;
  unless ($self->{COUNT}) {
    $self->{MIN} = $value;
    $self->{MAX} = $value;
    $self->{SUM} = 0;
  }
  $self->{COUNT}++;
  $self->{SUM} += $value;
  $self->{MIN} = $value if $value < $self->{MIN};
  $self->{MAX} = $value if $value > $self->{MAX};
  $self->{HISTOGRAM}->add($value) if $self->{HISTOGRAM};
}

sub get_min {
  my ($self) = @_;
  $self->{MIN};
}

sub get_max {
  my ($self) = @_;
  $self->{MAX};
}

sub get_sum {
  my ($self) = @_;
  $self->{SUM};
}

sub get_count {
  my ($self) = @_;
  $self->{COUNT};
}

sub get_mean {
  my ($self) = @_;
  int(0.5 + $self->{SUM} / $self->{COUNT});
}

sub get_fractional_mean {
  my ($self) = @_;
  $self->{SUM} / $self->{COUNT};
}

sub get_histogram {
  my ($self) = @_;
  $self->{HISTOGRAM};
}

my %headers_printed;

sub printstat {
  my ($self, $headerid) = @_;
  print "\tMin\tMean\tMax\tName\n" unless $headers_printed{$headerid}++;
  print
    "\t", $self->get_min(),
    "\t", sprintf("%4.2f", $self->get_fractional_mean()),
    "\t", $self->get_max(),
    "\t$headerid",
    "\n";
}

sub printcount {
  my ($self, $headerid, $rev) = @_;
  my $label = $self->{NAME};
  $label = $headerid if $headerid;
  print "$label\t" if $rev;
  print $self->get_count();
  print "\t$label" unless $rev;
  print "\n";
}

sub printsum {
  my ($self, $headerid, $rev) = @_;
  my $label = $self->{NAME};
  $label = $headerid if $headerid;
  print "$label\t" if $rev;
  print $self->get_sum();
  print "\t$label" unless $rev;
  print "\n";
}
  

### END INCLUDE Stats
### DO NOT INCLUDE
#####################################################################################
# Main Program (for testing)
#####################################################################################

### DO INCLUDE
### BEGIN INCLUDE Utils
package main;
use JSON;

#####################################################################################
# UUIDs from UUID::Tiny
#####################################################################################

# The following UUID code is taken from UUID::Tiny, available on
# cpan.org. I have stripped out much of the functionality in that
# module, keeping only what's needed here. If there is a better way to
# deliver a cpan module within a single script, I'd love to know about
# it. I believe that this use conforms with the perl terms.

####################################
# From the UUID::Tiny documentation:
####################################

=head1 ACKNOWLEDGEMENTS

Kudos to ITO Nobuaki E<lt>banb@cpan.orgE<gt> for his UUID::Generator::PurePerl
module! My work is based on his code, and without it I would've been lost with
all those incomprehensible RFC texts and C codes ...

Thanks to Jesse Vincent (C<< <jesse at bestpractical.com> >>) for his feedback, tips and refactoring!

=head1 COPYRIGHT & LICENSE

Copyright 2009, 2010, 2013 Christian Augustin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

ITO Nobuaki has very graciously given me permission to take over copyright for
the portions of code that are copied from or resemble his work (see
rt.cpan.org #53642 L<https://rt.cpan.org/Public/Bug/Display.html?id=53642>).

=cut

use Digest::MD5;

our $IS_UUID_STRING = qr/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/is;
our $IS_UUID_HEX    = qr/^[0-9a-f]{32}$/is;
our $IS_UUID_Base64 = qr/^[+\/0-9A-Za-z]{22}(?:==)?$/s;

my $MD5_CALCULATOR = Digest::MD5->new();

use constant UUID_NIL => "\x00" x 16;
use constant UUID_V1 => 1; use constant UUID_TIME   => 1;
use constant UUID_V3 => 3; use constant UUID_MD5    => 3;
use constant UUID_V4 => 4; use constant UUID_RANDOM => 4;
use constant UUID_V5 => 5; use constant UUID_SHA1   => 5;

sub _create_v3_uuid {
    my $ns_uuid = shift;
    my $name    = shift;
    my $uuid    = '';

    # Create digest in UUID ...
    $MD5_CALCULATOR->reset();
    $MD5_CALCULATOR->add($ns_uuid);

    if ( ref($name) =~ m/^(?:GLOB|IO::)/ ) {
        $MD5_CALCULATOR->addfile($name);
    }
    elsif ( ref $name ) {
        Logger->new()->NIST_die('::create_uuid(): Name for v3 UUID'
            . ' has to be SCALAR, GLOB or IO object, not '
            . ref($name) .'!')
            ;
    }
    elsif ( defined $name ) {
        $MD5_CALCULATOR->add($name);
    }
    else {
        Logger->new()->NIST_die('::create_uuid(): Name for v3 UUID is not defined!');
    }

    # Use only first 16 Bytes ...
    $uuid = substr( $MD5_CALCULATOR->digest(), 0, 16 );

    return _set_uuid_version( $uuid, 0x30 );
}

sub _set_uuid_version {
    my $uuid = shift;
    my $version = shift;
    substr $uuid, 6, 1, chr( ord( substr( $uuid, 6, 1 ) ) & 0x0f | $version );

    return $uuid;
}

sub create_uuid {
    use bytes;
    my ($v, $arg2, $arg3) = (shift || UUID_V1, shift, shift);
    my $uuid    = UUID_NIL;
    my $ns_uuid = string_to_uuid(defined $arg3 ? $arg2 : UUID_NIL);
    my $name    = defined $arg3 ? $arg3 : $arg2;

    ### Portions redacted from UUID::Tiny
    if ($v == UUID_V3 ) {
        $uuid = _create_v3_uuid($ns_uuid, $name);
    }
    else {
        Logger->new()->NIST_die("::create_uuid(): Invalid UUID version '$v'!");
    }

    # Set variant 2 in UUID ...
    substr $uuid, 8, 1, chr(ord(substr $uuid, 8, 1) & 0x3f | 0x80);

    return $uuid;
}

sub string_to_uuid {
    my $uuid = shift;

    use bytes;
    return $uuid if length $uuid == 16;
    return decode_base64($uuid) if ($uuid =~ m/$IS_UUID_Base64/);
    my $str = $uuid;
    $uuid =~ s/^(?:urn:)?(?:uuid:)?//io;
    $uuid =~ tr/-//d;
    return pack 'H*', $uuid if $uuid =~ m/$IS_UUID_HEX/;
    Logger->new()->NIST_die("::string_to_uuid(): '$str' is no UUID string!");
}

sub uuid_to_string {
    my $uuid = shift;
    use bytes;
    return $uuid
        if $uuid =~ m/$IS_UUID_STRING/;
    Logger->new()->NIST_die("::uuid_to_string(): Invalid UUID!")
        unless length $uuid == 16;
    return  join '-',
            map { unpack 'H*', $_ }
            map { substr $uuid, 0, $_, '' }
            ( 4, 2, 2, 2, 6 );
}

sub create_UUID_as_string {
    return uuid_to_string(create_uuid(@_));
}

#####################################################################################
# This is the end of the code taken from UUID::Tiny
#####################################################################################

my $json = JSON->new->allow_nonref->utf8;

sub generate_uuid_from_values {
  my ($queryid, $value, $provenance_string, $length) = @_;
  my $encoded_string = $json->encode("$queryid:$value:$provenance_string");
  $encoded_string =~ s/^"//;
  $encoded_string =~ s/"$//;
  &generate_uuid_from_string($encoded_string, $length);
}

sub generate_uuid_from_string {
  my ($string, $length) = @_;
  my $long_uuid = create_UUID_as_string(UUID_V3, $string);
  substr($long_uuid, -$length, $length);
}
### DO NOT INCLUDE
# sub uuid_generate {
#   my ($queryid, $value, $provenance_string) = @_;
#   my $encoded_string = $json->encode("$queryid:$value:$provenance_string");
#   $encoded_string =~ s/^"//;
#   $encoded_string =~ s/"$//;
# ### DO NOT INCLUDE
# # NOTE: this is the 2014 code, which special cased a query that had a funky character. I expect the patch is not backward compatible.  
# # # FIXME
# # my $glop = $value;
# # $glop =~ s/’/'/g;
# # #  create_UUID_as_string(UUID_V3, "$queryid:$value:$provenance_string");
# #  create_UUID_as_string(UUID_V3, "$queryid:$glop:$provenance_string");
# ### DO INCLUDE
#   # We're shortening the uuid for 2015
#   my $long_uuid = create_UUID_as_string(UUID_V3, $encoded_string);
#   substr($long_uuid, -12, 12);
# }

# sub short_uuid_generate {
#   my ($string) = @_;
#   my $encoded_string = $json->encode($string);
#   $encoded_string =~ s/^"//;
#   $encoded_string =~ s/"$//;
# ### DO NOT INCLUDE
# print STDERR "Original string = <<$string>>\n Encoded string = <<$encoded_string>>\n" unless $string eq $encoded_string;
# ### DO INCLUDE
#   my $long_uuid = create_UUID_as_string(UUID_V3, $encoded_string);
#   substr($long_uuid, -10, 10);
# }
### DO INCLUDE

sub min {
  my ($result, @values) = @_;
  foreach (@values) {
    $result = $_ if $_ < $result;
  }
  $result;
}

sub max {
  my ($result, @values) = @_;
  foreach (@values) {
    $result = $_ if $_ > $result;
  }
  $result;
}

# Pull DOCUMENTATION strings out of a table and format for the help screen
sub build_documentation {
  my ($structure, $sort_key) = @_;
  if (ref $structure eq 'HASH') {
    my $max_len = &max(map {length} keys %{$structure});
    "  " . join("\n  ", map {$_ . ": " . (' ' x ($max_len - length($_))) . $structure->{$_}{DESCRIPTION}}
		sort keys %{$structure}) . "\n";
  }
  elsif (ref $structure eq 'ARRAY') {
    $sort_key = 'TYPE' unless defined $sort_key;
    my $max_len = &max(map {length($_->{$sort_key})}  @{$structure});
    "  " . join("\n  ", map {$_->{$sort_key} . ": " . (' ' x ($max_len - length($_->{$sort_key}))) . $_->{DESCRIPTION}}
		sort {$a->{$sort_key} cmp $b->{$sort_key}} @{$structure}) . "\n";
  }
  else {
    "Internal error: Better call Saul.\n";
  }
}

sub dump_structure {
  my ($structure, $label, $indent, $history, $skip) = @_;
  if (ref $indent) {
    $skip = $indent;
    undef $indent;
  }
  my $outfile = *STDERR;
  $indent = 0 unless defined $indent;
  $history = {} unless defined $history;

  # Handle recursive structures
  if ($history->{$structure}) {
    print $outfile "  " x $indent, "$label: CIRCULAR\n";
    return;
  }

  my $type = ref $structure;
  unless ($type) {
    $structure = 'undef' unless defined $structure;
    print $outfile "  " x $indent, "$label: $structure\n";
    return;
  }
  if ($type eq 'ARRAY') {
    $history->{$structure}++;
    print $outfile "  " x $indent, "$label:\n";
    for (my $i = 0; $i < @{$structure}; $i++) {
      &dump_structure($structure->[$i], $i, $indent + 1, $history, $skip);
    }
  }
  elsif ($type eq 'CODE') {
    print $outfile "  " x $indent, "$label: CODE\n";
  }
  elsif ($type eq 'IO::File') {
    print $outfile "  " x $indent, "$label: IO::File\n";
  }
  else {
    $history->{$structure}++;
    print $outfile "  " x $indent, "$label:\n";
    my %done;
  outer:
    # You can add field names prior to the sort to order the fields in a desired way
    foreach my $key (sort keys %{$structure}) {
      if ($skip) {
	foreach my $skipname (@{$skip}) {
	  next outer if $key eq $skipname;
	}
      }
      next if $done{$key}++;
      # Skip undefs
      next unless defined $structure->{$key};
      &dump_structure($structure->{$key}, $key, $indent + 1, $history, $skip);
    }
  }
}

### END INCLUDE Utils
### BEGIN INCLUDE Switches

#####################################################################################
# This switch processing code written many years ago by James Mayfield
# and used here with permission. It really has nothing to do with
# TAC KBP; it's just a partial replacement for getopt that closely ties
# the documentation to the switch specification. The code may well be cheesy,
# so no peeking.
#####################################################################################

package SwitchProcessor;

sub _max {
    my $first = shift;
    my $second = shift;
    $first > $second ? $first : $second;
}

sub _quotify {
    my $string = shift;
    if (ref($string)) {
	join(", ", @{$string});
    }
    else {
	(!$string || $string =~ /\s/) ? "'$string'" : $string;
    }
}

sub _formatSubs {
    my $value = shift;
    my $switch = shift;
    my $formatted;
    if ($switch->{SUBVARS}) {
	$formatted = "";
	foreach my $subval (@{$value}) {
	    $formatted .= " " if $formatted;
	    $formatted .= _quotify($subval);
	}
    }
    # else if this is a constant switch, omit the vars [if they match?]
    else {
	$formatted = _quotify($value);
    }
    $formatted;
}

# Print an error message, display program usage, and exit unsuccessfully
sub _barf {
    my $self = shift;
    my $errstring = shift;
    open(my $handle, "|more") or Logger->new()->NIST_die("Couldn't even barf with message $errstring");
    print $handle "ERROR: $errstring\n";
    $self->showUsage($handle);
    close $handle;
    exit(-1);
}

# Create a new switch processor.  Arguments are the name of the
# program being run, and deneral documentation for the program
sub new {
    my $classname = shift;
    my $self = {};
    bless ($self, $classname);
    $self->{PROGNAME} = shift;
    $self->{PROGNAME} =~ s(^.*/)();
    $self->{DOCUMENTATION} = shift;
    $self->{POSTDOCUMENTATION} = shift;
    $self->{HASH} = {};
    $self->{PARAMS} = [];
    $self->{SWITCHWIDTH} = 0;
    $self->{PARAMWIDTH} = 0;
    $self->{SWITCHES} = {};
    $self->{VARSTOCHECK} = ();
    $self->{LEGALVARS} = {};
    $self->{PROCESS_INVOKED} = undef;
    $self;
}

# Fill a paragraph, with different leaders for first and subsequent lines
sub _fill {
    $_ = shift;
    my $leader1 = shift;
    my $leader2 = shift;
    my $width = shift;
    my $result = "";
    my $thisline = $leader1;
    my $spaceOK = undef;
    foreach my $word (split) {
	if (length($thisline) + length($word) + 1 <= $width) {
	    $thisline .= " " if ($spaceOK);
	    $spaceOK = "TRUE";
	    $thisline .= $word;
	}
	else {
			if(length($word) > $width) {
				my @chars = split("", $word);
				my $numsplits = int((scalar @chars/$width)) + 1;
				my $start  =  0;
				my $length =  @chars / $numsplits;

				foreach my $i (0 .. $numsplits-1)
				{
				    my $end = ($i == $numsplits-1) ? $#chars : $start + $length - 1;
				    my $splitword = join("", @chars[$start .. $end]);
				    $start += $length;
				    $result .= "$thisline\n";
				    $thisline = "$leader2$splitword";
				    $thisline .= "/" if $i < $numsplits-1;
				    $spaceOK = "TRUE";
				}
				
			}
			else {
		    $result .= "$thisline\n";
		    $thisline = "$leader2$word";
		    $spaceOK = "TRUE";
			}
	}
    }
    "$result$thisline\n";
}

# Show program usage
sub showUsage {
    my $self = shift;
    my $handle = shift;
    open($handle, "|more") unless defined $handle;
    print $handle _fill($self->{DOCUMENTATION}, "$self->{PROGNAME}:  ",
			" " x (length($self->{PROGNAME}) + 3), $terminalWidth);
    print $handle "\nUsage: $self->{PROGNAME}";
    print $handle " {-switch {-switch ...}}"
	if (keys(%{$self->{SWITCHES}}) > 0);
    # Count the number of optional parameters
    my $optcount = 0;
    # Print each parameter
    foreach my $param (@{$self->{PARAMS}}) {
	print $handle " ";
	print $handle "{" unless $param->{REQUIRED};
	print $handle $param->{NAME};
	$optcount++ if (!$param->{REQUIRED});
	print $handle "..." if $param->{ALLOTHERS};
    }
    # Close out the optional parameters
    print $handle "}" x $optcount;
    print $handle "\n\n";
    # Show details of each switch
    my $headerprinted = undef;
    foreach my $key (sort keys %{$self->{SWITCHES}}) {
	my $usage = "  $self->{SWITCHES}->{$key}->{USAGE}" .
	    " " x ($self->{SWITCHWIDTH} - length($self->{SWITCHES}->{$key}->{USAGE}) + 2);
	if (defined($self->{SWITCHES}->{$key}->{DOCUMENTATION})) {
	    print $handle "Legal switches are:\n"
		unless defined($headerprinted);
	    $headerprinted = "TRUE";
	    print $handle _fill($self->{SWITCHES}->{$key}->{DOCUMENTATION},
			$usage,
			" " x (length($usage) + 2),
			$terminalWidth);
	}
    }
    # Show details of each parameter
    if (@{$self->{PARAMS}} > 0) {
	print $handle "parameters are:\n";
	foreach my $param (@{$self->{PARAMS}}) {
	    my $usage = "  $param->{USAGE}" .
		" " x ($self->{PARAMWIDTH} - length($param->{USAGE}) + 2);
	    print $handle _fill($param->{DOCUMENTATION}, $usage, " " x (length($usage) + 2), $terminalWidth);
	}
    }
    print $handle "\n$self->{POSTDOCUMENTATION}\n" if $self->{POSTDOCUMENTATION};
}

# Retrieve all keys defined for this switch processor
sub keys {
    my $self = shift;
    keys %{$self->{HASH}};
}

# Add a switch that causes display of program usage
sub addHelpSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newHelp($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that causes a given variable(s) to be assigned a given
# constant value(s)
sub addConstantSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newConstant($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that assigns to a given variable(s) value(s) provided
# by the user on the command line
sub addVarSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newVar($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that invokes a callback as soon as it is encountered on
# the command line.  The callback receives three arguments: the switch
# object (which is needed by the internal routines, but presumably may
# be ignored by user-defined functions), the switch processor, and all
# the remaining arguments on the command line after the switch (as the
# remainder of @_, not a reference).  If it returns, it must return
# the list of command-line arguments that remain after it has dealt
# with whichever ones it wants to.
sub addImmediateSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newImmediate($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

sub addMetaSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newMeta($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a new switch
sub _addSwitch {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $switch = shift;
    # Can't add switches after process() has been invoked
    Logger->new()->NIST_die("Attempt to add a switch after process() has been invoked, at $filename line $line\n")
	if ($self->{PROCESS_INVOKED});
    # Bind the switch object to its name
    $self->{SWITCHES}->{$switch->{NAME}} = $switch;
    # Remember how much space is required for the usage line
    $self->{SWITCHWIDTH} = _max($self->{SWITCHWIDTH}, length($switch->{USAGE}))
	if (defined($switch->{DOCUMENTATION}));
    # Make a note of the variable names that are legitimized by this switch
    $self->{LEGALVARS}->{$switch->{NAME}} = "TRUE";
}

# Add a new command-line parameter
sub addParam {
    my ($shouldBeUndef, $filename, $line) = caller;
    my $self = shift;
    # Can't add params after process() has been invoked
    Logger->new()->NIST_die("Attempt to add a param after process() has been invoked, at $filename line $line\n")
	if ($self->{PROCESS_INVOKED});
    # Create the parameter object
    my $param = SP::_Param->new($filename, $line, @_);
    # Remember how much space is required for the usage line
    $self->{PARAMWIDTH} = _max($self->{PARAMWIDTH}, length($param->{NAME}));
    # Check for a couple of potential problems with parameter ordering
    if (@{$self->{PARAMS}} > 0) {
	my $previous = ${$self->{PARAMS}}[$#{$self->{PARAMS}}];
        Logger->new()->NIST_die("Attempt to add param after an allOthers param, at $filename line $line\n")
	    if ($previous->{ALLOTHERS});
        Logger->new()->NIST_die("Attempt to add required param after optional param, at $filename line $line\n")
	    if ($param->{REQUIRED} && !$previous->{REQUIRED});
    }
    # Make a note of the variable names that are legitimized by this param
    $self->{LEGALVARS}->{$param->{NAME}} = "TRUE";
    # Add the parameter object to the list of parameters for this program
    push(@{$self->{PARAMS}}, $param);
}

# Set a switch processor variable to a given value
sub put {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    $self->_varNameCheck($filename, $line, $key, undef);
    my $switch = $self->{SWITCHES}->{$key};
    Logger->new()->NIST_die("Wrong number of values in second argument to put, at $filename line $line.\n")
	if ($switch->{SUBVARS} &&
	    (!ref($value) ||
	     scalar(@{$value}) != @{$switch->{SUBVARS}}));
    $self->{HASH}->{$key} = $value;
}

# Get the value of a switch processor variable
sub get {
    my $self = shift;
    my $key = shift;
    # Internally, we sometimes want to do a get before process() has
    # been invoked.  The secret second argument to get allows this.
    my $getBeforeProcess = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    Logger->new()->NIST_die("Get called before process, at $filename line $line\n")
	if (!$self->{PROCESS_INVOKED} && !$getBeforeProcess);
    # Check for var.subvar syntax
    $key =~ /([^.]*)\.*(.*)/;
    my $var = $1;
    my $subvar = $2;
    # Make sure this is a legitimate switch processor variable
    $self->_varNameCheck($filename, $line, $var, $subvar);
    my $value = $self->{HASH}->{$var};
    $subvar ? $value->[$self->_getSubvarIndex($var, $subvar)] : $value;
}

sub _getSubvarIndex {
    my $self = shift;
    my $var = shift;
    my $subvar = shift;
    my $switch = $self->{SWITCHES}->{$var};
    return(-1) unless $switch;
    return(-1) unless $switch->{SUBVARS};
    for (my $i = 0; $i < @{$switch->{SUBVARS}}; $i++) {
	return($i) if ${$switch->{SUBVARS}}[$i] eq $subvar;
    }
    -1;
}

# Check whether a given switch processor variable is legitimate
sub _varNameCheck {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $key = shift;
    my $subkey = shift;
    # If process() has already been invoked, check the variable name now...
    if ($self->{PROCESS_INVOKED}) {
	$self->_immediateVarNameCheck($filename, $line, $key, $subkey);
    }
    # ...Otherwise, remember the variable name and check it later
    else {
	push(@{$self->{VARSTOCHECK}}, [$filename, $line, $key, $subkey]);
    }
}

# Make sure this variable is legitimate
sub _immediateVarNameCheck {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $key = shift;
    my $subkey = shift;
    Logger->new()->NIST_die("No such SwitchProcessor variable: $key, at $filename line $line\n")
	unless $self->{LEGALVARS}->{$key};
    Logger->new()->NIST_die("No such SwitchProcessor subvariable: $key.$subkey, at $filename line $line\n")
	unless (!$subkey || $self->_getSubvarIndex($key, $subkey) >= 0);
}

# Add default values to switch and parameter documentation strings,
# where appropriate
sub _addDefaultsToDoc {
    my $self = shift;
    # Loop over all switches
    foreach my $switch (values %{$self->{SWITCHES}}) {
	if ($switch->{METAMAP}) {
	    $switch->{DOCUMENTATION} .= " (Equivalent to";
	    foreach my $var (sort CORE::keys %{$switch->{METAMAP}}) {
		my $rawval = $switch->{METAMAP}->{$var};
		my $val = SwitchProcessor::_formatSubs($rawval, $self->{SWITCHES}->{$var});
		$switch->{DOCUMENTATION} .= " -$var $val";
	    }
	    $switch->{DOCUMENTATION} .= ")";
	}
	# Default values aren't reported for constant switches
	if (!defined($switch->{CONSTANT})) {
	    my $default = $self->get($switch->{NAME}, "TRUE");
	    if (defined($default)) {
		$switch->{DOCUMENTATION} .= " (Default = " . _formatSubs($default, $switch) . ").";
	    }
	}
    }
    # Loop over all params
    foreach my $param (@{$self->{PARAMS}}) {
	my $default = $self->get($param->{NAME}, "TRUE");
	# Add default to documentation if the switch is optional and there
	# is a default value
	$param->{DOCUMENTATION} .= " (Default = " . _quotify($default) . ")."
	    if (!$param->{REQUIRED} && defined($default));
    }
}

# Process the command line
sub process {
    my $self = shift;
    # Add defaults to the documentation
    $self->_addDefaultsToDoc();
    # Remember that process() has been invoked
    $self->{PROCESS_INVOKED} = "TRUE";
    # Now that all switches have been defined, check all pending
    # variable names for legitimacy
    foreach (@{$self->{VARSTOCHECK}}) {
	# FIXME: Can't we just use @{$_} here?
	$self->_immediateVarNameCheck(${$_}[0], ${$_}[1], ${$_}[2], ${$_}[3]);
    }
    # Switches must come first.  Keep processing switches as long as
    # the next element begins with a dash
    while (@_ && $_[0] =~ /^-(.*)/) {
	# Get the switch with this name
	my $switch = $self->{SWITCHES}->{$1};
	$self->_barf("Unknown switch: -$1\n")
	    unless $switch;
	# Throw away the switch name
	shift;
	# Invoke the process code associated with this switch
	# FIXME:  How can switch be made implicit?
	@_ = $switch->{PROCESS}->($switch, $self, @_);
    }
    # Now that the switches have been handled, loop over the legal params
    foreach my $param (@{$self->{PARAMS}}) {
	# Bomb if a required arg wasn't provided
	$self->_barf("Not enough arguments; $param->{NAME} must be provided\n")
	    if (!@_ && $param->{REQUIRED});
	# If this is an all others param, grab all the remaining arguments
	if ($param->{ALLOTHERS}) {
	    $self->put($param->{NAME}, [@_]) if @_;
	    @_ = ();
	}
	# Otherwise, if there are arguments left, bind the next one to the parameter
	elsif (@_) {
	    $self->put($param->{NAME}, shift);
	}
    }
    # If any arguments are left over, the user botched it
    $self->_barf("Too many arguments\n")
	if (@_);
}

################################################################################

package SP::_Switch;

sub new {
    my $classname = shift;
    my $filename = shift;
    my $line = shift;
    my $self = {};
    bless($self, $classname);
    Logger->new()->NIST_die("Too few arguments to constructor while creating classname, at $filename line $line\n")
	unless @_ >= 2;
    # Switch name and documentation are always present
    $self->{NAME} = shift;
    $self->{DOCUMENTATION} = pop;
    $self->{USAGE} = "-$self->{NAME}";
    # I know, these are unnecessary
    $self->{PROCESS} = undef;
    $self->{CONSTANT} = undef;
    $self->{SUBVARS} = ();
    # Return two values
    # FIXME: Why won't [$self, \@_] work here?
    ($self, @_);
}

# Create new help switch
sub newHelp {
    my @args = new (@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too many arguments to addHelpSwitch, at $_[1] line $_[2]\n")
	if (@args);
    # A help switch just prints out program usage then exits
    $self->{PROCESS} = sub {
	my $self = shift;
	my $sp = shift;
	$sp->showUsage();
	exit(0);
    };
    $self;
}

# Create a new constant switch
sub newConstant {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too few arguments to addConstantSwitch, at $_[1] line $_[2]\n")
	unless @args >= 1;
    Logger->new()->NIST_die("Too many arguments to addConstantSwitch, at $_[1] line $_[2]\n")
	unless @args <= 2;
    # Retrieve the constant value
    $self->{CONSTANT} = pop(@args);
    if (@args) {
	$self->{SUBVARS} = shift(@args);
	# Make sure, if there are subvars, that the number of subvars
	# matches the number of constant arguments
	Logger->new()->NIST_die("Number of values [" . join(", ", @{$self->{CONSTANT}}) .
	    "] does not match number of variables [" . join(", ", @{$self->{SUBVARS}}) .
		"], at $_[1] line $_[2]\n")
		    unless $#{$self->{CONSTANT}} == $#{$self->{SUBVARS}};
    }
    $self->{PROCESS} = sub {
	my $self = shift;
	my $sp = shift;
	my $counter = 0;
	$sp->put($self->{NAME}, $self->{CONSTANT});
	@_;
    };
    $self;
}

# Create a new var switch
sub newVar {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too many arguments to addVarSwitch, at $_[1] line $_[2]\n")
	unless @args <= 1;
    # If there are subvars
    if (@args) {
	my $arg = shift(@args);
	if (ref $arg) {
	    $self->{SUBVARS} = $arg;
	    # Augment the usage string with the name of the subvar
	    foreach my $subvar (@{$self->{SUBVARS}}) {
		$self->{USAGE} .= " <$subvar>";
	    }
	    # A var switch with subvars binds each subvar
	    $self->{PROCESS} = sub {
		my $self = shift;
		my $sp = shift;
		my $counter = 0;
		my $value = [];
		# Make sure there are enough arguments for this switch
		foreach (@{$self->{SUBVARS}}) {
		    $sp->_barf("Not enough arguments to switch -$self->{NAME}\n")
			unless @_;
		    push(@{$value}, shift);
		}
		$sp->put($self->{NAME}, $value);
		@_;
	    };
	}
	else {
	    $self->{USAGE} .= " <$arg>";
	    $self->{PROCESS} = sub {
		my $self = shift;
		my $sp = shift;
		$sp->put($self->{NAME}, shift);
		@_;
	    };
	}
    }
    else {
	# A var switch without subvars gets one argument, called 'value'
	# in the usage string
	$self->{USAGE} .= " <value>";
	# Bind the argument to the parameter
	$self->{PROCESS} = sub {
	    my $self = shift;
	    my $sp = shift;
	    $sp->put($self->{NAME}, shift);
	    @_;
	};
    }
    $self;
}

# Create a new immediate switch
sub newImmediate {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Wrong number of arguments to addImmediateSwitch or addMetaSwitch, at $_[1] line $_[2]\n")
	unless @args == 1;
    $self->{PROCESS} = shift(@args);
    $self;
}

# Create a new meta switch
sub newMeta {
    # The call looks just like a call to newImmediate, except that
    # instead of a fn as the second argument, there's a hashref.  So
    # use newImmediate to do the basic work, then strip out the
    # hashref and replace it with the required function.
    my $self = newImmediate(@_);
    $self->{METAMAP} = $self->{PROCESS};
    $self->{PROCESS} = sub {
	my $var;
	my $val;
	my $self = shift;
	my $sp = shift;
	# FIXME: Doesn't properly handle case where var is itself a metaswitch
	while (($var, $val) = each %{$self->{METAMAP}}) {
	    $sp->put($var, $val);
	}
	@_;
    };
    $self;
}

################################################################################

package SP::_Param;

# A parameter is just a struct for the four args
sub new {
    my $classname = shift;
    my $filename = shift;
    my $line = shift;
    my $self = {};
    bless($self, $classname);
    $self->{NAME} = shift;
    # param name and documentation are first and last, respectively.
    $self->{DOCUMENTATION} = pop;
    $self->{USAGE} = $self->{NAME};
    # If omitted, REQUIRED and ALLOTHERS default to undef
    $self->{REQUIRED} = shift;
    $self->{ALLOTHERS} = shift;
    # Tack on required to the documentation stream if this arg is required
    $self->{DOCUMENTATION} .= " (Required)."
	if ($self->{REQUIRED});
    $self;
}

################################################################################

### END INCLUDE Switches

1;
