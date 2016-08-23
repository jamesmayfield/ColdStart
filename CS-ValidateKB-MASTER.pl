#!/usr/bin/perl

use warnings;
use strict;

### DO NOT INCLUDE
use ColdStartLib;
### DO INCLUDE

binmode(STDOUT, ":utf8");

##################################################################################### 
# This program checks the validity of TAC Cold Start knowledge base variant input
# files. It will also output an updated version of a KB with warnings corrected.
#
# You are receiving this program because you signed up for a partner newsletter
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

### DO NOT INCLUDE
# FIXME: This doesn't really do much good without tracking the ColdStartLib version as well
### DO INCLUDE
my $version = "5.3";

my $statsfile;

##################################################################################### 
# Priority for the selection of problem locations
##################################################################################### 

my %use_priority = (
  MENTION => 1,
  TYPEDEF => 2,
  SUBJECT => 3,
  OBJECT  => 4,
);  

##################################################################################### 
# Mapping from output type to export routine
##################################################################################### 

my %type2export = (
  tac => \&export_tac,
  edl => \&export_edl,
);

my $output_formats = "[" . join(", ", sort keys %type2export) . ", none]";

##################################################################################### 
# Default values
##################################################################################### 

# Can the same assertion be made more than once?
my %multiple_attestations = (
  ONE =>       "only one allowed - no duplicates",
  ONEPERDOC => "at most one allowed per document",
  MANY =>      "any number of duplicate assertions allowed",
);
my $multiple_attestations = 'ONE';

# Which triple labels should be output?
my %output_labels = ();

# Filehandles for program and error output
my $program_output;
my $error_output = *STDERR{IO};

##################################################################################### 
# Library inclusions
##################################################################################### 

### DO INCLUDE Logger       ColdStartLib.pm
### DO INCLUDE Patterns     ColdStartLib.pm
### DO INCLUDE Provenance   ColdStartLib.pm
### DO INCLUDE Predicates   ColdStartLib.pm
### DO INCLUDE Switches     ColdStartLib.pm

##################################################################################### 
# Predicates
##################################################################################### 


##################################################################################### 
# Knowledge base
##################################################################################### 

# This is not really a KB per se, because we have to be resilient to errors in the input
package KB;

# A KB contains the following fields:
#  ASSERTIONS0	- All assertions
#  ASSERTIONS1	- Assertions indexed by subject
#  ASSERTIONS2	- Assertions indexed by subject and verb
#  ASSERTIONS3	- Assertions indexed by subject, verb and object
#  DOCIDS	- Assertions indexed by subject, verb and docid
#  ENTITIES	- Maps from entity name to entity structure
#  LOGGER	- Logger object for reporting errors and traces
#  MENTIONS	- Mention assertions indexed by docid
#  PREDICATES	- PredicateSet object
#  RUNID	- Run ID of the KB file this KB was built from
#  RUNID_LINE	- Entire line from which RUNID was extracted, including comments

# Create a new empty KB
sub new {
  my ($class, $logger, $predicates) = @_;
  my $self = {LOGGER => $logger, PREDICATES => $predicates};
  bless($self, $class);
  $self;
}

# Find or create the KB entity with a given name
sub intern {
  my ($kb, $name, $source) = @_;
  return $name if ref $name;
  if ($name =~ /^"/) {
    $kb->{LOGGER}->record_problem('STRING_USED_FOR_ENTITY', $name, $source);
    return;
  }
  unless ($name =~ /^:?\w+$/) {
    $kb->{LOGGER}->record_problem('ILLEGAL_ENTITY_NAME', $name, $source);
    return;
  }
  unless ($name =~ /^:/) {
    $kb->{LOGGER}->record_problem('COLON_OMITTED', $name, $source);
    $name = ":$name";
  }
  my $entity = $kb->{ENTITIES}{$name};
  unless (defined $entity) {
    $entity = {NAME => $name};
    $kb->{ENTITIES}{$name} = $entity;
  }
  $entity;
}

# Record that an entity has been used in a particular way (e.g., it's
# been given a type, it appears as the subject of a predicate, etc.)
sub entity_use {
  my ($kb, $name, $use_type, $source) = @_;
  $kb->{LOGGER}->NIST_die("Unknown use type: $use_type") unless $use_priority{$use_type};
  my $entity = $kb->intern($name, $source);
  # Do nothing if the name is malformed
  return unless defined $entity;
  $use_type = uc $use_type;
  push(@{$entity->{USES}{$use_type}}, $source);
  # When an error message refers to a particular entity, we'd like to
  # give as clear a pointer to the entity as we can. This code keeps
  # track of the "best" use of an entity for reporting purposes, with
  # %use_priority providing the definition of "best."
  my $thisuse = {USE_TYPE => $use_type, SOURCE => $source};
  my $bestuse = $entity->{BESTUSE} || $thisuse;
  $bestuse = $thisuse if $bestuse->{USE_TYPE} eq $thisuse->{USE_TYPE} &&
                         $bestuse->{SOURCE}{LINENUM} > $thisuse->{SOURCE}{LINENUM};
  $bestuse = $thisuse if $use_priority{$bestuse->{USE_TYPE}} > $use_priority{$thisuse->{USE_TYPE}};
  $entity->{BESTUSE} = $bestuse;
  $entity;
}

