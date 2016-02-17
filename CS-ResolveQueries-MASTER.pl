#!/usr/bin/perl

use warnings;
use strict;

### DO NOT INCLUDE
use ColdStartLib;
### DO INCLUDE

# ResolveQueries.pl
# Author: James Mayfield (jamesmayfield "at" gmail "dot" com)
my $version = "2016.1.0";

binmode(STDOUT, ":utf8");

# This program takes input from a TAC Cold Start query file and a
# submitted knowledge base. It runs each evaluation query against the
# KB, producing one line of output for each relation traversed. I
# needed this to work on a machine without a great deal of memory, so
# the KB is processed by iteratively reading the entire KB file, then
# seeking back to the beginning of the file. As each assertion in the
# submission is processed, the program checks whether it can fulfill
# any of the tasks it has outstanding.  There are the following kinds of
# tasks:
#  1. FindEntrypointsTask: The task knows the docid and character
#     offsets of one of the evaluation queries. It is fulfilled if the
#     assertion is a mention, and the characters of the mention overlap
#     the query offsets.
#  2. FillSlotTask: The task knows a KB entity and a predicate
#     name. It is fulfilled if the assertion is of that type, and has the
#     desired entity as subject.
#  3. Entity2NameTask: The task knows an entity and a docid.  It is
#     fulfilled if the assertion is a canonical_mention for that entity
#     in that document.
# Processing starts by creating a task manager and adding a
# FindEntrypointsTask for each evaluation query to it. The KB
# submission file is then processed one assertion at a time. If the
# assertion fulfills any task that is active in the task manager, the
# action associated with that task is executed. The actions for the
# various types of task are:
#  - FindEntrypointsTask: Add the current matching entrypoint to the
#    entrypoints for this evaluation query.
#  - SelectEntrypointTask: Create a FillSlotTask for the best
#    entrypoint found for a query. Generate a FillSlotTask from first
#    relation type in the evaluation query, starting from the entity
#    that matched. Add the task to the task manager.
#  - FillSlotTask: Create and add to the task manager an
#    Entity2NameTask, which will find the canonical mention for the
#    object of the matched relation in the document that supports the
#    the relation. If the object is not an entity (e.g., for a
#    relation that takes a string filler), just record it as a slot
#    fill. If there are more hops to be found in the evaluation query,
#    it also creates another FillSlotTask that starts at the object of
#    the assertion that matched, and traverses the next slot in the
#    query.
#  - Entity2NameTask: Add the string found as canonical mention as a
#    slot fill.
# As a courtesy, the task manager keeps track of all the successfully
# matched slot fills.  Once a task has been matched, or, in the case
# of a FillSlotTask, once it has been tested against each assertion in
# the KB submission, it is deleted from the task manager. Thus, once
# the task manager has no more tasks, it terminates and returns the
# slot fills it found.

# Each type of task has a matching routine that tests whether an
# assertion fulfills any of the active tasks of that type. They are
# stored globally here for some reason.
my @retrievers;

# Keep a global list of entity types
push(@retrievers, sub  {
                    my ($taskset, $assertion) = @_;
		    $taskset->set_type($assertion->{entity}, $assertion->{object})
		      if $assertion->{predicate} eq 'type';
		    return ();
                  });

my $error_output = *STDERR;
my $logger;

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
### DO INCLUDE Switches               ColdStartLib.pm


##################################################################################### 
# Task
##################################################################################### 

# This is the base class for the various task types

package Task;

{
  my $next_id = "00000";

  sub new {
    my ($class, $query, $description, $parent) = @_;
    my $self = {QUERY => $query, DESCRIPTION => $description, ID => $next_id++, CLASS => $class};
    bless($self, $class);
    $self;
  }

}

##################################################################################### 
# FindEntrypointsTask
##################################################################################### 

package FindEntrypointsTask;

# Inherit from Task. Use -norequire because Task is defined in this file.
use parent -norequire, 'Task';

sub new {
  my ($class, $query) = @_;
  my $querymention = $query->get_entrypoint(0);
  my $self = $class->SUPER::new($query, "$class($querymention->{DOCID}:$querymention->{START}-$querymention->{END})");
  $self->{QUERYMENTION} = $querymention;
  # We will collect all candidate matching mentions here:
  bless($self, $class);
  $self;
}

