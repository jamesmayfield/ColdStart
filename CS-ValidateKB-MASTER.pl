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
my $version = "2017.1.6";

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
  TAC => \&export_tac,
  EDL => \&export_edl,
  EAL => \&export_eal,
  NUG => \&export_nug,
  SEN => \&export_sen,
);

my $output_formats = "[" . join(", ", map {lc $_} sort keys %type2export) . ", none]";

##################################################################################### 
# Default values
##################################################################################### 

# Can the same assertion be made more than once?
my %multiple_attestations = (
  ONE =>       "only one allowed - no duplicates",
  ONEPERDOC => "at most one allowed per document",
  MANY =>      "any number of duplicate assertions allowed",
);
my $multiple_attestations = 'MANY';

# Which triple labels should be output?
my %output_labels = ();

# Filehandles for program and error output
my $error_output = *STDERR{IO};

### DO NOT INCLUDE
##################################################################################### 
# Library inclusions
##################################################################################### 
### DO INCLUDE
### DO INCLUDE Header           ColdStartLib.pm
### DO INCLUDE Logger           ColdStartLib.pm
### DO INCLUDE Patterns         ColdStartLib.pm
### DO INCLUDE Provenance       ColdStartLib.pm
### DO INCLUDE ProvenanceList   ColdStartLib.pm
### DO INCLUDE Predicates       ColdStartLib.pm
### DO INCLUDE Switches         ColdStartLib.pm
### DO INCLUDE Utils            ColdStartLib.pm


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
  unless ($name =~ /^:?(Entity|Event|String).+$/i && $name !~ /-/) {
    $kb->{LOGGER}->record_problem('ILLEGAL_NODE_NAME', $name, $source);
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
  my $entity = $kb->intern($name, $source);
  # A type specification with multiple types doesn't give us explicit type information, but
  # it does provide some information for immediate or later validation, so store this in
  # POSSIBLETYPES
  if (ref $type) {
    my @types = keys %{$type};
    if(@types > 1) {
      push(@{$entity->{POSSIBLETYPES}}, {TYPES=>$type, SOURCE=>$source});
      return;
    }
    $kb->{LOGGER}->NIST_die("type set with no entries in entity_typedef") unless @types;
    $type = $types[0];
  }
  $type = lc $type;
  # Only legal types may be asserted
  unless ($PredicateSet::legal_node_types{$type}) {
    $kb->{LOGGER}->record_problem('ILLEGAL_NODE_TYPE', $type, $source);
    return;
  }
  # Check if the node name is compatible with its type
  my $node_name = $entity->{NAME};
  unless ( ($PredicateSet::legal_entity_types{$type} && $node_name =~ /^:Entity.+?/) ||
   ($PredicateSet::legal_event_types{$type} && $node_name =~ /^:Event.+?/) ||
   ($PredicateSet::legal_string_types{$type} && $node_name =~ /^:String.+?/)) {
    $kb->{LOGGER}->record_problem('INCOMPATIBLE_NODE_NAME', $node_name, uc $type, $source);
    return;
  }
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
  my ($kb, $subject, $verb, $object, $provenance_string, $confidence, $source, $comment) = @_;
  $comment = "" unless defined $comment;
  my $logger = $kb->{LOGGER};
  # First, normalize all of the triple components
  my $subject_entity = $kb->intern($subject, $source);
  unless (defined $subject_entity) {
    $kb->{STATS}{REJECTED_ASSERTIONS}{NO_SUBJECT}++;
    return;
  }
  $subject = $subject_entity->{NAME};
  my $subject_type = $kb->get_entity_type($subject_entity);
  $subject_type = undef unless $PredicateSet::legal_node_types{$subject_type};
  my $realis;
  ($verb, $realis) = $kb->validate_realis($subject, $verb, $object, $source);
  my $object_entity;
  my $predicate = $kb->{PREDICATES}->get_predicate($verb, $subject_type, $source);
  unless (ref $predicate) {
    $kb->entity_use($subject_entity, 'SUBJECT', $source);
    $kb->{STATS}{REJECTED_ASSERTIONS}{NO_PREDICATE}++;
    return;
  }
  $verb = $predicate->get_name();
  my %verbs_with_restricted_prov = (
    mention => 1,
    canonical_mention => 1,
    nominal_mention => 1,
    normalized_mention => 1,
    pronominal_mention => 1,
    likes => 1,
    dislikes => 1,
    is_liked_by => 1,
    is_disliked_by => 1,
  );
  my $provenance = &get_provenance( {LOGGER => $logger,
                                       SOURCE =>$source,
                                       PROVENANCE_STRING => $provenance_string,
                                       SUBJECT => $subject,
                                       OBJECT => $object,
                                       VERB => $verb});
  foreach my $v(keys %verbs_with_restricted_prov) {
    if($verb =~ /$v/ ) {
      my %counts = $provenance->get_counts();
      $kb->{LOGGER}->record_problem('TOO_MANY_PROVENANCE_TRIPLES_E', $counts{PREDICATE_JUSTIFICATION}, $verbs_with_restricted_prov{$v}, $source)
        if($counts{PREDICATE_JUSTIFICATION}>$verbs_with_restricted_prov{$v});
    }
  }
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
    if (&PredicateSet::is_compatible('string', $predicate->get_range()) && $predicate->get_name() =~ /mention/i) {
      # Make sure this is a properly double quoted string
      unless ($object =~ /^"(?>(?:(?>[^"\\]+)|\\.)*)"$/) {
	# If not, complain and stick double quotes around it
	# FIXME: Need to quote internal quotes; use String::Escape
	$kb->{LOGGER}->record_problem('UNQUOTED_STRING', $object, $source);
	$object =~ s/(["\\])/\\$1/g;
	$object = "\"$object\"";
      }
    }
    elsif (&PredicateSet::is_compatible($predicate->get_range(), \%PredicateSet::legal_node_types)) {
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
  unless ($verb eq 'mention' || $verb eq 'nominal_mention' || $verb eq 'canonical_mention' || $verb eq 'normalized_mention' || $verb eq 'type' || $verb eq 'link') {
  existing:
    # We don't consider inferred assertions to be duplicates
    foreach my $existing (grep {!$_->{INFERRED}} $kb->get_assertions($subject, $verb, $object)) {
      # Don't worry about duplicates of assertions that have already been omitted from the output
      next if $existing->{OMIT_FROM_OUTPUT};
      my $existing_provenance = &get_provenance($existing);
      # If only one is allowed, any matching assertion is a duplicate
      if ($multiple_attestations eq 'ONE') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # In all other cases, it's not a duplicate unless it was extracted from the same document
      next existing unless $existing_provenance->get_docid() eq $provenance->get_docid();
      if ($multiple_attestations eq 'ONEPERDOC') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # If "many" duplicate assertions are allowed, we only have a
      # problem if it is being asserted about exactly the same mention
      next if $existing_provenance->tostring() ne $provenance->tostring();
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
  if ($predicate->{QUANTITY} eq 'single' && !$kb->{LOGGER}{IGNORE_WARNINGS}{MULTIPLE_FILLS_ENTITY}) {
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
  my $assertion = {LOGGER => $kb->{LOGGER},
           SUBJECT => $subject,
		   VERB => $verb,
		   OBJECT => $object,
		   PRINT_STRING => "$verb($subject, $object)",
		   SUBJECT_ENTITY => $subject_entity,
		   PREDICATE => $predicate,
		   REALIS => $realis,
		   OBJECT_ENTITY => $object_entity,
		   PROVENANCE_STRING => $provenance_string,
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
    my $is_duplicate_of_prov = &get_provenance($is_duplicate_of);
    if ($provenance->tostring() eq $is_duplicate_of_prov->tostring()) {
      $kb->{LOGGER}->record_problem('DUPLICATE_ASSERTION', "$is_duplicate_of->{SOURCE}{FILENAME} line $is_duplicate_of->{SOURCE}{LINENUM}", $source);
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
  if(defined $predicate && ($predicate->{NAME} eq 'mention' || $predicate->{NAME} eq 'nominal_mention') ) {
    $kb->{MENTIONS2}{$provenance->get_docid()}{$provenance->{PREDICATE_JUSTIFICATION}->toshortstring()}{$object}{$subject} = $assertion;
    $kb->{MENTIONS1}{$provenance->get_docid()}{$provenance->{PREDICATE_JUSTIFICATION}->toshortstring()}{$subject} = $assertion;
    push(@{$kb->{MENTIONS0}{$provenance->get_docid()}{$provenance->{PREDICATE_JUSTIFICATION}->toshortstring()}}, $assertion);
  }
  if(defined $predicate && $predicate->{NAME} eq 'pronominal_mention') {
    $kb->{PRONOMINAL_MENTIONS}{$provenance->get_docid()}{$provenance->{PREDICATE_JUSTIFICATION}->toshortstring()}{$subject} = $assertion;
  }
  push(@{$kb->{DOCIDS}{$subject}{$verb}{$provenance->get_docid()}}, $assertion)
    if defined $predicate && ($predicate->{NAME} eq 'mention' || $predicate->{NAME} eq 'canonical_mention' || $predicate->{NAME} eq 'nominal_mention' || $predicate->{NAME} eq 'pronominal_mention');
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
  return(map {@$_} values %{$kb->{ASSERTIONS3}{$subject}{$verb} || {}}) if defined $verb;
  #return(@{$kb->{ASSERTIONS2}{$subject}{$verb} || []}) if defined $verb;
  return(@{$kb->{ASSERTIONS1}{$subject} || []}) if defined $subject;
  return(@{$kb->{ASSERTIONS0} || []});
}

sub get_links {
  my ($kb, $subject, $kb_target) = @_;
  return(@{$kb->{LINKS}{$subject}{$kb_target}});
}

sub get_provenance {
  my ($assertion) = @_;
  my $provenance;
  if(lc $assertion->{VERB} eq "type" || lc $assertion->{VERB} eq "link"){
    $provenance = ProvenanceList->new($assertion->{LOGGER}, $assertion->{SOURCE});
  }
  else{
    $provenance = ProvenanceList->new($assertion->{LOGGER}, $assertion->{SOURCE},
                                        $assertion->{PROVENANCE_STRING}, $assertion->{SUBJECT},
                                        $assertion->{OBJECT}, $assertion->{VERB});
  }
  $provenance;
}

sub mention_exists {
  my ($kb, $entity, $provenance, $pronominal_mention_flag) = @_;
  my $assertion;
  if($kb->{MENTIONS1}{$provenance->get_docid()}{$provenance->toshortstring()}{$entity}) {
    $assertion = $kb->{MENTIONS1}{$provenance->get_docid()}{$provenance->toshortstring()}{$entity};
  }
  elsif($pronominal_mention_flag) {
    $assertion = $kb->{PRONOMINAL_MENTIONS}{$provenance->get_docid()}{$provenance->toshortstring()}{$entity}
      if($kb->{PRONOMINAL_MENTIONS}{$provenance->get_docid()}{$provenance->toshortstring()}{$entity});
  }
  $assertion;
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
    # Check if possible types are compatible with declared type
    if(exists $entity->{POSSIBLETYPES}) {
      foreach my $possible_types(@{$entity->{POSSIBLETYPES}}) {
        $kb->{LOGGER}->record_problem('MULTITYPED_ENTITY', $name,
            join(" or ", map {"$_"} sort keys %{$possible_types->{TYPES}})
            . " at line " . $possible_types->{SOURCE}{LINENUM} .
            " and $type at line " . $entity->{BESTUSE}{SOURCE}{LINENUM}
            , 'NO_SOURCE')
          unless exists $possible_types->{TYPES}{$type};
      }
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

# Make sure that the mention strings correspond to the text found at the given provenance
#
# This function optionally checks for the consistency of mention string found in the KB with
# the text found at the given offset in the document. This check is performed if the link to file
# containing the document text is provided in the doclength file provided using -docs switch.
sub check_mention_string {
  my ($kb) = @_;
  foreach my $subject ($kb->get_subjects()) {
    my %docids;
    foreach my $docid ($kb->get_docids($subject, 'mention'),
         $kb->get_docids($subject, 'nominal_mention'),
         $kb->get_docids($subject, 'pronominal_mention'),
		     $kb->get_docids($subject, 'canonical_mention')) {
      $docids{$docid}++;
    }
    unless (keys %docids) {
      $kb->{LOGGER}->record_problem('NO_MENTIONS', $subject, 'NO_SOURCE');
      next;
    }
    foreach my $docid (keys %docids) {
      my @mentions = ($kb->get_assertions($subject, 'mention', undef, $docid),
                               $kb->get_assertions($subject, 'nominal_mention', undef, $docid),
                               $kb->get_assertions($subject, 'pronominal_mention', undef, $docid),
                               $kb->get_assertions($subject, 'canonical_mention', undef, $docid));
      # Read the file
      my $filename;
      if(@mentions) {
        my $mention0_provenance = &get_provenance($mentions[0]);
        $filename = $mention0_provenance->get_docfile();
      }
      next unless $filename;
      my $entire_file;
      {
        local $/ = undef;
        open(my $infile, "<:utf8", $filename) or $kb->{LOGGER}->NIST_die("Source document expected at $filename: $!");
        $entire_file = <$infile>;
        close $infile;
      }
      # Check all mentions
      foreach my $mention(@mentions) {
        my $mention_string = &main::remove_quotes($mention->{OBJECT});
        my $mention_string_from_file;
        my $mention_provenance = &get_provenance($mention);
        my $start = $mention_provenance->{PREDICATE_JUSTIFICATION}->get_start();
        my $end = $mention_provenance->{PREDICATE_JUSTIFICATION}->get_end();
        $mention_string_from_file = substr($entire_file, $start, $end-$start+1);
        my $normalized_mention_string_from_file = $mention_string_from_file;
        my $normalized_mention_string = $mention_string;
        $normalized_mention_string =~ s/\s+/ /g;
        $normalized_mention_string_from_file =~ s/\s+/ /g;
        $kb->{LOGGER}->record_problem('INACCURACTE_MENTION_STRING',
                                         $mention_string,
                                         $mention_provenance->{PREDICATE_JUSTIFICATION}->tostring(),
                                         $mention->{SOURCE})
          if $normalized_mention_string ne $normalized_mention_string_from_file;
      }
    }
  }
}

# Make sure that every assertion also has an asserted inverse
sub assert_inverses {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    next if $assertion->{OBJECT} =~ /:String/;
    next unless $assertion->{OBJECT_ENTITY};
    next unless ref $assertion->{PREDICATE};
    next unless &PredicateSet::is_compatible($assertion->{PREDICATE}{RANGE}, \%PredicateSet::legal_node_types);
    # Accomodating the requirement for 2017
    # Duplicate assertions are allowed therefore generate missing inverses for all duplicates
    # An assertion is a duplicate if subject, verb, object matches but the provenance differ
    unless (grep {$assertion->{PROVENANCE_STRING} eq $_->{PROVENANCE_STRING}}
              $kb->get_assertions($assertion->{OBJECT}, $assertion->{PREDICATE}{INVERSE_NAME}, $assertion->{SUBJECT})) {
      $kb->{LOGGER}->record_problem('MISSING_INVERSE', $assertion->{PREDICATE}->get_name(),
			    $assertion->{SUBJECT}, $assertion->{OBJECT}, $assertion->{SOURCE});
      # Assert the inverse if it's not already there
      my $inverse_name = $assertion->{PREDICATE}{INVERSE_NAME};
      $inverse_name .= ".".$assertion->{REALIS} if $assertion->{REALIS};
      my $provenance = &get_provenance($assertion);
      if(exists $provenance->{FILLER_STRING} && defined $provenance->{FILLER_STRING}) {
        my $docid = $provenance->get_docid();
        my $subject = $assertion->{SUBJECT};
        my ($canonical_mention) = $kb->get_assertions($subject, 'canonical_mention', undef, $docid);
        $kb->{LOGGER}->record_problem('MISSING_CANONICAL_E', $subject, $docid, $assertion->{SOURCE})
          unless ($canonical_mention);
        my $canonical_mention_prov = &get_provenance($canonical_mention);
        $provenance->{FILLER_STRING} = $canonical_mention_prov->{PREDICATE_JUSTIFICATION};
        $kb->{LOGGER}->record_problem('MISSING_FILLER_STRING_PROV',
          $provenance->tooriginalstring(),
          $assertion->{SOURCE}) unless $provenance->{FILLER_STRING};
        if($provenance->{FILLER_STRING}) {
          my $filler_string = $provenance->{FILLER_STRING}->tooriginalstring();
          $provenance->{ORIGINAL_STRING} =~ s/^(.*?)\;/$filler_string;/;
        }
      }
      my $inverse = $kb->add_assertion($assertion->{OBJECT}, $inverse_name, $assertion->{SUBJECT},
				       $provenance->tooriginalstring(), $assertion->{CONFIDENCE}, $assertion->{SOURCE});
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
      my %mentions = map {$_->{PROVENANCE_STRING} => $_} $kb->get_assertions($subject, 'mention', undef, $docid);
      my %nominal_mentions = map {$_->{PROVENANCE_STRING} => $_} $kb->get_assertions($subject, 'nominal_mention', undef, $docid);
      my %canonical_mentions = map {$_->{PROVENANCE_STRING} => $_} $kb->get_assertions($subject, 'canonical_mention', undef, $docid);
      
      if($canonical_mentions_allowed && !keys %canonical_mentions && ( (scalar keys %mentions) + (scalar keys %nominal_mentions) > 1)) {
      	$kb->{LOGGER}->record_problem('MULTIPLE_MENTIONS_NO_CANONICAL', $subject, $docid, 'NO_SOURCE');
      	# There are multiple named/nominal mentions but no canonical. 
      }
      elsif ($canonical_mentions_allowed && !keys %canonical_mentions && keys %mentions) {
		$kb->{LOGGER}->record_problem('MISSING_CANONICAL', $subject, $docid, 'NO_SOURCE');
		# Pick the only named mention as the canonical mention. 
		my ($mention) = values %mentions;
		my $realis = "";
		$realis = ".".$mention->{REALIS} if $mention->{REALIS};
		my $assertion = $kb->add_assertion($mention->{SUBJECT}, "canonical_mention$realis", $mention->{OBJECT},
						   $mention->{PROVENANCE_STRING}, $mention->{CONFIDENCE}, $mention->{SOURCE});
		$assertion->{INFERRED} = 'true';
      }
      elsif ($canonical_mentions_allowed && !keys %canonical_mentions && keys %nominal_mentions) {
		$kb->{LOGGER}->record_problem('MISSING_CANONICAL', $subject, $docid, 'NO_SOURCE');
		# Pick the only nominal mention as the canonical mention. 
		my ($mention) = values %nominal_mentions;
		my $realis = "";
		$realis = ".".$mention->{REALIS} if $mention->{REALIS};
		my $assertion = $kb->add_assertion($mention->{SUBJECT}, "canonical_mention$realis", $mention->{OBJECT},
						   $mention->{PROVENANCE_STRING}, $mention->{CONFIDENCE}, $mention->{SOURCE});
		$assertion->{INFERRED} = 'true';
      }
      elsif ($canonical_mentions_allowed && keys %canonical_mentions > 1) {
	$kb->{LOGGER}->record_problem('MULTIPLE_CANONICAL', $subject, $docid, 'NO_SOURCE');
      }
      while (my ($string, $canonical_mention) = each %canonical_mentions) {
	# Find the mention that matches this canonical mention, if any
	my $mention = $mentions{$string};
	my $nominal_mention = $nominal_mentions{$string};
	my $realis = "";
	$realis = ".".$canonical_mention->{REALIS} if $canonical_mention->{REALIS};
	unless ($mention || $nominal_mention) {
	  # Canonical mention without a corresponding mention
	  $kb->{LOGGER}->record_problem('UNASSERTED_MENTION', $canonical_mention->{PRINT_STRING}, $docid, $canonical_mention->{SOURCE});
	  my $assertion = $kb->add_assertion($canonical_mention->{SUBJECT}, "mention$realis", $canonical_mention->{OBJECT},
					     $canonical_mention->{PROVENANCE_STRING},
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

# Check:
# (1) if assertions invloving string object entities have filler string present
# (2) if *mention* assertions have only predicate_justification provided
# (3) if the same provenance has multiple strings in the mentions, no effort is made to check if the offsets indeed represent the string in actual document
# (4) if filler_string is a mention of the object
# (5) if the provenance of a sentiment relation is a mention of the target
# (6) if the provenance of a normalized mention is a mention of the subject
# (7) if the BASE_FILLER is NILL (NILL is not an allowed value for BASE_FILLER provenance for event assertions)
sub check_provenance_lists {
  my ($kb) = @_;
  foreach my $docid(keys %{$kb->{MENTIONS2}}) {
    foreach my $span(keys %{$kb->{MENTIONS2}{$docid}}) {
      if (scalar keys (%{$kb->{MENTIONS2}{$docid}{$span}}) > 1) {
        $kb->{LOGGER}->record_problem('MULTIPLE_STRINGS_FOR_PROV', $kb->{MENTIONS0}{$docid}{$span}[0]{PROVENANCE_STRING},
          join(", ", map {"$_->{OBJECT} at line $_->{SOURCE}{LINENUM}"}
            sort {$a->{SOURCE}{LINENUM} <=> $b->{SOURCE}{LINENUM}} @{$kb->{MENTIONS0}{$docid}{$span}}), 'NO_SOURCE');
      }
    }
  }
  foreach my $assertion(@{$kb->{ASSERTIONS0}}) {
    my $assertion_prov = &get_provenance($assertion);
    $kb->{LOGGER}->record_problem('MISSING_FILLER_STRING_PROV',
          $assertion_prov->tooriginalstring(),
          $assertion->{SOURCE})
      if ($assertion->{OBJECT_ENTITY} &&
            $kb->get_entity_type($assertion->{OBJECT_ENTITY}) eq "string" &&
            ! $assertion_prov->{FILLER_STRING});
    $kb->{LOGGER}->record_problem('UNEXPECTED_PROVENANCE',
          $assertion_prov->tooriginalstring(),
          $assertion->{SOURCE})
      if ($assertion->{VERB} =~ /mention/ && (!$assertion_prov->{PREDICATE_JUSTIFICATION} ||
                                        $assertion_prov->{FILLER_STRING} ||
                                        $assertion_prov->{BASE_FILLER} ||
                                        $assertion_prov->{ADDITIONAL_JUSTIFICATION}));
    my @fields = qw(FILLER_STRING);
    foreach my $field(@fields) {
      $kb->{LOGGER}->record_problem('MISSING_MENTION_E', $field, $assertion_prov->{$field}->tooriginalstring(), $assertion->{OBJECT}, $assertion_prov->{WHERE})
        if(exists $assertion_prov->{$field} &&
          defined $assertion_prov->{$field} &&
          !$kb->mention_exists($assertion->{OBJECT}, $assertion_prov->{$field}));
    }
    # Verify if the provenance in sentiment assertion is a mention of the target (i.e. object for like and subject for dislike assertion)
    if($assertion->{VERB} eq "likes" || $assertion->{VERB} eq "dislikes") {
      $kb->{LOGGER}->record_problem('MISSING_MENTION_E', 'PREDICATE_JUSTIFICATION', $assertion_prov->{PREDICATE_JUSTIFICATION}->tooriginalstring(), $assertion->{OBJECT}, $assertion_prov->{WHERE})
        if(exists $assertion_prov->{PREDICATE_JUSTIFICATION} &&
          defined $assertion_prov->{PREDICATE_JUSTIFICATION} &&
          !$kb->mention_exists($assertion->{OBJECT}, $assertion_prov->{PREDICATE_JUSTIFICATION}, "PRONOMINAL_MENTIONS"));
    }
    elsif($assertion->{VERB} eq "is_liked_by" || $assertion->{VERB} eq "is_disliked_by") {
      $kb->{LOGGER}->record_problem('MISSING_MENTION_E', 'PREDICATE_JUSTIFICATION', $assertion_prov->{PREDICATE_JUSTIFICATION}->tooriginalstring(), $assertion->{SUBJECT}, $assertion_prov->{WHERE})
        if(exists $assertion_prov->{PREDICATE_JUSTIFICATION} &&
          defined $assertion_prov->{PREDICATE_JUSTIFICATION} &&
          !$kb->mention_exists($assertion->{SUBJECT}, $assertion_prov->{PREDICATE_JUSTIFICATION}, "PRONOMINAL_MENTIONS"));
    }
    if($assertion->{VERB} eq "normalized_mention"){
      $kb->{LOGGER}->record_problem('MISSING_MENTION_E', 'Provenance', $assertion_prov->{PREDICATE_JUSTIFICATION}->tooriginalstring(), $assertion->{SUBJECT}, $assertion_prov->{WHERE})
        unless $kb->mention_exists($assertion->{SUBJECT}, $assertion_prov->{PREDICATE_JUSTIFICATION});
    }
    # check if the BASE_FILLER is NILL (NILL is not an allowed value for BASE_FILLER provenance for event assertions)
    if($assertion->{SUBJECT} =~ /^:Event.+$/ or $assertion->{OBJECT} =~ /^:Event.+$/) {
      next if $assertion->{VERB} eq "type" or $assertion->{VERB} =~ /mention/;
      $kb->{LOGGER}->record_problem('UNEXPECTED_BASE_FILLER', 'NIL', $assertion_prov->{WHERE})
        if (not defined $assertion_prov->{BASE_FILLER} ) or ($assertion_prov->{BASE_FILLER}->tooriginalstring() eq 'NIL');
    }
  }
}

# Check if realis is present for Event assertions
sub validate_realis {
  my ($kb, $subject, $verb, $object, $source) = @_;
  my ($retval_verb, $retval_realis, $domain);
  # remove the domain from the potential_verb
  if($verb =~ /^(.*?):/) {
    $domain = $1;
    $verb =~ s/^.*?://;
  }
  my %acceptable_realis = map {$_=>1} qw(actual generic other);
  my @elements = split(/\./, $verb);
  if(@elements > 1) {
    # there is a dot in the verb
    # a realis could potentially be there
    my $potential_realis = $elements[$#elements];
    my $potential_verb = join(".", map {$elements[$_]} (0..$#elements-1));
    # There are following possible cases
    # and notice that we are not going to check the legitimacy of the verb here

    # if verb is a type
    if($potential_verb eq "type") {
      # throw an error because the realis should not be provided
      $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "none", $potential_realis, $source);

      # if the value of realis is illegal
      $kb->{LOGGER}->record_problem("ILLEGAL_REALIS", $potential_realis, $source)
        unless (exists $acceptable_realis{$potential_realis});

      $retval_verb = $potential_verb;
      $retval_realis = $potential_realis;
    }

    # if both the verb and the realis are legitimate
    # then check if the realis was required
    elsif(exists $acceptable_realis{$potential_realis} && exists $kb->{PREDICATES}{$potential_verb}) {
      # throw an error if the realis should not be provided
      $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "none", $potential_realis, $source)
        unless(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");

      $retval_verb = $potential_verb;
      $retval_realis = $potential_realis;
    }

    # if none are legitimate ------ (A)
    # then check if the original verb is legitimate
    #   - in this case the realis is missing
    #   - therefore verify if realis was required
    # otherwise there are possibly two problems here:
    #   (1) the realis is not legitimate,
    #   (2) the realis could be unexpected
    elsif(not exists $acceptable_realis{$potential_realis} && not exists $kb->{PREDICATES}{$potential_verb}) {
      if(exists $kb->{PREDICATES}{$potential_verb.".".$potential_realis}) {
        # if the original verb is legitimate
        # the realis is not there, throw an error if it was required
        $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "actual, generic, or other", "none", $source)
          if(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");
      }
      else{
        # the realis is not legitimate
        $kb->{LOGGER}->record_problem("ILLEGAL_REALIS", $potential_realis, $source);
        # throw an error if the realis should not be provided
        $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "none", $potential_realis, $source)
          unless(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");
      }
      $retval_verb = $potential_verb.".".$potential_realis;
    }

    # if verb is legitimate but the realis is not
    elsif(not exists $acceptable_realis{$potential_realis} && exists $kb->{PREDICATES}{$potential_verb}) {
      # Illegal realis used
      $kb->{LOGGER}->record_problem("ILLEGAL_REALIS", $potential_realis, $source);
      # throw an error if the realis should not be provided
      $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "none", $potential_realis, $source)
        if(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");

      $retval_verb = $potential_verb;
      $retval_realis = $potential_realis;
    }

    # if verb is not legitimate but the realis is
    elsif(exists $acceptable_realis{$potential_realis} && not exists $kb->{PREDICATES}{$potential_verb}) {
      # throw an error if the realis should not be provided
      $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "none", $potential_realis, $source)
        if(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");

      $retval_verb = $potential_verb;
      $retval_realis = $potential_realis;
    }
  }
  else {
    my $potential_verb = $verb;

    # the realis is not there, throw an error if it was required
    # notice that we are not verfying here if the verb is acceptable
    $kb->{LOGGER}->record_problem("UNEXPECTED_REALIS", "actual, generic, or other", "none", $source)
      if(($subject =~ /^:Event/ || $object =~ /^:Event/) && $potential_verb ne "type");

    $retval_verb = $potential_verb;
  }

	$retval_verb = "$domain:$retval_verb" if $domain;

  ($retval_verb, $retval_realis);
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
    my $provenance = &get_provenance($assertion);
    if (defined $assertion->{SUBJECT_ENTITY}) {
      my @subject_mentions;
	my $docid = $provenance->get_docid();
	unless(@subject_mentions) {
	  @subject_mentions = $kb->get_assertions($assertion->{SUBJECT_ENTITY}, 'mention', undef, $docid);
	  @subject_mentions = $kb->get_assertions($assertion->{SUBJECT_ENTITY}, 'nominal_mention', undef, $docid) 
	  	unless @subject_mentions;
	}
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{SUBJECT_ENTITY}{NAME},
				    $provenance->tooriginalstring(),
				    $assertion->{SOURCE})
	unless @subject_mentions;
    }
    if (defined $assertion->{OBJECT_ENTITY}) {
      my @object_mentions;
	my $docid = $provenance->get_docid();
	unless(@object_mentions) {
	  @object_mentions = $kb->get_assertions($assertion->{OBJECT_ENTITY}, 'mention', undef, $docid);
	  @object_mentions = $kb->get_assertions($assertion->{OBJECT_ENTITY}, 'nominal_mention', undef, $docid)
	  	unless @object_mentions;
	}
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{OBJECT_ENTITY}{NAME},
				    $provenance->tooriginalstring(),
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
  $kb->check_provenance_lists();
  $kb->check_mention_string();
  $kb->assert_inverses();
  $kb->assert_mentions(!defined $predicate_constraints || $predicate_constraints->{'canonical_mention'});
  $kb->check_relation_endpoints();
  $kb->check_confidence();
}

# Print out all assertions
sub dump_assertions {
  my ($kb) = @_;
  my $outfile = *STDERR{IO};
  foreach my $assertion ($kb->get_assertions()) {
    my $provenance = &get_provenance($assertion);
    if (defined $assertion->{PREDICATE}) {
      print $outfile "p:$assertion->{PREDICATE}{NAME}";
    }
    else {
      print $outfile "v:$assertion->{VERB}";
    }
    print $outfile "($assertion->{SUBJECT}, $assertion->{OBJECT})";
    if (ref $provenance) {
      print $outfile " $provenance->tostring()";
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
    $confidence = pop(@entries) if @entries && ($entries[-1] =~ /^\d+\.\d+$/ || $entries[-1] =~ /^\d+$/);
   
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
    #my $provenance;
### DO NOT INCLUDE
#    if (lc $predicate eq 'type') {
### DO INCLUDE
    my ($verb, $realis) = split(/\./, $predicate);
    if (lc $verb eq 'type' || lc $verb eq 'link') {
      unless (@entries == 3) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 3, scalar @entries, $source);
	next;
      }
      #$provenance = ProvenanceList->new($logger, $source);
    }
    else {
      unless (@entries == 4) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 4, scalar @entries, $source);
	next;
      }
      #$provenance = ProvenanceList->new($logger, $source, $provenance_string, $subject, $object, $predicate)
    }
    $kb->add_assertion($subject, $predicate, $object, $provenance_string, $confidence, $source, $comment);
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
  my $aprovenance = &KB::get_provenance($a);
  my $bprovenance = &KB::get_provenance($b);
  return $bpriority <=> $apriority ||
	 $aname cmp $bname ||
         $aprovenance->get_docid() cmp $bprovenance->get_docid() ||
	 $aprovenance->get_start() <=> $bprovenance->get_start();
}  

sub is_valid_ea_export_assertion {
  my ($assertion) = @_;
  my $retVal = "false";
  $retVal = "true"
    if $assertion->{SUBJECT} =~ /^:Event/ &&
       $assertion->{VERB} !~ /mention|type/ &&
	$retVal;
}

sub get_noun_type {
  my ($verb) = @_;
  return "NAM" if $verb eq "mention";
  return "NOM" if $verb eq "nominal_mention";
  return "PRO" if $verb eq "pronominal_mention";
  return;
}

# Export sentiments
sub export_sen {
  my ($kb, $options) = @_;
  my $sentiments_dir = $options->{SEN_OUTPUT}{PATH};
  my %verbs_of_interest = map {$_=>1} qw(mention nominal_mention pronominal_mention likes dislikes);
  my %mentions;
  my %provenance_to_mention;
  my %sentiments;
  foreach my $assertion ($kb->get_assertions()) {
    my $assertion_prov = &KB::get_provenance($assertion);
    next unless $verbs_of_interest{$assertion->{VERB}};
    if($assertion->{VERB} =~ /mention/) {
      push(@{$mentions{$assertion_prov->get_docid()}{$assertion->{SUBJECT}}}, $assertion);
    }
    else{
      push(@{$sentiments{$assertion_prov->get_docid()}{$assertion->{OBJECT}}{$assertion_prov->{PREDICATE_JUSTIFICATION}->tostring()}}, $assertion);
    }
  }
  foreach my $docid(sort keys %mentions) {
    my $source_type = "newswire";
    $source_type = "multi_post" if $docid =~ /_DF_/;
    my $runid = $kb->{RUNID};
    # ERE output
    my $outputfile_ere = "$sentiments_dir/predicted-ere/$docid.rich_ere.xml";
    my $output;
    open($output, ">:utf8", $outputfile_ere) or $kb->{LOGGER}->NIST_die("Could not open $outputfile_ere: $!");
    print $output "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $output "<deft_ere kit_id=\"$runid\" doc_id=\"$docid\" source_type=\"$source_type\">\n";
    print $output "  <entities>\n";
    foreach my $entity_nodeid(sort keys %{$mentions{$docid}}) {
      my $entity_type = uc $kb->get_entity_type($entity_nodeid, {LINENUM=>$., FILENAME=>$0});
      print $output "    <entity id=\"$entity_nodeid\" type=\"$entity_type\" specificity=\"specificIndividual\">\n";
      my $mentionid_num = 500000;
      foreach my $mention(@{$mentions{$docid}{$entity_nodeid}}) {
        $mentionid_num++;
        my $mentionid = "$entity_nodeid.$mentionid_num";
        $mention->{MENTIONID} = $mentionid;
        my $mention_prov = &KB::get_provenance($mention);
        my $provenance_string = $mention_prov->{PREDICATE_JUSTIFICATION}->tostring();
        $provenance_to_mention{$provenance_string}{$entity_nodeid} = $mention;
        my $noun_type = &get_noun_type($mention->{VERB});
        $kb->{LOGGER}->NIST_die("NOUN_TYPE undefined.") unless $noun_type;
        my $source = $docid;
        my $start = $mention_prov->{PREDICATE_JUSTIFICATION}->get_start();
        my $length = $mention_prov->{PREDICATE_JUSTIFICATION}->get_end()-$start+1;
        my $mention_text = &main::remove_quotes($mention->{OBJECT});
        print $output "      <entity_mention id=\"$mentionid\" noun_type=\"$noun_type\" source=\"$source\" offset=\"$start\" length=\"$length\">\n";
        print $output "        <mention_text>$mention_text<\/mention_text>\n";
        print $output "        <nom_head source=\"$source\" offset=\"$start\" length=\"$length\">$mention_text<\/nom_head>\n"
          if $noun_type eq "NOM";
        print $output "      <\/entity_mention>\n";
      }
      print $output "    <\/entity>\n";
    }
    print $output "  <\/entities>\n";
    print $output "<\/deft_ere>\n";
    close $output;
    # BEST output
    my $outputfile_best = "$sentiments_dir/predicted-best/$docid.best.xml";
    open($output, ">:utf8", $outputfile_best) or $kb->{LOGGER}->NIST_die("Could not open $outputfile_best: $!");
    print $output "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $output "<belief_sentiment_doc id=\"$docid\">\n";
    print $output "  <sentiment_annotations>\n";
    print $output "    <entities>\n";
    foreach my $target_nodeid(sort keys %{$sentiments{$docid}}) {
      foreach my $target_provenance_string(sort keys %{$sentiments{$docid}{$target_nodeid}}) {
        my $target_mentionid = $provenance_to_mention{$target_provenance_string}{$target_nodeid}->{MENTIONID};
        my $target_mention_text = &main::remove_quotes($provenance_to_mention{$target_provenance_string}{$target_nodeid}->{OBJECT});
        my $target_provenance = &KB::get_provenance($provenance_to_mention{$target_provenance_string}{$target_nodeid});
        my $target_offset = $target_provenance->{PREDICATE_JUSTIFICATION}->get_start();
        my $target_length = $target_provenance->{PREDICATE_JUSTIFICATION}->get_end()-$target_offset+1;
        print $output "      <entity ere_id=\"$target_mentionid\" offset=\"$target_offset\" length=\"$target_length\">\n";
        print $output "        <text>$target_mention_text<\/text>\n";
        print $output "        <sentiments>\n";
        foreach my $sentiment(@{$sentiments{$docid}{$target_nodeid}{$target_provenance_string}}) {
          my $source_nodeid = $sentiment->{SUBJECT};
          my ($source_canonical_mention_assertion) = $kb->get_assertions($source_nodeid, 'canonical_mention', undef, $docid);
          my $source_canonical_mention_assertion_provenance = &KB::get_provenance($source_canonical_mention_assertion);
          my $source_provenance_string = $source_canonical_mention_assertion_provenance->{PREDICATE_JUSTIFICATION}->tostring();
          my $source_mentionid = $provenance_to_mention{$source_provenance_string}{$source_nodeid}->{MENTIONID};
          my $source_mention_text = &main::remove_quotes($provenance_to_mention{$source_provenance_string}{$source_nodeid}->{OBJECT});
          my $source_provenance = &KB::get_provenance($provenance_to_mention{$source_provenance_string}{$source_nodeid});
          my $source_offset = $source_provenance->{PREDICATE_JUSTIFICATION}->get_start();
          my $source_length = $source_provenance->{PREDICATE_JUSTIFICATION}->get_end()-$source_offset+1;
          my $polarity = "pos";
          $polarity = "neg" if $sentiment->{VERB} eq "dislikes";
          my $confidence = $sentiment->{CONFIDENCE};
          $confidence = 1.0 unless $confidence;
          print $output "          <sentiment polarity=\"$polarity\" sarcasm=\"no\" confidence=\"$confidence\">\n";
          print $output "            <source ere_id=\"$source_mentionid\" offset=\"$source_offset\" length=\"$source_length\">$source_mention_text<\/source>\n";
          print $output "          <\/sentiment>\n";
        }
        print $output "        <\/sentiments>\n";
        print $output "      <\/entity>\n";
      }
    }
    print $output "    <\/entities>\n";
    print $output "  <\/sentiment_annotations>\n";
    print $output "<\/belief_sentiment_doc>\n";
    close $output;
  }
}

# Export Event Nuggets
sub export_nug {
  my ($kb, $options) = @_;
  my $event_nuggets_file = $options->{NUG_OUTPUT}{PATH};
  my %allowed_assertions = map {$_=>1} qw(mention nominal_mention pronominal_mention);
  my $run_id = $kb->{RUNID};
  my (%lines, %mentionids, %clusters, $output);
  foreach my $assertion(sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    next if $assertion->{SUBJECT} !~ /^:Event/;
    next unless exists $allowed_assertions{$assertion->{VERB}};
    my $provenance = &KB::get_provenance($assertion);
    my $docid = $provenance->get_docid();
    my $subject = $assertion->{SUBJECT};
    my $start = $provenance->{PREDICATE_JUSTIFICATION}->get_start();
    my $end = $provenance->{PREDICATE_JUSTIFICATION}->get_end();
    my $length = $start-$end+1;
    my ($start_span, $end_span) = ($start, $start+$length);
    my $span = "$start_span,$end_span";
    my $mention_string = &main::remove_quotes($assertion->{OBJECT});
    $mentionids{$docid} = 1 unless exists $mentionids{$docid};
    my $mentionid = "E$mentionids{$docid}";
    $mentionids{$docid}++;
    my $type = $kb->get_entity_type($subject);
    $type = join("_", map {ucfirst $_} split(/\./, $type));
    my $realis = ucfirst $assertion->{REALIS};
    my $line = join("\t", ($run_id, $docid, $mentionid, $span, $mention_string, $type, $realis));
    $clusters{$docid}{$subject}{$mentionid} = 1;
    push(@{$lines{$docid}{$subject}}, $line);
  }
  open($output, ">:utf8", $event_nuggets_file) or $kb->{LOGGER}->NIST_die("Could not open $event_nuggets_file: $!");
  foreach my $docid(sort keys %lines) {
    print $output "#BeginOfDocument $docid\n";
    foreach my $subject(sort keys %{$lines{$docid}}) {
      foreach my $line(sort @{$lines{$docid}{$subject}}) {
        print $output "$line\n";
      }
    }
    my $clusterid = 1;
    foreach my $subject(sort keys %{$lines{$docid}}) {
      print $output "\@Coreference\t$subject\t", join(",", sort keys %{$clusters{$docid}{$subject}}), "\n"
        if scalar(keys %{$clusters{$docid}{$subject}}) > 1;
    }
    print $output "#EndOfDocument\n";
  }
  close($output);
}

# Event Argument format.
sub export_eal {
  my ($kb, $options) = @_;
  my $event_argument_dir = $options->{EAL_OUTPUT}{PATH};
  my (%arguments, %linking, %corpuslinking);
  my @fields = qw(
      ID
      DOCUMENT_ID
      EVENT
      ROLE
      FILLER
      CAS
      PREDICATE_JUSTIFICATION
      BASE_FILLER
      ADDITIONAL_JUSTIFICATION
      REALIS
      CONFIDENCE
    );
  my $run_id = $kb->{RUNID};
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    if(&is_valid_ea_export_assertion($assertion) eq "true") {
      my $subject_string = $assertion->{SUBJECT};
      my $predicate_string = $assertion->{PREDICATE}{NAME};
      my $object_string = $assertion->{OBJECT};
      my $provenance = &KB::get_provenance($assertion);
      my $document_id = $provenance->get_docid();
      my ($subject_type_assertion) = $kb->get_assertions($subject_string, "type");
      my $type = $subject_type_assertion->{OBJECT};
      $type = join(".", map {ucfirst lc $_} split(/\./, $type));
      my $object_string_canonical_mention = $kb->{DOCIDS}{$object_string}{canonical_mention}{$document_id}[0]{OBJECT};
      $object_string_canonical_mention = $kb->{ASSERTIONS3}{$subject_string}{$predicate_string}{$object_string}[0]{OBJECT}
        unless $object_string_canonical_mention;
      if($object_string =~ /^:String.+?/) {
        my ($normalized_mention) = grep {&KB::get_provenance($_)->{DOCID} eq $document_id}
                                     $kb->get_assertions($object_string, 'normalized_mention', undef, undef);
        $object_string_canonical_mention = $normalized_mention->{OBJECT} if $normalized_mention;
      }
      $object_string_canonical_mention = &main::remove_quotes($object_string_canonical_mention);
      my $object_string_provenance = &KB::get_provenance($kb->{DOCIDS}{$object_string}{canonical_mention}{$document_id}[0]);
      my $object_string_provenance_string = $object_string_provenance->{PREDICATE_JUSTIFICATION}->toshortstring();
      my $confidence = $assertion->{CONFIDENCE};
      my ($predicate_justification, $base_filler, $additional_justification) = ("NIL", "NIL", "NIL");
      $predicate_justification = $provenance->{PREDICATE_JUSTIFICATION}->toshortstring()
        if $provenance->{PREDICATE_JUSTIFICATION};
      $base_filler = $provenance->{BASE_FILLER}->toshortstring() if $provenance->{BASE_FILLER};
      $additional_justification = $provenance->{ADDITIONAL_JUSTIFICATION}->toshortstring()
        if $provenance->{ADDITIONAL_JUSTIFICATION};
      my $realis = ucfirst lc $assertion->{REALIS};
      $predicate_string = ucfirst lc $predicate_string;
      my $id = $arguments{$document_id} ? scalar @{$arguments{$document_id}} + 1 : 1;
      my $node_id = $subject_string;
      $subject_string = join(".", ("$run_id$node_id",$document_id,$id)); 
      my @output = (
          $subject_string,
          $document_id,
          $type,
          $predicate_string,
          $object_string_canonical_mention,
          $object_string_provenance_string,
          $predicate_justification,
          $base_filler,
          $additional_justification,
          $realis,
          $confidence);
      my %output_line = map {$fields[$_]=>$output[$_]} (0..$#fields);
      push(@{$arguments{$document_id}}, \%output_line);
      if($realis ne "Generic"){
        push(@{$linking{$document_id}{$node_id}}, "$subject_string");
        $corpuslinking{$node_id}{"$document_id-$run_id$node_id.$document_id"} = 1;
      }
    }
  }

  # Generate the argument file
  foreach my $document_id(keys %arguments){
    open(ARGUMENT, ">>$event_argument_dir/arguments/$document_id");
    foreach my $line(@{$arguments{$document_id}}) {
      print ARGUMENT join("\t", map {$line->{$_}} @fields), "\n";
    }
    close(ARGUMENT);
  }

  # Generate the linking file
  foreach my $document_id(keys %linking) {
    open(LINKING, ">>$event_argument_dir/linking/$document_id");
    foreach my $node_id(keys %{$linking{$document_id}}) {
      print LINKING "$run_id$node_id.$document_id\t", join(" ", sort @{$linking{$document_id}{$node_id}}), "\n";
    }
    close(LINKING);
  }

  # Generate the corpus linking file
  foreach my $node_id(sort keys %corpuslinking) {
    open(CORPUS_LINKING, ">>$event_argument_dir/corpusLinking/corpusLinking");
    print CORPUS_LINKING "$run_id$node_id\t", join(" ", sort keys %{$corpuslinking{$node_id}}), "\n";
    close(CORPUS_LINKING);
  }
}

# TAC format is just a list of assertions. Output the assertions in
# the order defined by the above comparator (just to make the output
# pretty; there is no fundamental need to do so)
sub export_tac {
  my ($kb, $options) = @_;
  my $output_labels = $options->{OUTPUT_LABELS};
  my $output_filename = $options->{TAC_OUTPUT}{PATH};
  my $program_output;
  open($program_output, ">:utf8", $output_filename) or Logger->new()->NIST_die("Could not open $output_filename: $!");
  print $program_output "$kb->{RUNID_LINE}\n\n";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    next unless $output_labels->{$assertion->{PREDICATE}{LABEL}};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $assertion_prov = &KB::get_provenance($assertion);
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    if ($predicate_string ne 'type' &&
	$predicate_string ne 'mention' &&
	$predicate_string ne 'canonical_mention' &&
	$predicate_string ne 'nominal_mention' &&
    $predicate_string ne 'pronominal_mention' &&
	$predicate_string ne 'normalized_mention' &&
	$predicate_string ne 'link') {
      $domain_string = $kb->get_entity_type($assertion->{SUBJECT_ENTITY});
      next if $domain_string eq 'unknown';
      next if $domain_string eq 'multiple';
      $domain_string .= ":";
    }
    my $predicate_name = $assertion->{PREDICATE}{NAME};
    $predicate_name .= ".".$assertion->{REALIS} if $assertion->{REALIS};
    print $program_output "$assertion->{SUBJECT}\t$domain_string$predicate_name\t$assertion->{OBJECT}";
    print $program_output "\t", $assertion_prov->tooriginalstring();
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
  my $output_filename = $options->{EDL_OUTPUT}{PATH};
  my $program_output;
  open($program_output, ">:utf8", $output_filename) or Logger->new()->NIST_die("Could not open $output_filename: $!");
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
    next if $assertion->{SUBJECT} =~ /^:Event/;
    my $provenance = &KB::get_provenance($assertion);
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    next unless $predicate_string eq 'mention' || $predicate_string eq 'nominal_mention';
    my $runid = $kb->{RUNID};
    my $mention_id = $next_mentionid++;
    $mention_id = $assertion->{SUBJECT}."_".$mention_id;
    my $mention_string = &main::remove_quotes($assertion->{OBJECT});
    my $provenance_string = $provenance->tooriginalstring();
    my $kbid = $entity2link{$assertion->{SUBJECT}};
    my $entity_type = uc $entity2type{$assertion->{SUBJECT}};
    my $mention_type = $predicate_string eq 'mention' ? "NAM": "NOM";
    my $confidence = $assertion->{CONFIDENCE};
    print $program_output join("\t", $runid, $mention_id, $mention_string,
			             $provenance_string, $kbid, $entity_type,
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
$switches->addVarSwitch('output_dir', "Specify a directory to which output files should be written. Default would be the directory containing the KB to be validated.");
$switches->addVarSwitch("output", "Colon-separated list of output formats. Legal formats are $output_formats." .
		                  " Use 'none' to perform error checking with no output.");
$switches->put("output", 'none');
$switches->addVarSwitch("linkkb", "Specify which links should be used to produce KB IDs for the \"-output edl\" option. Legal values depend upon the prefixes found in the argument to 'link' relations in the KB being validated. This option has no effect unless \"-output edl\" has been specified.");
$switches->put("linkkb", "LDC2015E42");
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
$switches->put('ignore', 'MULTIPLE_FILLS_ENTITY');
$switches->addVarSwitch('task', "Specify task to validate. Legal values are: " . join(", ", map {"$_ ($tasks{$_}{DESCRIPTION})"} sort keys %tasks) . ".");
$switches->put('task', 'CSKB');
$switches->addVarSwitch('stats_file', "Specify a file into which statistics about the KB being validated will be placed");
$switches->addParam("filename", "required", "File containing input KB specification.");

$switches->process(@ARGV);

# This holds the "knowledge base"
my $kb;

my $logger = Logger->new(undef, $error_output);

# The input file to process
my $filename = $switches->get("filename");
my ($input_dir, $output_prefix) = $filename =~ /((?:[^\/]*\/)*)(.*)/;
$input_dir =~ s/\/+$//g;
$output_prefix =~ s/\.tac$//;
$logger->NIST_die("File $filename does not exist") unless -e $filename;

my $task = uc $switches->get("task");
$logger->NIST_die("Unknown task: $task (known tasks are [" . join(", ", keys %tasks) . "]")
  unless defined $tasks{$task};
my $predicate_constraints;
$predicate_constraints = {map {$_ => 'true'} @{$tasks{$task}{LEGAL_PREDICATES}}} if defined $tasks{$task}{LEGAL_PREDICATES};

# Setup $output_dir
my $output_dir = $switches->get("output_dir");
if($output_dir) {
	# If the output directory is provided
  unless(-d $output_dir) {
    # If the output directory does not exist
    $logger->NIST_die("$output_dir exists but its not a directory") if(-e $output_dir);
    system("mkdir $output_dir") or $logger->NIST_die("Could not create directory $output_dir: $!");;
  }
}
else {
  # Set the output directory to the directory containing input file
  $output_dir = ".";
  $output_dir = $input_dir unless $input_dir =~ /^\s*$/;
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
  TAC_OUTPUT => {TYPE => "FILE", PATH => "$output_dir/$output_prefix.tac.valid"},
  EDL_OUTPUT => {TYPE => "FILE", PATH => "$output_dir/$output_prefix.edl.valid"},
  EAL_OUTPUT => {TYPE => "DIR", PATH => "$output_dir/event_arguments", SUBDIR => [qw(arguments corpusLinking linking)]},
  NUG_OUTPUT => {TYPE => "FILE", PATH => "$output_dir/$output_prefix.nug.valid"},
  SEN_OUTPUT => {TYPE => "DIR", PATH => "$output_dir/sentiments", SUBDIR => [qw(predicted-ere predicted-best)]},
};

my $output_modes = lc $switches->get('output');
my %output_modes_selected;
foreach my $output_mode (split(/:/, $output_modes)) {
	$output_modes_selected{uc $output_mode} = 1;
  $logger->NIST_die("Unknown output mode: $output_mode") unless $type2export{uc $output_mode} || lc $output_mode eq 'none';
  my $output_option = uc $output_mode . "_OUTPUT";
  my $output_path = $output_options->{$output_option}{PATH};
  # Generate an error if the output file already exists
  $logger->NIST_die("Output file already exists at $output_path: $!")
    if $output_options->{$output_option}{TYPE} eq "FILE" && -e $output_path;
  # Generate an error if the output directory already exists
  $logger->NIST_die("Output directory already exists at $output_path: $!")
    if $output_options->{$output_option}{TYPE} eq "DIR" && -d $output_path;
  if ($output_options->{$output_option}{TYPE} eq "DIR") {
    # Create the output directories
    system("mkdir $output_path");
    foreach my $subdir(@{$output_options->{$output_option}{SUBDIR}}) {
      system("mkdir $output_path/$subdir");
    }
  }
}

my $stats_filename = $switches->get("stats_file");
if ($stats_filename) {
  open($statsfile, ">:utf8", $stats_filename) or die "Could not open $stats_filename: $!";
}

my $predicates = PredicateSet->new($logger);

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
    my ($docid, $document_length, $file) = split(/\t/);
    $docids->{$docid} = {LENGTH=>$document_length, FILE=>$file};
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
  foreach my $output_mode (split(/:/, uc $output_modes)) {
    my $output_fn = $type2export{$output_mode};
    &{$output_fn}($kb, $output_options) if $output_fn;
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
# 2017.1.0 - First release of 2017
# 2017.1.1 - Warning: MULTIPLE_FILLS_ENTITY is now being ignored by default since 2017 specification allows multiple fills
#          - We are also passing multiple fills for single-valued slots onto the validated KB; Only the best node is picked later on for scoring purposes
# 2017.1.2 - Adding logger object to assertions
#          - Reduced memory requirements
# 2017.1.3 - BUGFIX: An error was incorrectly thrown when an existing pronominal mention appeared as a provenance of sentiment relation
# 2017.1.4 - Removing domain name from pronominal_mention
# 2017.1.5 - INCLUDEs etc updated to allow Include.pl to successfully create standalone executables
# 2017.1.6 - INACCURACTE_MENTION_STRING made a WARNING instead of an ERROR
1;