# Assert that an entity has the given type
sub entity_typedef {
  my ($kb, $name, $type, $def_type, $source) = @_;
  $kb->{LOGGER}->NIST_die("Unknown def type: $def_type") unless $use_priority{$def_type};
  # A type specification with multiple types doesn't give us any information, so ignore it
  if (ref $type) {
    my @types = keys %{$type};
    return if (@types > 1);
    $kb->{LOGGER}->NIST_die("type set with no entries in entity_typedef") unless @types;
    $type = $types[0];
  }
  $type = lc $type;
  # Only legal types may be asserted
  unless ($PredicateSet::legal_entity_types{$type}) {
    $kb->{LOGGER}->record_problem('ILLEGAL_ENTITY_TYPE', $type, $source);
    return;
  }
  my $entity = $kb->intern($name, $source);
  # Do nothing if the name is malformed
  return unless defined $entity;
  $def_type = uc $def_type;
  push(@{$entity->{TYPEDEFS}{$type}{$def_type}}, $source);
  my $thisdef = {DEFTYPE => $def_type, SOURCE => $source};
  my $bestdef = $entity->{BESTDEF}{$type} || $thisdef;
  # The best definition to point the user at is the one with the
  # highest use_priority, or, if they're the same, the one that occurs
  # first in the file
  $bestdef = $thisdef if $bestdef->{DEFTYPE} eq $thisdef->{DEFTYPE} &&
                         $bestdef->{SOURCE}{LINENUM} > $thisdef->{SOURCE}{LINENUM};
  $bestdef = $thisdef if $use_priority{$bestdef->{DEFTYPE}} > $use_priority{$thisdef->{DEFTYPE}};
  $entity->{BESTDEF}{$type} = $bestdef;
  $entity;
}

# Find the type of a given entity, if known
sub get_entity_type {
  my ($kb, $entity, $source) = @_;
  $entity = $kb->intern($entity, $source);
  # We'll only get nil if the entity name is malformed, but return
  # unknown nonetheless
  return 'unknown' unless defined $entity;
  my @types = keys %{$entity->{TYPEDEFS}};
  return $types[0] if @types == 1;
  return 'unknown' unless @types;
  return 'multiple';
}

# Assert a particular triple into the KB
sub add_assertion {
  my ($kb, $subject, $verb, $object, $provenance, $confidence, $source, $comment) = @_;
  $comment = "" unless defined $comment;
  # First, normalize all of the triple components
  my $subject_entity = $kb->intern($subject, $source);
  unless (defined $subject_entity) {
    $kb->{STATS}{REJECTED_ASSERTIONS}{NO_SUBJECT}++;
    return;
  }
  $subject = $subject_entity->{NAME};
  my $subject_type = $kb->get_entity_type($subject_entity);
  $subject_type = undef unless $PredicateSet::legal_entity_types{$subject_type};
  my $object_entity;
  my $predicate = $kb->{PREDICATES}->get_predicate($verb, $subject_type, $source);
  unless (ref $predicate) {
    $kb->{STATS}{REJECTED_ASSERTIONS}{NO_PREDICATE}++;
    return;
  }
  $verb = $predicate->get_name();
  # Record entity uses and type definitions. 'type' assertions are special-cased (as they have no object)
  if ($verb eq 'type') {
    $kb->entity_use($subject_entity, 'TYPEDEF', $source);
    $kb->entity_typedef($subject_entity, $object, 'TYPEDEF', $source);
  }
  elsif ($verb eq 'link') {
    $kb->entity_use($subject_entity, 'SUBJECT', $source);
    # This tells us nothing about the type of the entity, so don't call entity_typedef
    unless ($object =~ /^"?(.*?):(.*?)"?$/) {
      $kb->{LOGGER}->record_problem('ILLEGAL_LINK_SPECIFICATION', $object, $source);
      $kb->{STATS}{REJECTED_ASSERTIONS}{BAD_PREDICATE}++;
      return;
    }
    # Remove double quotes if they're present
    $object = "$1:$2";
  }
  else {
    $kb->entity_use($subject_entity, 'SUBJECT', $source);
    $kb->entity_typedef($subject_entity, $predicate->get_domain(), 'SUBJECT', $source);
    if (&PredicateSet::is_compatible('string', $predicate->get_range())) {
      # Make sure this is a properly double quoted string
      unless ($object =~ /^"(?>(?:(?>[^"\\]+)|\\.)*)"$/) {
	# If not, complain and stick double quotes around it
	# FIXME: Need to quote internal quotes; use String::Escape
	$kb->{LOGGER}->record_problem('UNQUOTED_STRING', $object, $source);
	$object =~ s/(["\\])/\\$1/g;
	$object = "\"$object\"";
      }
    }
    if (&PredicateSet::is_compatible($predicate->get_range(), \%PredicateSet::legal_entity_types)) {
      $object_entity = $kb->intern($object, $source);
      unless (defined $object_entity) {
	$kb->{STATS}{REJECTED_ASSERTIONS}{NO_OBJECT}++;
	return;
      }
      $object = $object_entity->{NAME};
      $kb->entity_use($object_entity, 'OBJECT', $source);
      $kb->entity_typedef($object_entity, $predicate->get_range(), 'OBJECT', $source);
    }
  }
  # Check for duplicate assertions
  my $is_duplicate_of;
### DO NOT INCLUDE
  # FIXME: There's gotta be a better way