# FindEntrypointsTasks are indexed only under docid; matching the entry
# point mention to the query mention is done at lookup time
sub add_to_index {
  my ($self, $taskset) = @_;
  push(@{$taskset->{INDICES}{FindEntrypoint}{$self->{QUERYMENTION}{DOCID}}}, $self);
}

# Determine whether this mention overlaps the evaluation query offsets
sub match {
  my ($self, $assertion) = @_;
  # Any mention that overlaps is a match
  !($self->{QUERYMENTION}{END} < $assertion->{start_0} || $assertion->{end_0} < $self->{QUERYMENTION}{START});
}

# Find FindEntrypointsTasks in the index that match the given assertion
push(@retrievers, sub  {
                    my ($taskset, $assertion) = @_;
		    return () unless $assertion->{predicate} eq 'mention';
		    grep {$_->match($assertion)} @{$taskset->{INDICES}{FindEntrypoint}{$assertion->{docid_0}} || []};
                  });

# Remove this FindEntrypointsTask from the TaskSet. This only reverses
# add_to_index; indexing by the position of the assertion in the KB
# file is handled by the TaskSet itself. If we are removing the task,
# it means we have looked through all possible matching
# mentions. Thus, we can now advance the one mention that best matches
# the query.
sub remove_from_index {
  my ($self, $taskset) = @_;
  $taskset->{INDICES}{FindEntrypoint}{$self->{QUERYMENTION}{DOCID}} =
    [grep {$_ != $self} @{$taskset->{INDICES}{FindEntrypoint}{$self->{QUERYMENTION}{DOCID}}}];
  # Now select the one best match for creation of a FillSlotTask
  if ($self->{BEST_MATCH}) {
    my $task = FillSlotTask->new($self->{QUERY}, $self, $self->{BEST_MATCH}{entity}, $self->{BEST_MATCH_ASSERTION});
    $taskset->add_task($task) if defined $task;
    # I think that the task manager will delete this task
    # automatically, so we don't have to $taskset->remove($self) here
    $taskset->{STATS}{ENTRYPOINTS_FOUND}++;
  }
}

# From the 2014 Guidelines:
#   The rules for mapping from an evaluation query to a knowledge base entry are as follows. First, 
#   form a candidate set of all KB node mentions that have at least one character in common with the 
#   evaluation query mention and that have the same type. If this set is empty, the submission does not 
#   contain any answers for the evaluation query. Otherwise, for each mention K in the candidate set, 
#   calculate:
#     • COMMON, the number of characters in K that are also in the query mention Q.
#     • K_ONLY, the number of characters in K that are not in Q.
#   Execute each the following eliminations until the candidate set is size one, and select that candidate 
#   as the KB node that matches the query:
#     • Eliminate any candidate that does not have the maximal value of COMMON
#     • Eliminate any candidate that does not have the minimal value of K_ONLY
#     • Eliminate all but the candidate that appears first in the submission file

# We've found an assertion that matches this FindEntrypointsTask. Save
# the assertion if it is a better match than the best match seen so
# far (or if it is the only one seen so far)
sub execute {
  my ($self, $taskset, $assertion) = @_;
  my $common = &main::min($assertion->{end_0}, $self->{QUERYMENTION}{END}) -
               &main::max($assertion->{start_0}, $self->{QUERYMENTION}{START});
  my $k_only = $assertion->{end_0} - $assertion->{start_0} - $common;
  if (defined $self->{BEST_MATCH}) {
    return if $common < $self->{COMMON};
    if ($common == $self->{COMMON}) {
      return if $k_only > $self->{K_ONLY};
      if ($k_only == $self->{K_ONLY}) {
	return if $assertion->{position} > $self->{BEST_MATCH}{position};
      }
    }
  }
  $self->{BEST_MATCH} = $assertion;
  $self->{COMMON} = $common;
  $self->{K_ONLY} = $k_only;
  $self->{BEST_MATCH_ASSERTION} = $assertion;
}

##################################################################################### 
# FillSlotTask
##################################################################################### 

package FillSlotTask;

use parent -norequire, 'Task';

