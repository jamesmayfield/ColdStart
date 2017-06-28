#!/usr/bin/perl -w
use warnings;
use strict;
use utf8;
use Carp;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

my $version = "2017.0.1";

# Filehandles for program and error output
my $program_output;
my $error_output;

# Constants
my $NUM_RELATIONS = 5;
my $MAX_DOCNUM = 10;
my $MAX_START = 150;

package RelationSet;

sub new {
  my ($class, $logger) = @_;
  my $self = {
    LOGGER => $logger,
    RELATIONS => [], 
  };  
  bless($self, $class);
  $self;
}

sub add {
  my ($self, $relation) = @_;
  push(@{$self->{RELATIONS}}, $relation);
}

sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

sub get_ALL_RELATIONS {
  my ($self) = @_;
  $self->{RELATIONS};
}


sub tostring {
  my ($self) = @_;
  join ("\n", map {$_->tostring()} @{$self->{RELATIONS}});
}

package _Provenance;

sub new {
  my ($class, $logger, $mention_string, $docid, $span) = @_;
  my $self = {
    LOGGER => $logger,
  };
  bless($self, $class);
  $self->populate_from_text($mention_string, $docid, $span);
  $self;
}

sub populate_from_text {
  my ($self, $mention_string, $docid, $span) = @_;
  my $length;
  $length = length($mention_string) if $mention_string;
  $length = &_Utils::rand(60) unless $length;
  ($self->{START}, $self->{END}) = split("-", $span) if $span;
  $self->{START} = &_Utils::rand($MAX_START) unless $self->{START};
  $self->{END} = $self->{START} + $length - 1 unless $self->{END};
  $self->{DOCUMENTID} = $docid if $docid;
  $self->{DOCUMENTID} = "SIMPSONS_0".(&_Utils::rand($MAX_DOCNUM)+10) unless $docid;
}

sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

sub get_DOCUMENTID {
  my ($self) = @_;
  $self->{DOCUMENTID};
}

sub tostring {
  my ($self) = @_;
  "$self->{DOCUMENTID}:$self->{START}-$self->{END}";
}

package Relation;

sub new {
  my ($class, $logger, $subject, $verb, $object, $entities) = @_;
  my $self = {
    LOGGER => $logger,
    SUBJECT => $entities->get($subject),
    OBJECT => $entities->get($object),
    VERB => $verb,
    PROVENANCE => undef,
  };
  bless($self, $class);
  $self->generate_provenance();
  my $docid = $self->{PROVENANCE}->get("DOCUMENTID");
  $self;
}

sub generate_provenance {
  my ($self) = @_;
  $self->{PROVENANCE} = _Provenance->new($self->{LOGGER});
}

sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

sub get_DOCUMENTID {
  my ($self) = @_;
  $self->{PROVENANCE}->get("DOCUMENTID");
}

sub tostring {
  my ($self) = @_;
  my $subject = $self->{SUBJECT}->get("NAME");
  my $object = $self->{OBJECT}->get("NAME");
  my $verb = $self->{VERB};
  my $provenance = $self->{PROVENANCE}->tostring();
  my $confidence = &_Utils::rand();
  join("\t", ($subject, $verb, $object, $provenance, $confidence));
}

package Mention;

sub new {
  my ($class, $logger, $mention_string, $docid, $span) = @_;
  my $self = {
    LOGGER => $logger,
    STRING => $mention_string,
    PROVENANCE => _Provenance->new($logger, $mention_string, $docid, $span),
  };
  bless($self, $class);
  $self;
}

sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

sub get_DOCUMENTID {
  my ($self) = @_;
  $self->{PROVENANCE}->get("DOCUMENTID");
}

sub get_START {
  my ($self) = @_;
  $self->{PROVENANCE}->get("START");  
}

sub get_END {
  my ($self) = @_;
  $self->{PROVENANCE}->get("END");  
}


sub get_PROVENANCE {
  my ($self) = @_;
  $self->{PROVENANCE}->tostring();
}

sub tostring {
  my ($self, $entityname) = @_;
  join("\t", ($entityname, "mention", $self->get("STRING"), $self->{PROVENANCE}->tostring()));
}


package MentionSet;

sub new {
  my ($class, $logger) = @_;
  my $self = {
    LOGGER => $logger,
    MENTIONS => [],
  };
  bless($self, $class);
  $self;  
}