#  unless ($verb eq 'link') {
#  unless ($verb eq 'mention' || $verb eq 'canonical_mention' || $verb eq 'type') {
### DO INCLUDE
  unless ($verb eq 'mention' || $verb eq 'nominal_mention' || $verb eq 'canonical_mention' || $verb eq 'type' || $verb eq 'link') {
  existing:
    # We don't consider inferred assertions to be duplicates
    foreach my $existing (grep {!$_->{INFERRED}} $kb->get_assertions($subject, $verb, $object)) {
      # Don't worry about duplicates of assertions that have already been omitted from the output
      next if $existing->{OMIT_FROM_OUTPUT};
      # If only one is allowed, any matching assertion is a duplicate
      if ($multiple_attestations eq 'ONE') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # In all other cases, it's not a duplicate unless it was extracted from the same document
      next existing unless $existing->{PROVENANCE}->get_docid() eq $provenance->get_docid();
      if ($multiple_attestations eq 'ONEPERDOC') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # If "many" duplicate assertions are allowed, we only have a
      # problem if it is being asserted about exactly the same mention
      next if $existing->{PROVENANCE}->tostring() ne $provenance->tostring();
      # This if is entirely unnecessary, but it makes everything look nice and symmetric
      if ($multiple_attestations eq 'MANY') {
	# This is an actual duplicate of exactly the same information
	$is_duplicate_of = $existing;
	last existing;
      }
    }
  }

  # Handle single-valued slots that are given more than one filler
  my $is_multiple_of;
  if ($predicate->{QUANTITY} eq 'single') {
    foreach my $existing ($kb->get_assertions($subject, $verb)) {
      # Again, ignore assertions that have already been omitted from the output
      next if $existing->{OMIT_FROM_OUTPUT};
      if (defined $object_entity && defined $existing->{OBJECT_ENTITY}) {
	if ($object_entity != $existing->{OBJECT_ENTITY}) {
	  $is_multiple_of = $existing;
	  last;
	}
      }
      elsif ($object ne $existing->{OBJECT}) {
	$is_multiple_of = $existing;
	last;
      }
    }
  }
  # Create the assertion, but don't record it yet. We do this before
  # handling $is_duplicate_of because we may want to use the new
  # assertion rather than the duplicate
  my $assertion = {SUBJECT => $subject,
		   VERB => $verb,
		   OBJECT => $object,
		   PRINT_STRING => "$verb($subject, $object)",
		   SUBJECT_ENTITY => $subject_entity,
		   PREDICATE => $predicate,
		   OBJECT_ENTITY => $object_entity,
		   PROVENANCE => $provenance,
		   CONFIDENCE => $confidence,
		   SOURCE => $source,
		   COMMENT => $comment};
  # Only output one of a set of multiples
  if ($is_multiple_of) {
    $kb->{LOGGER}->record_problem('MULTIPLE_FILLS_ENTITY', $subject, $verb, $source);
    if ($confidence < $is_multiple_of->{CONFIDENCE}) {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($confidence > $is_multiple_of->{CONFIDENCE}) {
      $is_multiple_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($assertion->{SOURCE}{LINENUM} < $is_multiple_of->{SOURCE}{LINENUM}) {
      $is_multiple_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    else {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
  }
  # Now we can decide how to handle the duplicate
  if ($is_duplicate_of) {
    # Make sure this isn't exactly the same assertion
    if ($provenance->tostring() eq $is_duplicate_of->{PROVENANCE}->tostring()) {
      $kb->{STATS}{REJECTED_ASSERTIONS}{DUPLICATE}++;
      return;
    }
    $kb->{LOGGER}->record_problem('DUPLICATE_ASSERTION', "$is_duplicate_of->{SOURCE}{FILENAME} line $is_duplicate_of->{SOURCE}{LINENUM}", $source);
    # Keep the duplicate with higher confidence. If the confidences are the same, keep the earlier one
    if ($confidence < $is_duplicate_of->{CONFIDENCE}) {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($confidence > $is_duplicate_of->{CONFIDENCE}) {
      $is_duplicate_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($assertion->{SOURCE}{LINENUM} < $is_duplicate_of->{SOURCE}{LINENUM}) {
      $is_duplicate_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    else {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
  }
  # Record the assertion in various places for easy retrieval
  push(@{$kb->{MENTIONS}{$provenance->get_docid()}}, $assertion)
    if defined $predicate && ($predicate->{NAME} eq 'mention');
  push(@{$kb->{DOCIDS}{$subject}{$verb}{$provenance->get_docid()}}, $assertion)
    if defined $predicate && ($predicate->{NAME} eq 'mention' || $predicate->{NAME} eq 'canonical_mention' || $predicate->{NAME} eq 'nominal_mention');
  if ($predicate->{NAME} eq 'link') {
    $assertion->{OBJECT} =~ /^(.*?):(.*)$/;
    push(@{$kb->{LINKS}{$subject}{$1}}, $2);
  }
  push(@{$kb->{ASSERTIONS3}{$subject}{$verb}{$object}}, $assertion);
  push(@{$kb->{ASSERTIONS2}{$subject}{$verb}}, $assertion);
  push(@{$kb->{ASSERTIONS1}{$subject}}, $assertion);
  push(@{$kb->{ASSERTIONS0}}, $assertion);

  # We're definitely adding this assertion, so track assertion statistics
  # $kb->{STATS}{NUM_ASSERTIONS}++;
  # $kb->{STATS}{PREDICATES}{$verb || "NO_VERB"}++;
  # $kb->{STATS}{SUBJECT_TYPE}{$subject_type || "UNDEFINED"}++;
  $assertion;
}

# Select a global canonical mention for this entity
sub get_best_mention {
  my ($kb, $entity, $docid) = @_;
  my $best = "";
  if (defined $docid) {
    my @mentions = $kb->get_assertions($entity, 'canonical_mention', undef, $docid);
    if (@mentions == 1) {
      $best = $mentions[0]{OBJECT};
    }
    else {
      print $error_output "Oh dear, Wrong number of canonical mentions in document $docid\n";
    }
  } else {
    my @mentions = $kb->get_assertions($entity, 'canonical_mention');
    foreach my $mention (@mentions) {
      $best = $mention->{OBJECT} if length($mention->{OBJECT}) > length($best);
    }
  }
  $best;
}

# More handy accessors
sub get_subjects { my ($kb) = @_;                  keys %{$kb->{ASSERTIONS1}} }
sub get_verbs    { my ($kb, $subject) = @_;        keys %{$kb->{ASSERTIONS2}{$subject}} }
sub get_objects  { my ($kb, $subject, $verb) = @_; keys %{$kb->{ASSERTIONS3}{$subject}{$verb}} }
sub get_docids   { my ($kb, $subject, $verb) = @_; keys %{$kb->{DOCIDS}{$subject}{$verb}} }

# Find all assertions that match a given pattern
sub get_assertions {
  my ($kb, $subject, $verb, $object, $docid) = @_;
  $kb->{LOGGER}->NIST_die("get_assertions given both object and docid")
    if defined $object && defined $docid;

  $subject = $subject->{NAME} if ref $subject;
  $verb = $verb->{VERB} if ref $verb;
  $object = $object->{NAME} if ref $object;

  return(@{$kb->{ASSERTIONS3}{$subject}{$verb}{$object} || []}) if defined $object;
  return(@{$kb->{DOCIDS}{$subject}{$verb}{$docid} || []}) if defined $docid;
  return(@{$kb->{ASSERTIONS2}{$subject}{$verb} || []}) if defined $verb;
  return(@{$kb->{ASSERTIONS1}{$subject} || []}) if defined $subject;
  return(@{$kb->{ASSERTIONS0} || []});
}

sub get_links {
  my ($kb, $subject, $kb_target) = @_;
  return(@{$kb->{LINKS}{$subject}{$kb_target}});
}

##################################################################################### 
# Error checking and inferred relations
##################################################################################### 

# Report entities that don't have exactly one type
sub check_entity_types {
  my ($kb) = @_;
  while (my ($name, $entity) = each %{$kb->{ENTITIES}}) {
    my $type = $kb->get_entity_type($entity);
    if ($type eq 'unknown') {
      $kb->{LOGGER}->record_problem('UNKNOWN_TYPE', $name, $entity->{BESTUSE}{SOURCE});
    }
    elsif ($type eq 'multiple') {
      $kb->{LOGGER}->record_problem('MULTITYPED_ENTITY', $name,
			    join(", ", map {"$_ at line $entity->{BESTDEF}{$_}{SOURCE}{LINENUM}"}
				 sort keys %{$entity->{BESTDEF}}), 'NO_SOURCE');
    }
  }
}

# Make sure that every entity that has been mentioned or used somewhere has a typedef
sub check_definitions {
  my ($kb) = @_;
  while (my ($name, $entity) = each %{$kb->{ENTITIES}}) {
    # I suspect that having multiple types here (PER, ORG, GPE) is at this point vestigial
    foreach my $type (keys %{$entity->{BESTDEF}}) {
      # An entity that is used in any way must have an actual typedef somewhere
      $kb->{LOGGER}->record_problem('MISSING_TYPEDEF', $name, $entity->{BESTDEF}{$type}{SOURCE})
	unless $entity->{TYPEDEFS}{$type}{TYPEDEF};
    }
  }
}

# Make sure that every assertion also has an asserted inverse
sub assert_inverses {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    next unless ref $assertion->{PREDICATE};
    next unless &PredicateSet::is_compatible($assertion->{PREDICATE}{RANGE}, \%PredicateSet::legal_entity_types);
    unless ($kb->get_assertions($assertion->{OBJECT}, $assertion->{PREDICATE}{INVERSE_NAME}, $assertion->{SUBJECT})) {
      $kb->{LOGGER}->record_problem('MISSING_INVERSE', $assertion->{PREDICATE}->get_name(),
			    $assertion->{SUBJECT}, $assertion->{OBJECT}, $assertion->{SOURCE});
      # Assert the inverse if it's not already there
      my $inverse = $kb->add_assertion($assertion->{OBJECT}, $assertion->{PREDICATE}{INVERSE_NAME}, $assertion->{SUBJECT},
				       $assertion->{PROVENANCE}, $assertion->{CONFIDENCE}, $assertion->{SOURCE});
      # And flag this as an inferred relation
      $inverse->{INFERRED} = 'true';
      # Make sure the visibility of the assertion and its inverse is in sync
      $assertion->{OMIT_FROM_OUTPUT} = 'true' if $inverse->{OMIT_FROM_OUTPUT};
      $inverse->{OMIT_FROM_OUTPUT} = 'true' if $assertion->{OMIT_FROM_OUTPUT};
    }
  }
}

# Make sure that mentions and canonical_mentions are in sync
sub assert_mentions {
  my ($kb, $canonical_mentions_allowed) = @_;
  foreach my $subject ($kb->get_subjects()) {
    my %docids;
    foreach my $docid ($kb->get_docids($subject, 'mention'),
    		   $kb->get_docids($subject, 'nominal_mention'),
		       $kb->get_docids($subject, 'canonical_mention')) {
      $docids{$docid}++;
    }
    unless (keys %docids) {
      $kb->{LOGGER}->record_problem('NO_MENTIONS', $subject, 'NO_SOURCE');
      next;
    }
    foreach my $docid (keys %docids) {
      my %mentions = map {$_->{PROVENANCE}->tostring() => $_} $kb->get_assertions($subject, 'mention', undef, $docid);
      my %nominal_mentions = map {$_->{PROVENANCE}->tostring() => $_} $kb->get_assertions($subject, 'nominal_mention', undef, $docid);
      my %canonical_mentions = map {$_->{PROVENANCE}->tostring() => $_} $kb->get_assertions($subject, 'canonical_mention', undef, $docid);
      
      if($canonical_mentions_allowed && !keys %canonical_mentions && ( (scalar keys %mentions) + (scalar keys %nominal_mentions) > 1)) {
      	$kb->{LOGGER}->record_problem('MULTIPLE_MENTIONS_NO_CANONICAL', $subject, $docid, 'NO_SOURCE');
      	# There are multiple named/nominal mentions but no canonical. 
      }
      elsif ($canonical_mentions_allowed && !keys %canonical_mentions && keys %mentions) {
		$kb->{LOGGER}->record_problem('MISSING_CANONICAL', $subject, $docid, 'NO_SOURCE');
		# Pick the only named mention as the canonical mention. 
		my ($mention) = values %mentions;
		my $assertion = $kb->add_assertion($mention->{SUBJECT}, 'canonical_mention', $mention->{OBJECT},
						   $mention->{PROVENANCE}, $mention->{CONFIDENCE}, $mention->{SOURCE});
		$assertion->{INFERRED} = 'true';
      }
      elsif ($canonical_mentions_allowed && !keys %canonical_mentions && keys %nominal_mentions) {
		$kb->{LOGGER}->record_problem('MISSING_CANONICAL', $subject, $docid, 'NO_SOURCE');
		# Pick the only nominal mention as the canonical mention. 
		my ($mention) = values %nominal_mentions;
		my $assertion = $kb->add_assertion($mention->{SUBJECT}, 'canonical_mention', $mention->{OBJECT},
						   $mention->{PROVENANCE}, $mention->{CONFIDENCE}, $mention->{SOURCE});
		$assertion->{INFERRED} = 'true';
      }
      elsif ($canonical_mentions_allowed && keys %canonical_mentions > 1) {
	$kb->{LOGGER}->record_problem('MULTIPLE_CANONICAL', $subject, $docid, 'NO_SOURCE');
      }
      while (my ($string, $canonical_mention) = each %canonical_mentions) {
	# Find the mention that matches this canonical mention, if any
	my $mention = $mentions{$string};
	my $nominal_mention = $nominal_mentions{$string};
	unless ($mention || $nominal_mention) {
	  # Canonical mention without a corresponding mention
	  $kb->{LOGGER}->record_problem('UNASSERTED_MENTION', $canonical_mention->{PRINT_STRING}, $docid, $canonical_mention->{SOURCE});
	  my $assertion = $kb->add_assertion($canonical_mention->{SUBJECT}, 'mention', $canonical_mention->{OBJECT},
					     $canonical_mention->{PROVENANCE},
					     $canonical_mention->{CONFIDENCE},
					     $canonical_mention->{SOURCE});
	  $assertion->{INFERRED} = 'true';
	}
      }
    }
  }
}

# Make sure that all confidence values are legal
sub check_confidence {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    if (defined $assertion->{CONFIDENCE}) {
      # Special case a confidence value of "1" to make it a warning only
      if ($assertion->{CONFIDENCE} eq '1') {
	$kb->{LOGGER}->record_problem('MISSING_DECIMAL_POINT', $assertion->{CONFIDENCE}, $assertion->{SOURCE});
	$assertion->{CONFIDENCE} = '1.0';
      }
      unless ($assertion->{CONFIDENCE} =~ /^(?:1\.0*)$|^(?:0?\.[0-9]*[1-9][0-9]*)$/) {
	$kb->{LOGGER}->record_problem('ILLEGAL_CONFIDENCE_VALUE', $assertion->{CONFIDENCE}, $assertion->{SOURCE});
	$assertion->{CONFIDENCE} = '1.0';
      }
    }
  }
}

my @do_not_check_endpoints = (
  'type',
  'mention',
  'canonical_mention',
  'link',
);

my %do_not_check_endpoints = map {$_ => $_} @do_not_check_endpoints;

# Each endpoint of a relation that is an entity must be attested in
# a document that attests to the relation
sub check_relation_endpoints {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    next unless ref $assertion->{PREDICATE};
    next if $do_not_check_endpoints{$assertion->{PREDICATE}{NAME}};
    my $provenance = $assertion->{PROVENANCE};
    my $num_provenance_entries = $provenance->get_num_entries();
    if (defined $assertion->{SUBJECT_ENTITY}) {
      my @subject_mentions;
      for (my $i = 0; $i < $num_provenance_entries; $i++) {
	my $docid = $assertion->{PROVENANCE}->get_docid($i);
	unless(@subject_mentions) {
	  @subject_mentions = $kb->get_assertions($assertion->{SUBJECT_ENTITY}, 'mention', undef, $docid);
	  @subject_mentions = $kb->get_assertions($assertion->{SUBJECT_ENTITY}, 'nominal_mention', undef, $docid) 
	  	unless @subject_mentions;
	}
      }
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{SUBJECT_ENTITY}{NAME},
				    $provenance->tostring(),
				    $assertion->{SOURCE})
	unless @subject_mentions;
    }
    if (defined $assertion->{OBJECT_ENTITY}) {
      my @object_mentions;
      for (my $i = 0; $i < $num_provenance_entries; $i++) {
	my $docid = $assertion->{PROVENANCE}->get_docid($i);
	unless(@object_mentions) {
	  @object_mentions = $kb->get_assertions($assertion->{OBJECT_ENTITY}, 'mention', undef, $docid);
	  @object_mentions = $kb->get_assertions($assertion->{OBJECT_ENTITY}, 'nominal_mention', undef, $docid)
	  	unless @object_mentions;
	}
      }
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{OBJECT_ENTITY}{NAME},
				    $provenance->tostring(),
				    $assertion->{SOURCE})
	unless @object_mentions;
    }
  }
}

# Perform a number of basic checks to make sure that the KB is well-formed
sub check_integrity {
  my ($kb, $predicate_constraints) = @_;
  $kb->check_entity_types();
  $kb->check_definitions();
  $kb->assert_inverses();
  $kb->assert_mentions(!defined $predicate_constraints || $predicate_constraints->{'canonical_mention'});
  $kb->check_relation_endpoints();
  $kb->check_confidence();
}

# Print out all assertions
sub dump_assertions {
  my ($kb) = @_;
  my $outfile = $program_output || *STDERR{IO};
  foreach my $assertion ($kb->get_assertions()) {
    if (defined $assertion->{PREDICATE}) {
      print $outfile "p:$assertion->{PREDICATE}{NAME}";
    }
    else {
      print $outfile "v:$assertion->{VERB}";
    }
    print $outfile "($assertion->{SUBJECT}, $assertion->{OBJECT})";
    if (ref $assertion->{PROVENANCE}) {
      print $outfile " $assertion->{PROVENANCE}->tostring()";
    }
    print $outfile "\n";
  }
}
  # my $assertion = {SUBJECT => $subject,
  # 		   VERB => $verb,
  # 		   OBJECT => $object,
  # 		   PRINT_STRING => "$verb($subject, $object)",
  # 		   SUBJECT_ENTITY => $subject_entity,
  # 		   PREDICATE => $predicate,
  # 		   OBJECT_ENTITY => $object_entity,
  # 		   PROVENANCE => $provenance,
  # 		   CONFIDENCE => $confidence,
  # 		   SOURCE => $source,
  # 		   COMMENT => $comment};

sub collect_stats {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    my $status = ($assertion->{OMIT_FROM_OUTPUT} ? "OMITTED" : "ASSERTED");
    my $domain_string = $kb->get_entity_type($assertion->{SUBJECT_ENTITY});
    $kb->{STATS}{$status}{DOMAIN}{$domain_string}++;
    $kb->{STATS}{$status}{DOMAIN}{ALL}++;
    my $predicate = $assertion->{VERB};
    $predicate = "$domain_string:$predicate"
      unless $predicate eq 'type' || $predicate eq 'mention' || $predicate eq 'canonical_mention' || $predicate eq 'link';
    $kb->{STATS}{$status}{PREDICATE}{$predicate}++;
    $kb->{HAS_MULTIPLE_CONFIDENCES} = 'true'
      if defined $kb->{PREVIOUS_CONFIDENCE} && $kb->{PREVIOUS_CONFIDENCE} != $assertion->{CONFIDENCE};
    $kb->{PREVIOUS_CONFIDENCE} = $assertion->{CONFIDENCE};
  }
  while (my ($name, $entity) = each %{$kb->{ENTITIES}}) {
    my $type = $kb->get_entity_type($entity);
    $kb->{STATS}{ENTITY}{$type}++;
    $kb->{STATS}{ENTITY}{ALL}++;
  }
}

sub print_hash_stats {
  my ($header, $hash, $outfile) = @_;
  foreach my $key (sort keys %{$hash}) {
    my $value = $hash->{$key};
    if (ref $value eq 'HASH') {
      &print_hash_stats(($header ? "$header:$key" : $key), $value, $outfile);
    }
    else {
      print $outfile "$header\t$key\t$value\n";
    }
  }
}

sub print_stats {
  my ($kb, $outfile) = @_;
  print $outfile "RUNID\t\t$kb->{RUNID}\n";
#  print $outfile "FILENAME\t\t$kb->{FILENAME}\n";
  print $outfile "HAS_MULTIPLE_CONFIDENCES\t\t", $kb->{HAS_MULTIPLE_CONFIDENCES} ? "YES" : "NO", "\n";
  &print_hash_stats("", $kb->{STATS}, $outfile);
}

##################################################################################### 
# Loading and saving
##################################################################################### 

package main;

sub trim {
  my ($string) = @_;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
}

# Load a KB that is expressed in TAC format (tab-separated triples with provenance)
sub load_tac {
  my ($logger, $task, $predicates, $predicate_constraints, $filename, $docids) = @_;
  my $kb = KB->new($logger, $predicates);
  $kb->{FILENAME} = $filename;
  open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
  my $runid = <$infile>;
  chomp $runid;
  $kb->{RUNID_LINE} = $runid;
  $runid =~ s/\s*#.*//;
  $runid =~ s/^\s+//;
  $runid =~ s/\s+$//;
  if (length($runid) == 0 || $runid =~ /^:/ || $runid =~ /\s/) {
    $kb->{LOGGER}->record_problem('MISSING_RUNID', {FILENAME => $filename, LINENUM => $.});
    # The most likely explanation if the line is not blank is that the
    # runid was omitted entirely, so go back to the beginning and
    # process as if there is no runid there
    seek($infile, 0, 0) or $logger->NIST_die("Could not seek to the start of $filename: $!");
    my $date = `date`;
    $runid = 'OmittedRunID';
    $kb->{RUNID_LINE} = "OmittedRunID\t# $date  Did not find a legal run ID at the start of $filename";
  }
  $kb->{RUNID} = $runid;
  while (<$infile>) {
    chomp;
    my $source = {FILENAME => $filename, LINENUM => $.};
    my $confidence = '1.0';
    # Eliminate comments, ensuring that pound signs in the middle of
    # strings are not treated as comment characters
    s/$main::comment_pattern/$1/;
    my $comment = $2 || "";
    next unless /\S/;
    my @entries = map {&trim($_)} split(/\t/);
    # Get the confidence out of the way if it is provided
    $confidence = pop(@entries) if @entries && $entries[-1] =~ /^\d+\.\d+$/;
   
    if(@entries && $entries[-1] =~ /^\d+\.\d+e[-+]?\d\d$/) {
     $kb->{LOGGER}->record_problem('IMPROPER_CONFIDENCE_VALUE', $entries[-1], $source);
     $confidence = pop(@entries);
     $confidence = sprintf("%.12f", $confidence);
    }
    # Now assign the entries to the appropriate fields
    my ($subject, $predicate, $object, $provenance_string) = @entries;
    if (defined $predicate_constraints && !$predicate_constraints->{lc $predicate}) {
      $kb->{LOGGER}->record_problem('OFF_TASK_SLOT', $predicate, $task, $source);
      next;
    }
    my $provenance;
### DO NOT INCLUDE
#    if (lc $predicate eq 'type') {
### DO INCLUDE
    if (lc $predicate eq 'type' || lc $predicate eq 'link') {
      unless (@entries == 3) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 3, scalar @entries, $source);
	next;
      }
      $provenance = Provenance->new($logger, $source, 'EMPTY');
    }
    else {
      unless (@entries == 4) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 4, scalar @entries, $source);
	next;
      }
      $provenance = Provenance->new($logger, $source, 'PROVENANCETRIPLELIST', $provenance_string)
    }
    $kb->add_assertion($subject, $predicate, $object, $provenance, $confidence, $source, $comment);
  }
  close $infile;
  $kb->check_integrity($predicate_constraints);