sub new {
  my ($class, $query, $predecessor_task, $entity, $predecessor_assertion) = @_;
  return unless $query->{SLOTS};
  my @slots = @{$query->{SLOTS}};
#  die "Attempt to create $class with no slot list" unless @slots;
  my $slot = shift @slots;
  my $self = $class->SUPER::new($query, "$class--$slot($predecessor_assertion->{object}) from " . join(", ", caller), $predecessor_task);
  $self->{QUERY} = $query;
  $self->{PREDECESSOR} = $predecessor_task;
  $self->{ENTITY} = $entity;
  $self->{PREDECESSOR_ASSERTION} = $predecessor_assertion;
  $self->{SLOT} = $slot;
  $self->{SLOTS} = [@slots];
  bless($self, $class);
  $self;
}

# FillSlotTasks are indexed by entity and predicate
sub add_to_index {
  my ($self, $taskset) = @_;
  push(@{$taskset->{INDICES}{FillSlot}{$self->{ENTITY}}{$self->{SLOT}}}, $self);
}

push(@retrievers, sub  {
                    my ($taskset, $assertion) = @_;
		    # Slot names have colons; others (such as mention or type) do not
		    return () unless $assertion->{predicate} =~ /:/;
		    @{$taskset->{INDICES}{FillSlot}{$assertion->{entity}}{$assertion->{predicate}} || []};
                  });

sub remove_from_index {
  my ($self, $taskset) = @_;
  $taskset->{INDICES}{FillSlot}{$self->{ENTITY}}{$self->{SLOT}} =
    [grep {$_ != $self} @{$taskset->{INDICES}{FillSlot}{$self->{ENTITY}}{$self->{SLOT}}}];
}

sub execute {
  my ($self, $taskset, $assertion) = @_;
  # If the object of the assertion begins with a colon, it represents
  # an entity.
  if ($assertion->{object} =~ /^:/) {
    # Whether this is the final hop or not, find the canonical mention
    # for this entity in the supporting document. That allows the
    # query thus far to be treated independently as a shorter
    # query. We also need this task fulfilled to know what the query
    # name for the subsequent fill(s) is
    my $task = Entity2NameTask->new($self->{QUERY}, $self, $assertion->{object}, $assertion->{docid_0}, $assertion);
    $taskset->add_task($task);
    $taskset->{STATS}{FILLS_FOUND}++;
  }
  else {
    # If this is not an entity, it is a regular slot fill; there is no
    # need to look for a canonical mention. Add it to the set of
    # results
    $taskset->add_fill($self, $assertion);
    # FIXME:
    $taskset->{STATS}{FILLS_FOUND}++;
    $taskset->{STATS}{FINAL_STRING_FILLS_FOUND}++;
    # $taskset->{STATS}{FINAL_UNIQUE_STRING_FILLS_FOUND}++ unless $taskset->{DEDUP}{FINAL_UNIQUE_FILLS}{$self->{ID}}++;
    # $taskset->{STATS}{FINAL_TOTAL_FILLS_FOUND}++;
    # $taskset->{STATS}{FINAL_TOTAL_UNIQUE_FILLS_FOUND}++ unless $taskset->{DEDUP}{FINAL_UNIQUE_FILLS}{$self->{ID}}++;
  }
  # Note that we do not remove this task from the taskset yet; slot fills
  # can be filled multiple times
}

##################################################################################### 
# Entity2NameTask
##################################################################################### 

package Entity2NameTask;

use parent -norequire, 'Task';

sub new {
  my ($class, $query, $parent, $entity, $docid, $parent_assertion) = @_;
  my $self = $class->SUPER::new($query, "$class($entity)", $parent);
  $self->{ENTITY} = $entity;
  $self->{DOCID} = $docid;
  $self->{PARENT} = $parent;
  $self->{PARENT_ASSERTION} = $parent_assertion;
  bless($self, $class);
  $self;
}

# Entity2NameTasks are indexed by entity and docid; they look for the
# appropriate canonical_mention
sub add_to_index {
  my ($self, $taskset) = @_;
  push(@{$taskset->{INDICES}{Entity2Name}{$self->{ENTITY}}{$self->{DOCID}}}, $self);
}

push(@retrievers, sub  {
                    my ($taskset, $assertion) = @_;
		    return () unless $assertion->{predicate} eq 'canonical_mention';
		    @{$taskset->{INDICES}{Entity2Name}{$assertion->{entity}}{$assertion->{docid_0}} || []};
                  });

