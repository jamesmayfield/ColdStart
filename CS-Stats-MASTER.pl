#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

##################################################################################### 
# This program generates statistics over TAC Cold Start data files.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.0";

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
### DO INCLUDE Stats                  ColdStartLib.pm
### DO INCLUDE Switches               ColdStartLib.pm

##################################################################################### 
##### XML Documents
##################################################################################### 

package Document;

# IMPORTANT NOTE: new returns a list of Documents, not a single document,
# because a given file might contain more than one <doc> specification
sub new {
  my ($class, $filename) = @_;
  my @result;
  my $self = {FILENAME => $filename};
  open(my $infile, "<:utf8", $filename) or die "Could not open $filename: $!";
  local ($/);
  my $filetext = <$infile>;
  close $infile;
  while ($filetext =~ /(<doc .*?<\/doc>)/gis) {
    my $doctext = $1;
    $doctext =~ s/\s/ /gs;
    $doctext =~ /<doc[^>]+id="(.*?)"[^>]*>/i or die "No docid in doc $doctext";
    my $docid = $1;
    my $self = {FILENAME => $filename,
		TEXT => $doctext,
		DOCID => $docid};
    bless($self, $class);
    push(@result, $self);  }
  return(@result);
}

sub get_text {
  my ($self) = @_;
  $self->{TEXT};
}

sub get_docid {
  my ($self) = @_;
  $self->{DOCID};
}

sub get_filename {
  my ($self) = @_;
  $self->{FILENAME};
}

sub docid2filename {
  my ($docid) = @_;
  # Kill any leading or trailing detritus
  $docid =~ s/\.xml$//i;
  $docid =~ s/^.*\///;
  $docid =~ /_(\d{2})\d+$/ or die "DOCID $docid does not end in digits";
  my $subdir = $1;
#  "$collection_dir/$subdir/$docid.xml";
  "collection_dir/$subdir/$docid.xml";
}

##################################################################################### 
##### Document Collection
##################################################################################### 

package Collection;

my $doc_pattern = qr/.xml$/;

