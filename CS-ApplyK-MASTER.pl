#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# Apply justifications constraint to the slot-filling output file.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2017.1.0";

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


my $switches = SwitchProcessor->new($0, "Apply justifications constraint to the slot-filling output file prior to validation.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('justifications', "Are multiple justifications allowed? " .
			"Legal values are of the form A:B where A represents justifications per document and B represents total justifications. " .
			"Use \'M\' to allow any number of justifications, for e.g., \'M:10\' to allow multiple justifications per document ".
			"but overall not more than 10 (best or top) justifications.");
$switches->put('justifications', "1:3");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("runfile", "required", "File containing query output.");
$switches->addParam("outputfile", "required", "File into which new output is to be placed.");

$switches->process(@ARGV);

my $runfile = $switches->get("runfile");
my $output_filename = $switches->get("outputfile");
my $justifications = $switches->get("justifications");
my $logger = Logger->new();

my %entries;

my @labels = qw(QUERYID SLOT RUNID RELATION_PROV VALUE TYPE VALUE_PROV CONFIDENCE NODEID);

# Load the file
open(my $infile, "<:utf8", $runfile) or $logger->NIST_die("Could not open $runfile: $!");
my $linenum = 0;
while(my $line = <$infile>) {
  chomp $line;
  $linenum++;
  my @elements = split(/\t/, $line);  
  my $entry = {map {$labels[$_]=>$elements[$_]} (0..$#labels)};
  my $target_uuid = &main::generate_uuid_from_values($entry->{QUERYID}, $entry->{VALUE}, $entry->{VALUE_PROV}, 12);
  my ($docid) = split(":", $entry->{RELATION_PROV});
  $entry->{DOCUMENTID} = $docid;
  $entry->{LEVEL} = scalar split("_", $entry->{QUERYID}) - 2;
  $entry->{TARGET_QUERYID} = $entry->{QUERYID}."_".$target_uuid;
  $entry->{LINENUM} = $linenum;
  $entry->{LINE} = $line;
  push(@{$entries{CATEGORIZED}{$entry->{LEVEL}}{$entry->{QUERYID}}{$entry->{NODEID}}{$entry->{CONFIDENCE}}{$entry->{LINENUM}}}, $entry);  				       
  push(@{$entries{ALL}}, $entry);  				       
}
close($infile);

# Apply the constraint
my ($k) = $justifications =~ /^.*?:(.*?)$/;
my $i=0;
foreach my $level(keys %{$entries{CATEGORIZED}}) {
  my %good_dependents;
  foreach my $queryid(keys %{$entries{CATEGORIZED}{$level}}) {
    foreach my $nodeid(keys %{$entries{CATEGORIZED}{$level}{$queryid}}) {
      my %docids_selected;
      foreach my $conf(sort {$b<=>$a} keys %{$entries{CATEGORIZED}{$level}{$queryid}{$nodeid}}) {
      	foreach my $linenum(sort {$a<=>$b} keys %{$entries{CATEGORIZED}{$level}{$queryid}{$nodeid}{$conf}}) { 
		  my @entries = @{$entries{CATEGORIZED}{$level}{$queryid}{$nodeid}{$conf}{$linenum}};
		  foreach my $entry(grep {!$_->{DISCARD}} @entries) {
		  	if(scalar keys %docids_selected == $k) {
		  	  $entry->{DISCARD} = 1;
		  	  next;
		  	}
		  	if(exists $docids_selected{$entry->{DOCUMENTID}}) {
		  	  $entry->{DISCARD} = 1;
		  	  next;
		  	}
		  	$good_dependents{$entry->{TARGET_QUERYID}} = 1;
		  	$docids_selected{$entry->{DOCUMENTID}} = 1;
		  	$i++;
		  	if($i % 10000 == 0) {
		  		print STDERR ".";
		  	}
		  }
      	}
      }
    }
  }
  # Discard dependents
  foreach my $entry(grep {$_->{LEVEL} == $level + 1} @{$entries{ALL}}) {
    unless(exists $good_dependents{$entry->{QUERYID}}) {
      $entry->{DISCARD} = 1;
    }
  }
}

open(my $program_output, ">:utf8", $output_filename) or $logger->NIST_die("Could not open $output_filename: $!");

foreach my $entry(sort {$a->{LINENUM}<=>$b->{LINENUM}} @{$entries{ALL}}) {
  if(exists $entry->{DISCARD} && $entry->{DISCARD} == 1) {
  	print STDERR "--discarding: $entry->{LINE}\n";
  }
  else {
  	print $program_output "$entry->{LINE}\n";
  }
}

close($program_output);

1;

################################################################################
# Revision History
################################################################################

# 2017.1.0 - Initial version 