sub remove_from_index {
  my ($self, $taskset) = @_;
  $taskset->{INDICES}{Entity2Name}{$self->{ENTITY}}{$self->{DOCID}} =
    [grep {$_ != $self} @{$taskset->{INDICES}{Entity2Name}{$self->{ENTITY}}{$self->{DOCID}}}];
}

sub execute {
  my ($self, $taskset, $assertion) = @_;
  $taskset->add_fill($self->{PARENT}, $self->{PARENT_ASSERTION}, $self, $assertion);
  # There is only one fill for this task, so the task can be deleted immediately
  $taskset->remove($self);
  # Generate the next round of slot filling if necessary
  if (@{$self->{QUERY}{SLOTS}}) {
    my $filler = &TaskSet::normalize_filler($assertion->{object});
    my $provenance_string = "$assertion->{docid_0}:$assertion->{start_0}-$assertion->{end_0}";
    my $provenance = Provenance->new($logger, {FILENAME => "somewhere", LINENUM => "someline"}, 'PROVENANCETRIPLELIST', $provenance_string);
    my $next_query = $self->{QUERY}->generate_query($filler, $provenance);
    if (defined $next_query) {
      my $task = FillSlotTask->new($next_query, $self, $assertion->{entity}, $assertion);
      $taskset->add_task($task) if defined $task;
    }
  }
}

##################################################################################### 
# TaskSet
##################################################################################### 

# A TaskSet maintains a set of open tasks. It processes the assertions
# in a KB file one at a time, looking for assertions that fulfill any
# of the tasks. If the end of the KB file is reached, seek is used to
# return to the beginning, and processing continues. If all assertions
# have been matched to a task, the task is deleted.

package TaskSet;

# COUNT is the number of open tasks currently in the TaskSet
# OUTFILE is the file handle to which output should be sent
sub new {
  my ($class, $infile, $outfile) = @_;
  my $self = {COUNT => 0, INFILE => $infile, OUTFILE => $outfile};
  bless($self, $class);
  $self;
}

# Keep track of which run is currently being processed
sub set_runid {
  my ($self, $runid) = @_;
  $self->{RUNID} = $runid;
}

sub get_runid {
  my ($self) = @_;
  $self->{RUNID};
}

# Include a new task in the set of open tasks
sub add_task {
  my ($self, $task, $position) = @_;
  die "You forgot to set the runid for the TaskSet!" unless defined $self->{RUNID};
  # POSITION is the location in the input file at the time the task is
  # added. The next time we return to that place in the file, we can
  # remove this task (since we will have compared all assertions in
  # the file to the task description). Starting in 2014, POSITION is
  # usually established by add_task, rather than being passed in.
  $position = tell($self->{INFILE}) unless defined $position;
  $task->{POSITION} = $position;
  # Index this task according to the current position. We use a hash
  # rather than an array, because the entries will be sparse
  push(@{$self->{POSITIONS}{$position}}, $task);
  $self->{COUNT}++;
  # We have indexed this task according to its position in the
  # file. Now we also index it according to the particular type of
  # task
  $task->add_to_index($self);
  $self->{STATS}{TASKS}{TOTAL}++;
  $self->{STATS}{TASKS}{$task->{CLASS}}++;
}

sub get_all_entries {
  my ($self) = @_;
  my @result;
  while (my ($position, $entries) = each %{$self->{POSITIONS}}) {
    push(@result, @{$entries});
  }
  @result;
}

# Convert an evaluation query to its initial FindEntryPointTask and
# add it to the set of current tasks
sub add_evaluation_query {
  my ($self, $query) = @_;
  my $initial_task = FindEntrypointsTask->new($query);
  $self->add_task($initial_task, 0);
}

# sub add_type_collector {
#   my ($self) = @_;
#   my $type_task = FindTypeTask->new($self);
#   $self->add_task($type_task, 0);
# }

sub set_type {
  my ($self, $entity_id, $type) = @_;
  $self->{TYPES}{$entity_id} = $type;
}

sub get_type {
  my ($self, $entity_id) = @_;
  $self->{TYPES}{$entity_id};
}

# Number of open tasks
sub get_num_active_tasks {
  $_[0]->{COUNT};
}