#&main::dump_structure($kb, 'KB', [qw(LOGGER CONFIDENCE LABEL QUANTITY BESTDEF BESTUSE TYPEDEFS USES COMMENT INVERSE_NAME SOURCE WHERE DOMAIN RANGE)]);
#exit 0;
  $kb;
}

# When outputting TAC format, place assertions in a particular order
sub get_assertion_priority {
  my ($name) = @_;
  return 3 if $name eq 'type';
  return 2 if $name eq 'link';
  return 1 if $name eq 'mention' || $name eq 'canonical_mention';
  return 0;
}

sub assertion_comparator {
  return $a->{SUBJECT} cmp $b->{SUBJECT} unless $a->{SUBJECT} eq $b->{SUBJECT};
  my $aname = lc $a->{PREDICATE}{NAME};
  my $bname = lc $b->{PREDICATE}{NAME};
  my $apriority = &get_assertion_priority($aname);
  my $bpriority = &get_assertion_priority($bname);
  return $bpriority <=> $apriority ||
	 $aname cmp $bname ||
         $a->{PROVENANCE}->get_docid() cmp $b->{PROVENANCE}->get_docid() ||
	 $a->{PROVENANCE}->get_start() <=> $b->{PROVENANCE}->get_start();
}  

# TAC format is just a list of assertions. Output the assertions in
# the order defined by the above comparator (just to make the output
# pretty; there is no fundamental need to do so)
sub export_tac {
  my ($kb, $options) = @_;
  my $output_labels = $options->{OUTPUT_LABELS};
  print $program_output "$kb->{RUNID_LINE}\n\n";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    next unless $output_labels->{$assertion->{PREDICATE}{LABEL}};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    if ($predicate_string ne 'type' &&
	$predicate_string ne 'mention' &&
	$predicate_string ne 'canonical_mention' &&
	$predicate_string ne 'nominal_mention' &&
	$predicate_string ne 'link') {
      $domain_string = $kb->get_entity_type($assertion->{SUBJECT_ENTITY});
      next if $domain_string eq 'unknown';
      next if $domain_string eq 'multiple';
      $domain_string .= ":";
    }
    print $program_output "$assertion->{SUBJECT}\t$domain_string$assertion->{PREDICATE}{NAME}\t$assertion->{OBJECT}";
    print $program_output "\t", $assertion->{PROVENANCE}->tooriginalstring();
    print $program_output "\t$assertion->{CONFIDENCE}" if $predicate_string ne 'type';
    print $program_output $assertion->{COMMENT};
    print $program_output "\n";
  }
}