sub add_mention {
  my ($self, $mention_string, $docid, $span) = @_;
  push(@{$self->{MENTIONS}}, Mention->new($self->{LOGGER}, $mention_string, $docid, $span));
}

sub get_docids {
  my ($self) = @_;
  keys {map {$_->get("DOCUMENTID")=>1} @{$self->{MENTIONS}}};
}

sub get_strings {
  my ($self) = @_;
  map {$_->get("STRING")} @{$self->{MENTIONS}};
}

sub has_document {
  my ($self, $docid) = @_;
  grep {$_ eq $docid} $self->get_docids();
}

sub tostring {
  my ($self, $entityname) = @_;
  join("\n", map {$_->tostring($entityname)} 
               sort { $a->get("DOCUMENTID") cmp $b->get("DOCUMENTID") || 
               	      $a->get("START")<=>$b->get("START")} 
               	 @{$self->{MENTIONS}});
}

package EntitySet;

sub new {
  my ($class, $logger) = @_;
  my $self = {
    LOGGER => $logger,
    ALL_ENTITIES => [],
    ENTITIES_BY_NAME => {},
  };
  bless($self, $class);
  $self;
}

sub add {
  my ($self, $entity) = @_;
  push(@{$self->{ALL_ENTITIES}}, $entity);
  $self->{ENTITIES_BY_NAME}{$entity->get("NAME")} = $entity;
}

# Create or return an entity
sub get {
  my ($self, $name) = @_;
  unless($self->{ENTITIES_BY_NAME}{$name}) {
    $self->add(Entity->new($self->{LOGGER}, $name));
  }
  $self->{ENTITIES_BY_NAME}{$name};
}

sub tostring {
  my ($self) = @_;
  join ("\n", map {$_->tostring()} @{$self->{ALL_ENTITIES}});
}

package Entity;

use List::Util qw(shuffle);

sub new {
  my ($class, $logger, $name) = @_;
  my $self = {
    LOGGER => $logger,
    NAME => $name,
    TYPE => undef,
    MENTIONS => MentionSet->new($logger),
  };
  bless($self, $class);
  $self;
}

sub set {
  my ($self, $field, $value, @args) = @_;
  my $method = $self->can("set_$field");
  $method->($self, $value, @args) if $method;
  $self->{$field} = $value unless $method;
}

sub set_MENTIONS {
  my ($self, $value, $specific_entrypoint) = @_;
  my @mentions = split(",", $value);
  if($specific_entrypoint) {
    my ($docid, $span) = split(":", $specific_entrypoint);
    $self->{MENTIONS}->add_mention(pop @mentions, $docid, $span);    
  }
  foreach my $mention(@mentions) {
  	$mention =~ s/^\s+|\s+$//g;
    $self->{MENTIONS}->add_mention($mention);
  }
}

# Return the field if it's defined. Otherwise, invoke the corresponding get method
sub get {
  my ($self, $field) = @_;
  return $self->{$field} if defined $self->{$field};
  my $method = $self->can("get_$field");
  return $method->($self) if $method;
  return;
}

sub get_MENTION_DOCS {
  my ($self) = @_;
  $self->{MENTIONS}->get_docids();
}

sub get_MENTION_STRINGS {
  my ($self) = @_;
  $self->{MENTIONS}->get_strings();
}

sub has {
  my ($self, $field, $value) = @_;
  my $method = $self->can("has_$field");
  return $method->($self, $value);
  return $self->{$field} if defined $self->{$field};
  return;
}

sub has_MENTION_DOC {
  my ($self, $docid) = @_;
  return $self->{MENTIONS}->has_document($docid);
}

sub assert_mention {
  my ($self, $docid, $span) = @_;
  return if $self->has("MENTION_DOC", $docid);
  my @mention_strings = $self->get("MENTION_STRINGS");
  my ($mention_string) = shuffle @mention_strings;
  $self->{MENTIONS}->add_mention($mention_string, $docid, $span);
}

sub tostring {
  my ($self) = @_;
  my $string = "";
  my $name = $self->get("NAME");
  my $type = $self->get("TYPE");
  $string .= join("\t", ($name, "type", $type)); 
  $string .= "\n";
  $string .= $self->{MENTIONS}->tostring($name); 
  $string;
}