sub findfiles {
  my ($dir_or_file) = @_;
  if (-d $dir_or_file) {
    # Don't recurse through dot directories unless they're the
    # original (relative) name given
    return if $dir_or_file =~ m@/\.@;
    return(map {&findfiles($_)} <$dir_or_file/*>);
  }
  else {
    return($dir_or_file) if $dir_or_file =~ /$doc_pattern/;
  }
}

sub new {
  my ($class, $dir) = @_;
  my $self;
  if (-d $dir) {
    $self = {DIRECTORY => $dir};
    die "No file or directory called $dir" unless -e $dir;
    $self->{FILENAMES} = [&findfiles($dir)];
  }
  else {
    $dir =~ /^(.*)\//;
    $self = {DIRECTORY => $1 || ".", FILENAMES => [$dir]};
  }
  bless($self, $class);
  $self;
}

# sub docid2doc {
#   my ($self, $docid) = @_;
#   unless ($self->{DOCID2FILENAME}) {
    

sub print_filenames {
  my ($self) = @_;
  foreach my $filename (@{$self->{FILENAMES}}) {
    print "$filename\n";
  }
}

sub get_filenames {
  my ($self) = @_;
  return @{$self->{FILENAMES}};
}

sub get_numfiles {
  my ($self) = @_;
  scalar @{$self->{FILENAMES}};
}

sub scan_files {
  my ($self) = @_;
  return if $self->{SCANNED};
  $self->{STATS}{LENGTH} = Statistic->new('DOCLEN', "document length", 100);
  $self->{STATS}{WORDS} = Statistic->new('WORDS', 'number of words', 100);
  $self->{STATS}{WSLENGTH} = Statistic->new('WSLENGTH', 'length with normalized white space', 100);
  $self->{STATS}{NUMDOCS} = 0;
  my @filenames = $self->get_filenames();
  foreach my $filename (@filenames) {
    my $dir;
    if ($filename =~ /^.*\/(.*)\//) {
      $dir = $1;
      $self->{STATS}{DIRS}{$dir} = Statistic->new("DIR:$dir", "Files in $dir", 100)
	unless $self->{STATS}{DIRS}{$dir};
      $self->{STATS}{DIRS}{$dir}->add(1);
    }
    my @documents = Document->new($filename);
    $self->{STATS}{NUMDOCS} += @documents;
    foreach my $document (@documents) {
      my $docid = $document->get_docid();
      $self->{DOCID2FILENAME}{$docid} = $filename;
      my $text = $document->get_text();
      $self->{STATS}{LENGTH}->add(length($text));
      my $numwords = 0;
      while ($text =~ /\w+/g) {
	$numwords++;
      }
      $self->{STATS}{WORDS}->add($numwords);
      $text =~ s/\s+/ /gs;
      $self->{STATS}{WSLENGTH}->add(length($text));
    }
  }
  $self->{SCANNED} = 'true';
}

sub print_statistics {
  my ($self) = @_;
  $self->scan_files();
  print "Collection: $self->{DIRECTORY}\n";
  print "\t", $self->get_numfiles(), "\tNumber of files\n";
  print "\t$self->{STATS}{NUMDOCS}\tNumber of documents\n";
  print "\n";
  foreach my $dir (sort keys %{$self->{STATS}{DIRS}}) {
    print "\t";
    $self->{STATS}{DIRS}{$dir}->printsum("Files in $dir");
  }
  print "\n";
  $self->{STATS}{LENGTH}->printstat('Length');
  $self->{STATS}{WSLENGTH}->printstat('Whitespace-normalized length');
  $self->{STATS}{WORDS}->printstat('Words');
  print "\n";
  $self->{STATS}{LENGTH}->get_histogram()->print();
  $self->{STATS}{WSLENGTH}->get_histogram()->print();
  $self->{STATS}{WORDS}->get_histogram()->print();
}

package main;

##################################################################################### 
##### Queries
##################################################################################### 

sub print_query_stats {
  my ($logger, $filename, $querylist) = @_;
  my $queries = QuerySet->new($logger, $filename);
  my %stats;
  $stats{ALL}{ALL} = Statistic->new("ALL_ALL", "All slots");
  $stats{ALL}{0}   = Statistic->new("ALL_0", "ALL Hop 0 slots");
  $stats{ALL}{1}   = Statistic->new("ALL_1", "ALL Hop 1 slots");
  $stats{PER}{ALL} = Statistic->new("PER_ALL", "Person slots");
  $stats{PER}{0}   = Statistic->new("PER_0", "Hop 0 Person slots");
  $stats{PER}{1}   = Statistic->new("PER_1", "Hop 1 Person slots");
  $stats{ORG}{ALL} = Statistic->new("ORG_ALL", "Organization slots");
  $stats{ORG}{0}   = Statistic->new("ORG_0", "Hop 0 Organization slots");
  $stats{ORG}{1}   = Statistic->new("ORG_1", "Hop 1 Organization slots");
  $stats{GPE}{ALL} = Statistic->new("GPE_ALL", "GPE slots");
  $stats{GPE}{0}   = Statistic->new("GPE_0", "Hop 0 GPE slots");
  $stats{GPE}{1}   = Statistic->new("GPE_1", "Hop 1 GPE slots");
  $stats{ENTRYPOINTS} = Statistic->new("ENTRYPOINTS", "Entry points");
  $stats{NUMSLOTS} = Statistic->new("SLOTS", "Total number of slots in the queries");
  $stats{NUMQUERIES} = Statistic->new('NUM_QUERIES', 'Total number of queries');
  foreach my $query (grep {$_->{FROM_FILE}} $queries->get_all_queries()) {
    if ($querylist) {
      next unless $querylist->{$queries->get_ancestor_id($query->get('QUERY_ID'))};
    }
    
    $stats{NUMQUERIES}->add(1);

    # ENTRYPOINTS
    $stats{ENTRYPOINTS}->add($query->get_num_entrypoints());

    # SLOT0
    my $slot0 = $query->get('SLOT0');
    $slot0 =~ /^(.*?):(.*)$/ or die "Bad slot: $slot0";
    my $type = uc $1;
    $stats{ALL}{0}->add(1);
    $stats{$type}{0}->add(1);
    $stats{ALL}{ALL}->add(1);
    $stats{NUMSLOTS}->add(1);
    $stats{$type}{ALL}->add(1);
    unless (defined $stats{SLOTS}{$slot0}) {
      $stats{SLOTS}{$slot0}{ALL} = Statistic->new("${slot0}_ALL", "$slot0 slot");
      $stats{SLOTS}{$slot0}{0} = Statistic->new("${slot0}_0", "Hop 0 $slot0 slot");
      $stats{SLOTS}{$slot0}{1} = Statistic->new("${slot0}_1", "Hop 1 $slot0 slot");
    }
    $stats{SLOTS}{$slot0}{ALL}->add(1);
    $stats{SLOTS}{$slot0}{0}->add(1);

    # SLOT1
    if ($query->get('SLOT1')) {
      my $slot1 = $query->get('SLOT1');
      $slot1 =~ /^(.*?):(.*)$/ or die "Bad slot: $slot1";
      $type = uc $1;
      $stats{$type}{1}->add(1);
      $stats{$type}{ALL}->add(1);
      $stats{ALL}{1}->add(1);
      $stats{ALL}{ALL}->add(1);
      $stats{NUMSLOTS}->add(1);
      unless (defined $stats{SLOTS}{$slot1}) {
	$stats{SLOTS}{$slot1}{ALL} = Statistic->new("${slot1}_ALL", "$slot1 slot");
	$stats{SLOTS}{$slot1}{0} = Statistic->new("${slot1}_0", "Hop 0 $slot1 slot");
	$stats{SLOTS}{$slot1}{1} = Statistic->new("${slot1}_1", "Hop 1 $slot1 slot");
      }
      $stats{SLOTS}{$slot1}{ALL}->add(1);
      $stats{SLOTS}{$slot1}{1}->add(1);
    }
  }
  print "Query Statistics";
  foreach my $filename ($queries->get_filenames()) {
    $filename =~ s/.*\///;
    print "\t$filename\n";
  }
  print "\n\n";
  $stats{NUMQUERIES}->printsum("Queries", 'rev');
  $stats{NUMSLOTS}->printsum("Slots", "rev");
  $stats{ENTRYPOINTS}->printsum('Entry points', 'rev');
  print "\n";
  $stats{ENTRYPOINTS}->printstat('Entry points per query');
  print "\n";
  print "Slot\tHop 0\tHop 1\tALL\n";
  foreach my $type (qw(ALL PER ORG GPE)) {
    print $type;
    foreach my $hop ('0', '1', 'ALL') {
      print "\t", $stats{$type}{$hop}->get_count();
    }
    print "\n";
  }
  foreach my $slot (sort keys %{$stats{SLOTS}}) {
    print $slot;
    foreach my $hop ('0', '1', 'ALL') {
      print "\t", $stats{SLOTS}{$slot}{$hop}->get_count();
    }
    print "\n";
  }
}

##################################################################################### 
##### Runs
##################################################################################### 

sub collect_run_stats {
  my ($logger, $queries, $querylist, $run) = @_;
  my %dedup;
  my %stats = (RUNID => $run->{RUNID});
  my $prev_confidence;

  # Create the appropriate statistics
  foreach my $statname (qw(ALL PER ORG GPE NUMQUERIES NUMENTRIES)) {
    foreach my $level (qw(ALL 0 1)) {
      $stats{$statname}{$level} = Statistic->new("${statname}_$level",
						 ($level eq 'ALL' ? "Total number of " : "Number of Hop $level ") .
						 ($statname eq 'NUMQUERIES' ? "queries" :
						  $statname eq 'NUMENTRIES' ? "fills submitted" :
						  $statname eq 'ALL' ? "slots" :
						 "$statname slots"));
    }
  }

  foreach my $entry ($run->get_all_entries()) {
    my $type = uc $entry->{SLOT_TYPE};
    my $level = $entry->{QUERY}{LEVEL};
    if ($querylist) {
      next unless $querylist->{$queries->get_ancestor_id($entry->{QUERY}->get('QUERY_ID'))};
    }

    # Confidence values
    $prev_confidence = $entry->{CONFIDENCE} unless defined $prev_confidence;
    $stats{HAS_MULTIPLE_CONFIDENCES} = 'true' if $entry->{CONFIDENCE} != $prev_confidence;

    # Increment the appropriate counts
    foreach my $statname ('ALL', $type, 'NUMQUERIES', 'NUMENTRIES') {
      my $skip_all = $statname eq 'NUMQUERIES' && $dedup{ALL}{$entry->{QUERY_ID}}++;
      my $skip_level = $statname eq 'NUMQUERIES' && $dedup{$level}{$entry->{QUERY_ID}}++;
      $stats{$statname}{ALL}->add(1) unless $skip_all;
      $stats{$statname}{$level}->add(1) unless $skip_level;
    }
  }
  
  \%stats;
}

sub print_run_stats {
  my ($run, $stats) = @_;
  print "Slot Fill Statistics for:\t$run->{RUNID}\n";
  print $stats->{HAS_MULTIPLE_CONFIDENCES} ? "    Multiple confidence values used\n" : "\n";
  print "\n";
  $stats->{NUMQUERIES}{ALL}->printsum('Num queries');
  $stats->{NUMQUERIES}{0}->printsum('Num Hop 0 queries');
  $stats->{NUMQUERIES}{1}->printsum('Num Hop 1 queries');
  $stats->{NUMENTRIES}{ALL}->printsum('Num submitted entries');
  $stats->{NUMENTRIES}{0}->printsum('Num Hop 0 submitted entries');
  $stats->{NUMENTRIES}{1}->printsum('Num Hop 1 submitted entries');
  print "\n";
  print "\tALL\tHop 0\tHop 1\n";
  foreach my $type (qw(ALL PER ORG GPE)) {
    print $type;
    foreach my $hop ('ALL', '0', '1') {
      print "\t", $stats->{$type}{$hop}->get_count();
    }
    print "\n";
  }
}

sub print_all_run_stats {
  my ($logger, $queries, $querylist, $runfiles) = @_;
  #die "Run stats doesn't supporty -querylist" if $querylist;
  my @stats = sort {$a->{RUNID} cmp $b->{RUNID}}
    map {&collect_run_stats($logger, $queries, $querylist, EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, $_))}
    grep {!-z}
    @{$runfiles};
  print "\t\t";
  foreach (@stats) {
    print "\t$_->{RUNID}";
  }
  print "\n";
  my $firststat = $stats[0];
  foreach my $statname (qw(ALL PER ORG GPE NUMQUERIES NUMENTRIES)) {
    foreach my $level (qw(ALL 0 1)) {
      print "$statname\t$level\t$firststat->{$statname}{$level}{DESCRIPTION}";
      foreach my $stat (@stats) {
	print "\t$stat->{$statname}{$level}{SUM}";
      }
      print "\n";
    }
  }
}

##################################################################################### 
##### Main Program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Produce a variety of TAC Cold Start statistics", "");
print$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch("queries", "File containing evaluation queries");
$switches->addVarSwitch("querylist", "File containing list of query IDs; only the specified queries will be statisticated");
$switches->addVarSwitch("documents", "Directory or file containing document collection");
$switches->addVarSwitch("kb", "File containing knowledge base");
$switches->addParam("runfiles", undef, "allothers", "Submitted valid run files");

$switches->process(@ARGV);

my $logger = Logger->new();

my $querylist_file = $switches->get("querylist");
my $querylist;
if ($querylist_file) {
  open(my $infile, "<:utf8", $querylist_file) or die "Could not open $querylist_file: $!";
  my @query_ids = <$infile>;
  close $infile;
  chomp @query_ids;
  $querylist = {map {$_ => 'true'} @query_ids};
}

# Put runs ahead of queries (since they need queries to be properly interpreted)
if ($switches->get("runfiles")) {
  my $queryfile = $switches->get("queries");
  die "Must specify -queries when using -run switch" unless $queryfile;
  my $queries = QuerySet->new($logger, $queryfile);
  my $runfiles = $switches->get("runfiles");
  &print_all_run_stats($logger, $queries, $querylist, $runfiles);
}
elsif ($switches->get("queries")) {
  &print_query_stats($logger, $switches->get("queries"), $querylist);
}
elsif ($switches->get("documents")) {
  my $collection = Collection->new($switches->get("documents"));
  $collection->print_statistics();
}
elsif ($switches->get("kb")) {
  print STDERR << "END_KB";
To get KB stats, run CS-ValidateKB with the -stats_file flag on each knowledge base.
You can then combine the results using the merge-kb-stats.pl script.
END_KB
}
else {
  $switches->showUsage();
}

1;