# Find any open tasks that match the assertion, by invoking each of
# the retrieval routines stored in @retrievers
sub retrieve_tasks {
  my ($self, $assertion) = @_;
  my @result = ();
  foreach my $retriever (@retrievers) {
    push(@result, &{$retriever}($self, $assertion));
  }
  @result;
}

# We're done with this task, either because we tried all the
# assertions, or because its execute routine was satisfied and asked
# for the deletion
sub remove {
  my ($self, $task) = @_;
  $task->remove_from_index($self);
  my $position = $task->{POSITION};
  # remove_at_position might already have removed the task from POSITIONS
  if (defined $self->{POSITIONS}{$position}) {
    $self->{POSITIONS}{$position} = [grep {$_ != $task} @{$self->{POSITIONS}{$position}}];
  }
  $self->{COUNT}--;
}

# Delete all tasks that started at the current position, as long as
# they have done a seek back to the beginning at some point
sub remove_at_position {
  my ($self, $position) = @_;
  # identify currently existing tasks prior to calls to remove()
  # (which can cause new tasks to be added, so we freeze the list of
  # tasks to be removed before doing any removals)
  my @tasks = @{$self->{POSITIONS}{$position} || []};
  my @tasks_to_remove = grep {$_->{WRAPPED}} @tasks;
  my @tasks_to_keep = grep {!$_->{WRAPPED}} @tasks;
  $self->{POSITIONS}{$position} = \@tasks_to_keep;
  foreach (@tasks_to_remove) {
    $self->remove($_);
  }
}

# A filler might have tabs or newlines, which can't appear in the
# assessment files.  It is also likely to be surrounded by double
# quotes, which must be removed (along with any escaped characters in
# the string)
sub normalize_filler {
  my ($filler) = @_;
  if ($filler =~ /^"(.*)"$/) {
    $filler = $1;
    $filler =~ s/\\(.)/$1/g;
  }
  $filler =~ s/\s/ /gs;
  $filler;
}

# Keep track of the filled slots that have been found. We collect them
# in the TaskSet just as a convenience, since all the routines that
# need to return a filled slot already have access to it
sub add_fill {
  my ($self, $task, $assertion, $name_task, $name_assertion) = @_;
  # First, we construct each of the output column values
  # Column 1: Query ID
  my $query_id = $task->{QUERY}->get('FULL_QUERY_ID');
  # Column 2: Slot name
  my $slot_name = $task->{SLOT};
  # Column 3: Run ID
  my $run_id = $self->{RUNID};
  # Column 4: Full Provenance
  my $full_provenance_string = $assertion->{offsets};
  # Column 5: Slot Filler
  my $filler;
  # Column 6: Type
  my $type = $self->get_type($assertion->{object}) || 'STRING';
  # Column 7: Slot Filler Provenance
  my $filler_provenance;
  # Column 8: Confidence score
  my $confidence = $assertion->{confidence};
  # This routine either receives a single task and matching assertion
  # (if this a string-valued slot) or two such pairs, one for the
  # final hop in the query and one bearing the canonical_mention for
  # the slot fill.
  if (defined $name_task) {
    $filler = &normalize_filler($name_assertion->{object});
    $filler_provenance = $name_assertion->{offsets};
  }
  else {
    $filler = &normalize_filler($assertion->{object});
    $filler_provenance = "$assertion->{docid_0}:$assertion->{start_0}-$assertion->{end_0}";
  }
  # We've calculated all of the necessary values, so print the result
  my $outfile = $self->{OUTFILE};
  # FIXME: Should probably use the appropriate schema from ColdStartLib here
  print $outfile join("\t", ($query_id,
  			     $slot_name,
  			     $run_id,
  			     $full_provenance_string,
  			     $filler,
			     $type,
  			     $filler_provenance,
  			     $confidence,
  			    )), "\n";
}

package main;

# For each type of relation that can appear in a KB submission file,
# this table indicates the names and order of the columns (In previous
# years there was greater variety here)
my %predicate2labels = (
### DO NOT INCLUDE
# FIXME: Make sure these are still accurate
### DO INCLUDE
  type =>              [qw(entity predicate object confidence)],
  default =>           [qw(entity predicate object offsets confidence)],
);