package _Utils;

sub rand {
  my ($arg) = @_;
  return int(rand($arg))+1 if $arg;
  return sprintf("%0.4f", rand(1)) unless $arg;
}

package KB;

sub new {
  my ($class, $logger, $filename, $kbname) = @_;
  my $self = {
    LOGGER => $logger,
    NAME => $kbname,
    FILENAME => $filename,
    ENTITIES => EntitySet->new($logger),
    RELATIONS => RelationSet->new($logger),
  };
  bless($self, $class);
  $self->load($filename);
  $self;
}

sub load {
  my ($self, $filename) = @_;
  open(FILE, $filename);
  my $kb_name = <FILE>;
  chomp $kb_name;
  $self->{NAME} = $kb_name unless $self->{NAME};
  while(my $line = <FILE>) {
    chomp $line;
    next if $line =~ /^\s*$/;
	next if $line =~ /^\s*\#/;
    $self->populate_from_line($line);    
  }
  foreach my $relation(@{$self->{RELATIONS}->get("ALL_RELATIONS")}) {
    $relation->{SUBJECT}->assert_mention($relation->get("DOCUMENTID"));
    $relation->{OBJECT}->assert_mention($relation->get("DOCUMENTID"));
  }
  close(FILE);
}

sub populate_from_line {
  my ($self, $line) = @_;
  my ($subject, $verb, $objects) = split("\t", $line);
  if($verb eq "type") {
    $self->populate_from_type_line($line);
  }
  elsif($verb eq "mentions") {
    $self->populate_from_mentions_line($line);
  }
  else{
    $self->populate_from_relations_line($line);
  }  
}

sub populate_from_type_line {
  my ($self, $line) = @_;
  my ($entity_name, $verb, $type) = split("\t", $line);
  my $entity = $self->{ENTITIES}->get($entity_name);
  $entity->set("TYPE", $type);
}

sub populate_from_mentions_line {
  my ($self, $line) = @_;
  my ($entity_name, $verb, $mentions, $specific_entrypoint) = split("\t", $line);
  my $entity = $self->{ENTITIES}->get($entity_name);
  $entity->set("MENTIONS", $mentions, $specific_entrypoint);
}

sub populate_from_relations_line {
  my ($self, $line) = @_;
  my ($subject, $verb, $objects) = split("\t", $line);
  foreach my $object(split(",", $objects)) {
  	$object =~ s/^\s+|\s+$//g;
  	for(my $i=1; $i<=$NUM_RELATIONS; $i++) {
      my $relation = Relation->new($self->{LOGGER}, $subject, $verb, $object, $self->{ENTITIES});
      $self->{RELATIONS}->add($relation);
  	}
  }
}


sub tostring {
  my ($self) = @_;
  my $string = "$self->{NAME}\n";
  $string .= $self->{ENTITIES}->tostring();
  $string .= "\n";
  $string .= $self->{RELATIONS}->tostring();  
  $string;  
}



# Handle run-time switches
my $switches = SwitchProcessor->new($0,
   "Expand the compact KB into standard KB (used for generating testing cases out of compact KBs)",
   "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);

$switches->addVarSwitch('output_file', "Where should program output be sent? (prefix of filename, stdout or stderr)");
$switches->put('output_file', 'stdout');
$switches->addVarSwitch('kbname', "What should be the output system name?");
$switches->addVarSwitch("error_file", "Where should error output be sent? (filename, stdout or stderr)");
$switches->put("error_file", "stderr");
$switches->addParam("filename", "required", "File containing query output.");

my $argsin = join(" ", @ARGV);

$switches->process(@ARGV);

my $logger = Logger->new();

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if ($output_filename eq 'none') {
  undef $program_output;
}
elsif (lc $output_filename eq 'stdout') {
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

my $kb_name = $switches->get("kbname");

my $filename = $switches->get("filename");
my $kb = KB->new($logger, $filename, $kb_name);

print $program_output $kb->tostring();

close($program_output) if $program_output;

$logger->report_all_problems();

# The NIST submission system wants an exit code of 255 if errors are encountered
my $num_errors = $logger->get_num_errors();
$logger->NIST_die("$num_errors error" . $num_errors == 1 ? "" : "s" . "encountered")
  if $num_errors;