# EDL 2015 format is a tab-separated file with the following columns:
#  1. System run ID
#  2. Mention ID
#  3. Mention head string
#  4. Provenance
#  5. KBID or NIL
#  6. Entity type (GPE, ORG, PER, LOC, FAC)
#  7. Mention type (NAM, NOM)
#  8. Confidence value

sub export_edl {
  my ($kb, $options) = @_;
  my $linkkbname = $options->{LINK_KB};
  # Collect type information
  my %entity2type;
  my %entity2link;
  my $next_nilnum = "0001";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    if ($predicate_string eq 'type') {
      $entity2type{$assertion->{SUBJECT}} = $assertion->{OBJECT};
      $entity2link{$assertion->{SUBJECT}} = "NIL_" . $next_nilnum++ unless $entity2link{$assertion->{SUBJECT}};
    }
    elsif ($predicate_string eq 'link') {
      my $linkspec = $assertion->{OBJECT};
      # FIXME: Need to check for well-formedness in some less drastic way (and probably elsewhere)
      $linkspec =~ /^(.*?):(.*)$/ or $kb->{LOGGER}->NIST_die("Malformed link specification: $linkspec");
      my $linkkb = $1;
      my $kbid = $2;
      $entity2link{$assertion->{SUBJECT}} = $kbid if $linkkbname eq $linkkb;
    }
  }
  my $next_mentionid = "M00001";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    next unless $predicate_string eq 'mention' || $predicate_string eq 'nominal_mention';
    my $runid = $kb->{RUNID};
    my $mention_id = $next_mentionid++;
    my $mention_string = $assertion->{OBJECT};
    my $provenance = $assertion->{PROVENANCE}->tooriginalstring();
    my $kbid = $entity2link{$assertion->{SUBJECT}};
    my $entity_type = $entity2type{$assertion->{SUBJECT}};
    my $mention_type = $predicate_string eq 'mention' ? "NAM": "NOM";
    my $confidence = $assertion->{CONFIDENCE};
    print $program_output join("\t", $runid, $mention_id, $mention_string,
			             $provenance, $kbid, $entity_type,
			             $mention_type, $confidence), "\n";
  }
}