# Convert an assertion to a hash that holds the various fields of the
# assertion. The following fields are created:
  # description
  # offsets -- parsed out (with a different index for each offset) as:
  #   docid_0
  #   start_0
  #   end_0
  # entity
  # object
  # predicate
  # predicate_end
  # predicate_start
  # position -- line number in submission file

my $counter = "assertion0001";

sub parse_assertion {
  my ($line, $position) = @_;
  # The spec didn't actually require a single tab between entries, so
  # we must ditch any fields that don't contain text
  my (@entries) = map {s/^\s+//; s/\s+$//; $_} grep {/\S/} split(/\t/, $line);
  # Some folks include a confidence on type assertions, others
  # don't. So add a confidence if none is present to make all
  # assertions uniform
  push(@entries, "1.0") unless $entries[-1] =~ /^\d+\.\d+$/;
  # Get the list of expected columns in the assertion statement
  my $predicate = lc $entries[1];
  my $labels = $predicate2labels{$predicate} || $predicate2labels{default};
  # Make sure the number of values provided matches the number
  # expected.  This should always be true if the Validator has been
  # run, but do the check anyway just to make sure
  if (@{$labels} != @entries) {
    print STDERR "\nlabels = (", join(", ", @{$labels}), "); entries = (", join(", ", @entries), ")\n";
    die "Wrong number of arguments for predicate $predicate";
  }
  # Create the hash
  my $result = {map {$labels->[$_] => $entries[$_]} 0..$#{$labels}};
  # Pull out the start and end offsets
  if (defined $result->{offsets}) {
    my $offsets = $result->{offsets};
    my @offsets = split(/,/, $offsets);
    foreach (0..$#offsets) {
      my ($docid, $start, $end) = $offsets[$_] =~ /^(.*):(\d+)-(\d+)$/ or die "illegal offset specification: $offsets[$_]";
      $result->{"docid_$_"} = $docid;
      $result->{"start_$_"} = $start;
      $result->{"end_$_"} = $end;
    }
  }
  # Add the description and position fields, which are metadata about
  # the assertion that do not appear in it
  $result->{description} = "$result->{predicate}($result->{entity}, $result->{object}) ---> <<$line>>";
  $result->{position} = $position;

  # To allow the new query ID to be generated, we must have the same
  # fields as a SF variant submission. These include: QUERY, QUERY_ID,
  # QUERY_ID_BASE, TARGET_UUID, VALUE, VALUE_PROVENANCE and TYPE.

  $result;
}

# Cycle back to the top of the KB file, find the run ID in the first
# line, skip over that line (so that we don't try to interpret the run
# ID as an assertion), and return the run ID (which may well be
# ignored, but we don't care)
sub seek_to_start {
  my ($infile, $taskset) = @_;
  seek($infile, 0, 0) or die "Could not seek to beginning of file";
  my $runid = <$infile>;
  chomp $runid;
  $runid =~ s/$main::comment_pattern/$1/;
  $runid =~ s/^\s+//;
  $runid =~ s/\s+$//;
  die "No runid found" unless $runid;
  # remove_at_position() can trigger the addition of new entries, so
  # freeze the set of entries to be wrapped here
  my @entries_to_wrap = $taskset->get_all_entries();
  # The initial tasks for the evaluation queries go in at position
  # zero. Make sure we don't forget to delete them once we've read
  # through the file the first time
  $taskset->remove_at_position(0);
  foreach my $entry (@entries_to_wrap) {
    $entry->{WRAPPED} = 'true';
  }
  $runid;
}

# Look to fulfill each of the evaluation queries in the current run file
sub process_runfile {
  my ($runfile, $evaluation_queries, $outfile) = @_;
  open(my $infile, "<:utf8", $runfile) or die "Could not open $runfile: $!";
  # Create a new task set
  my $taskset = TaskSet->new($infile, $outfile);
  # Call seek_to_start to skip over the run ID.  seek_to_start wipes
  # out tasks at position 0, so add evaluation queries afterward
  my $runid = &seek_to_start($infile, $taskset);
  $taskset->set_runid($runid);
#  $taskset->add_type_collector();
  foreach my $evaluation_query ($evaluation_queries->get_all_queries()) {
    $taskset->add_evaluation_query($evaluation_query);
  }
  # Main loop for stepping through the KB file.  We're done when no
  # active tasks remain
  while ($taskset->get_num_active_tasks()) {
    # Get the position of the assertion we're about to read in
    my $tell = tell($infile);
    # Remove any assertions already at this position; we've gone
    # through the entire file with them
    $taskset->remove_at_position($tell);
    # Get the next assertion
    local $_ = <$infile>;
    # If we didn't get anything, we're at the end of the KB file, so
    # seek back to the start and continue
    if (!defined $_) {
      &seek_to_start($infile, $taskset);
      next;
    }
    chomp;
    # KB files may contain comments.  Delete them, but make sure to
    # handle double-quoted strings properly
    s/$main::comment_pattern/$1/;
    next unless /\S/;
    my $assertion = &parse_assertion($_, $tell);
    # Find any open tasks that are fulfilled by this assertion
    my @tasks = $taskset->retrieve_tasks($assertion);
    # If any are found, run the execute method on them
    foreach my $task (@tasks) {
      $task->execute($taskset, $assertion);
    }
  }
  close $infile;
  my @toprint = (
		 {HEADER => "Entry points", FN => sub { $_[0]{ENTRYPOINTS_FOUND} }},
		 {HEADER => "Fills", FN => sub { $_[0]{FILLS_FOUND} }},
		 {HEADER => "String fills", FN => sub { $_[0]{FINAL_STRING_FILLS_FOUND} }},
		 {HEADER => "ResolutionTasks", FN => sub {$_[0]{TASKS}{TOTAL} }},
		 {HEADER => "Entity2NameTasks", FN => sub {$_[0]{TASKS}{Entity2NameTask} }},
		 {HEADER => "FillSlotTasks", FN => sub {$_[0]{TASKS}{FillSlotTask} }},
		 {HEADER => "FindEntrypointsTasks", FN => sub {$_[0]{TASKS}{FindEntrypointsTask} }},
		);

  foreach (@toprint) {
    print STDERR "\t$_->{HEADER}";
  }
  # Allow grep
  print STDERR "\tRESOLUTION_STATISTICS\n";
  print STDERR $taskset->{RUNID};
  foreach (@toprint) {
    print STDERR "\t", &{$_->{FN}}($taskset->{STATS});
  }
  # Allow grep
  print STDERR "\tRESOLUTION_STATISTICS\n";
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Apply a set of evaluation queries to a knowledge base to produce Cold Start output for assessment.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addParam("queryfile", "required", "XML file containing queries to be resolved");
$switches->addParam("runfile", "required", "Files containing input KBs");
$switches->addParam("output_file", "required", "File into which to place slot fills");
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");

$switches->process(@ARGV);

my $error_filename = $switches->get("error_file");
if (lc $error_filename eq 'stdout') {
  $error_output = *STDOUT{IO};
}
elsif (lc $error_filename eq 'stderr') {
  $error_output = *STDERR{IO};
}
else {
  open($error_output, ">:utf8", $error_filename) or die "Could not open $error_filename: $!";
}

my $query_filename = $switches->get("queryfile");
my $runfile = $switches->get("runfile");
my $output_file = $switches->get("output_file");

### DO NOT INCLUDE
# FIXME: Do we need something more specific here?
### DO INCLUDE
$logger = Logger->new();

my $queries = QuerySet->new($logger, $query_filename);
my $outfile;
my $outfile_opened;
if (lc $output_file eq 'stdout') {
  $outfile = *STDOUT{IO};
}
elsif (lc $output_file eq 'stderr') {
  $outfile = *STDERR{IO};
}
else {
  open($outfile, ">:utf8", $output_file) or die "Could not open $output_file: $!";
  $outfile_opened = 'true';
}
print STDERR "WARNING: $runfile might not be a validated Cold Start run file (it doesn't contain .valid)\n" if $runfile =~ /\./ && $runfile !~ /\.valid/;
&process_runfile($runfile, $queries, $outfile);
close $outfile if $outfile_opened;

1;

################################################################################
# Revision History
################################################################################

# 2014.1.0: Original resolver based on 2013 model
# 2014.1.1: Fixed incorrect self-documentation
# 2015.1.0: Added type column to output
# 2016.1.0: Add FULL_QUERY_ID and another minor change to make the code work
#			with new library