##################################################################################### 
# Runtime switches and main program
#####################################################################################

my %tasks = (
  CSKB => {DESCRIPTION => "Cold Start Knowledge Base variant",
	  },
  CSED => {DESCRIPTION => "Cold Start Entity Discovery variant",
	   LEGAL_PREDICATES => [qw(type mention)],
	  },
  CSEDL => {DESCRIPTION => "Cold Start Entity Discovery and Linking variant",
	    LEGAL_PREDICATES => [qw(type mention nominal_mention link)],
	   },
);

# Handle run-time switches
my $switches = SwitchProcessor->new($0,
   "Validate a TAC Cold Start KB file, checking for common errors, and optionally exporting to a variety of formats.",
   "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify a file to which output should be redirected");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch("output", "Specify the output format. Legal formats are $output_formats." .
		                  " Use 'none' to perform error checking with no output.");
$switches->put("output", 'none');
$switches->addVarSwitch("linkkb", "Specify which links should be used to produce KB IDs for the \"-output edl\" option. Legal values depend upon the prefixes found in the argument to 'link' relations in the KB being validated. This option has no effect unless \"-output edl\" has been specified.");
$switches->put("linkkb", "none");
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch("predicates", "File containing specification of additional predicates to allow");
$switches->addVarSwitch("labels", "Colon-separated list of triple labels for output. Useful in conjunction with -predicates switch.");
$switches->put("labels", "TAC");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addVarSwitch('multiple', "Are multiple assertions of the same triple allowed? " .
			"Legal values are: " . join(", ", map {"$_ ($multiple_attestations{$_})"} sort keys %multiple_attestations));
$switches->put('multiple', $multiple_attestations);
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addVarSwitch('ignore', "Colon-separated list of warnings to ignore. Legal values are: " .
			Logger->new()->get_warning_names());
$switches->addVarSwitch('task', "Specify task to validate. Legal values are: " . join(", ", map {"$_ ($tasks{$_}{DESCRIPTION})"} sort keys %tasks) . ".");
$switches->put('task', 'CSKB');
$switches->addVarSwitch('stats_file', "Specify a file into which statistics about the KB being validated will be placed");
$switches->addParam("filename", "required", "File containing input KB specification.");

$switches->process(@ARGV);

# This holds the "knowledge base"
my $kb;

my $task = uc $switches->get("task");
Logger->new()->NIST_die("Unknown task: $task (known tasks are [" . join(", ", keys %tasks) . "]")
  unless defined $tasks{$task};
my $predicate_constraints;
$predicate_constraints = {map {$_ => 'true'} @{$tasks{$task}{LEGAL_PREDICATES}}} if defined $tasks{$task}{LEGAL_PREDICATES};

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
}
elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
}
elsif (lc $output_filename ne 'none') {
  open($program_output, ">:utf8", $output_filename) or Logger->new()->NIST_die("Could not open $output_filename: $!");
}

my $error_filename = $switches->get("error_file");
if (lc $error_filename eq 'stdout') {
  $error_output = *STDOUT{IO};
}
elsif (lc $error_filename eq 'stderr') {
  $error_output = *STDERR{IO};
}
else {
  open($error_output, ">:utf8", $error_filename) or Logger->new()->NIST_die("Could not open $error_filename: $!");
}

my $logger = Logger->new(undef, $error_output);

my $stats_filename = $switches->get("stats_file");
if ($stats_filename) {
  open($statsfile, ">:utf8", $stats_filename) or die "Could not open $stats_filename: $!";
}

my $output_mode = lc $switches->get('output');
$logger->NIST_die("Unknown output mode: $output_mode") unless $type2export{$output_mode} || $output_mode eq 'none';
my $output_fn = $type2export{$output_mode};

my $predicates = PredicateSet->new($logger);

# The input file to process
my $filename = $switches->get("filename");
$logger->NIST_die("File $filename does not exist") unless -e $filename;

# What triple labels should be output?
my $labels = $switches->get("labels");
# Courtesy check that basic TAC relations are being output
my $tac_found;
foreach my $label (split(/:/, uc $labels)) {
  $output_labels{$label} = 'true';
  $tac_found++ if $label eq 'TAC';
}
print $error_output "WARNING: 'TAC' not included in output labels\n" unless $tac_found;

my $output_options = {
  OUTPUT_LABELS => \%output_labels,
  LINK_KB => uc $switches->get("linkkb"),
};

# Load any additional predicate specifications
my $predicates_file = $switches->get("predicates");
$predicates->load($predicates_file) if defined $predicates_file;

# How should multiple assertions of the same triple be handled?
$multiple_attestations = uc $switches->get("multiple");
$logger->NIST_die("Argument to -multiple switch must be one of [" . join(", ", sort keys %multiple_attestations) . "]")
  unless $multiple_attestations{$multiple_attestations};

# Add the user's selected warnings to the list of warnings to ignore
my $ignore = $switches->get("ignore");
if (defined $ignore) {
  my @warnings = map {uc} split(/:/, $ignore);
  foreach my $warning (@warnings) {
    $logger->ignore_warning($warning);
  }
}

# Load mapping from docid to length of that document
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

# Load the knowledge base
$kb = &load_tac($logger, $task, $predicates, $predicate_constraints, $filename, $docids);

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
else {
  print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
  # Output the KB if so desired
  if ($output_fn) {
    &{$output_fn}($kb, $output_options);
  }
}

if ($statsfile) {
  $kb->collect_stats();
  $kb->print_stats($statsfile);
  close $statsfile;
}

exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Original version
# 1.1 - Changed comment deletion pattern to use older syntax for possessive matches
#     - Increased robustness to ill-formed submission files
#     - Allowed multiple predicate domains and ranges
# 1.2 - Added check that entities in relations are attested in the document attesting to the relation
#     - Added switches for redirecting standard and error output
#     - Added NIST exit code on failure
#     - Modified document lengths code to accept length rather than index of last character
#     - UTF-8 compliance
#     - Allowed user-defined relations
#     - Ensured that if a relation is omitted from the output, its inverse is too
# 1.3 - Added binmode(STDOUT, ":utf8"); to avoid wide character errors
#
# 2.0 - Updated for TAC 2013
#     - per:employee_or_member_of
#     - New offset specifications (no longer pairs)
#     - Updated predicate alias list
#     - Added tac2012 input option
#
# 3.0 - Updated for TAC 2014
#     - Completely refactored
# 3.1 - Minor refactoring to help support other scripts
# 3.2 - Ensured all program exits are NIST-compliant
#
# 4.0 - First version on GitHub
# 4.1 - Added export in EDL format
# 4.2 - Fixed bug in which LINK relations were receiving a leading entity type
# 4.3 - Slightly refactored output functions; proper functioning of -linkkb switch
# 4.4 - Added checks for CSED variant
# 4.5 - Fixed mention checking in CSED task; made confidence = 0.0 illegal
# 4.6 - Incorporate changes to underlying library; remove links & export_edl for the time being
# 4.7 - Detect illegal -task specification
# 4.8 - Added FAC and LOC as legal entity types; restored links and export_edl options; added nominal_mention links
# 4.9 - General Release
# 5.0 - Version upped due to change in library
# 5.1 - nominal_mention error reporting updated; minor bug fixes
# 5.2 - MULTIPLE_MENTIONS_NO_CANONICAL error handling added. named-mention missing warnings removed when nominal and canonical are both present.
# 5.3 - Fixing the handling of multiple nominal_mentions for an entity from the same document
1;
