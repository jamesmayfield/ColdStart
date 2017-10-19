#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program validates Cold Start 2016 assessments.
# It takes as input the evaluation queries, the cross-lingual assessment file, and
# optinally a colon-separated lanugage identifiers.
# It will optionally produce the assessment files corresponding to given languages.
#
# Author: Shahzad Rajput
# Please send questions or comments to shahzad "dot" rajput "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "2017.1.0";

# Filehandles for program and error output
my %program_output;
my $error_output = *STDERR{IO};


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

### DO NOT INCLUDE
# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

### DO INCLUDE
##################################################################################### 
# Runtime switches and main program
##################################################################################### 

my %language_options = (
  ENG => {
  	NAME => 'ENGLISH',
    DESCRIPTION => "English only",
    INPROVENANCE => 'yes',
  },
  SPA=> {
  	NAME => 'SPANISH',
    DESCRIPTION => "Spanish only",
    INPROVENANCE => 'yes',
  },
  CMN => {
  	NAME => 'CHINESE',
    DESCRIPTION => "Chinese only",
    INPROVENANCE => 'yes',
  },
  XLING => {
  	NAME => 'MULTI-LINGUAL',
    DESCRIPTION => "Any language.",
  },
);

sub get_language {
  my ($assessment) = @_;
  my @language_identifiers = grep {exists $language_options{$_}{INPROVENANCE}} keys %language_options;
  my $query_language = $assessment->{QUERY}{LANGUAGES}[0];
  my $provenance_triples = "$assessment->{RELATION_PROVENANCE_TRIPLES},$assessment->{VALUE_PROVENANCE_TRIPLES}";
  my @matching_languages = keys {map {$language_options{$_}{NAME}=>1} grep {$provenance_triples=~/$_\_/} @language_identifiers};
  my $language = "MULTI-LINGUAL";
  if(scalar @matching_languages == 1 && $matching_languages[0] eq $query_language) {
  	$language = $query_language;
  }
  ($language) = grep {$language_options{$_}{NAME} eq $language} keys %language_options;
  $language;
}

sub get_corrected_assessment_line {
  my ($assessment, $language, %mention_type) = @_;
  my $retVal = $assessment->{LINE};
  if($assessment->{VALUE_EC} ne "0") {
  	my $original = $assessment->{EC_MENTION_TYPE};
  	if(exists $mention_type{$assessment->{VALUE_EC}} && exists $mention_type{$assessment->{VALUE_EC}}{$language}) {
  	  $assessment->{EC_MENTION_TYPE} = $mention_type{$assessment->{VALUE_EC}}{$language};
  	}
  	else {
  	  $assessment->{EC_MENTION_TYPE} = "NOM";
  	}
  	my @columns = @{$assessment->{SCHEMA}{COLUMNS}};
  	$retVal = join("\t", map{$assessment->{SCHEMA}{INVERSE_ASSESSMENT_CODES}{$assessment->{$_}} || $assessment->{$_}} @columns);
  	$assessment->{EC_MENTION_TYPE} = $original;
  }
  $retVal;
}

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Validate a TAC Cold Start cross-lingual assessment file, checking for common errors " .
                    "and optionally produce language specific assessment file(s).",
                    "-language is a colon-separated list drawn from the following:\n" . &main::build_documentation(\%language_options) .
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify output file prefix.");
$switches->put('output_file', 'none');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch("languages", "required", "Colon-separated lanugage identifiers.");
$switches->put('languages', "ENG:SPA:CMN:XLING");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addConstantSwitch('groundtruth', 'true', "Treat input file as ground truth (so don't, e.g., enforce single-valued slots)");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated");
$switches->addParam("filename", "required", "File containing assessments.");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");

my $logger = Logger->new();
# It is not an error for ground truth to have multiple fills for a single-valued slot
$logger->delete_error('MULTIPLE_FILLS_SLOT') if $switches->get('groundtruth');

# Allow redirection of stdout and stderr
my $output_filename_prefix = $switches->get("output_file");

foreach my $output_postfix(keys %language_options) {
  if (lc $output_filename_prefix eq 'stdout') {
    $program_output{$output_postfix} = *STDOUT{IO};
  }
  elsif (lc $output_filename_prefix eq 'stderr') {
    $program_output{$output_postfix} = *STDERR{IO};
  }
  else {
    open($program_output{$output_postfix}, ">:utf8", $output_filename_prefix . "." . lc($output_postfix)) or $logger->NIST_die("Could not open $output_filename_prefix . "." . lc($output_postfix): $!");
  }
}

my $error_filename = $switches->get("error_file");
$logger->set_error_output($error_filename);
$error_output = $logger->get_error_output();

# Validate selected policy options
foreach my $language_selected(split(":", $switches->get("languages"))) {
  $logger->NIST_die("Unexpected language $language_selected for -languages")
  	  if(not exists $language_options{$language_selected});
}

# Load mapping from docid to document length
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

# The input file to process
my $filename = $switches->get("filename");
$logger->NIST_die("File $filename does not exist") unless -e $filename;

my $queries = QuerySet->new($logger, $queryfile);

# FIXME: parameterize discipline
my $assessments = EvaluationQueryOutput->new($logger, 'ASSESSED', $queries, {JUSTIFICATIONS_ALLOWED=>"M:M"}, $filename);

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
else{
  # set up %parent_language_ids
  my %parent_language;
  my %mention_type;
  foreach my $assessment(@{$assessments->{ALL_ENTRIES}}) {
    my $language = &get_language($assessment);

    $parent_language{$assessment->{TARGET_QUERY_ID}}{$language} = 1
      if($assessment->{LEVEL} == 0 );

    my $value_mention_type = $assessment->{VALUE_MENTION_TYPE};
    my $ec_mention_type = $assessment->{EC_MENTION_TYPE};

    if ( ($value_mention_type eq "NAM" && $ec_mention_type eq "NAM")
        || ($value_mention_type eq "NOM" && $ec_mention_type eq "NOM") ) {
          $mention_type{$assessment->{VALUE_EC}}{$language} = $ec_mention_type
            if(not exists $mention_type{$assessment->{VALUE_EC}}{$language});
          $logger->NIST_die("Unexpected mention type.")
            if(exists $mention_type{$assessment->{VALUE_EC}}{$language}
              && $mention_type{$assessment->{VALUE_EC}}{$language} ne $ec_mention_type);
    }
    elsif ($value_mention_type eq "NOM" && $ec_mention_type ne "NAM" && $ec_mention_type ne "NOM" ) {
      # This happens when the EC_MENTION_TYPE is a (docid, value) pair, i.e., the case when there is a
      # named mention in the collection but no run retrieved it.
      #
      # This case should be handled as follows: If the document mentioned in EC_MENTION_TYPE is in 
      # language `A` and (1) if `A` matches `$language` then mention_type for `A` and `XLING` is NAM,
      # but (2) if `A` does not match `$language` then mention_type for `XLING` is NAM.
      
      my ($ec_mention_type_language) = $ec_mention_type =~ /(ENG|CMN|SPA)_/;
      $logger->NIST_die("Unexpected value: ==>$ec_mention_type<==\nin line: $assessment->{LINE}\n")
        unless $ec_mention_type_language;
      $mention_type{$assessment->{VALUE_EC}}{$language} = $ec_mention_type
        if($ec_mention_type_language eq $language);
    }
    $mention_type{$assessment->{VALUE_EC}}{'XLING'} = $ec_mention_type;
  }
  # filter all the assessments into language-specific assessments
  foreach my $assessment(@{$assessments->{ALL_ENTRIES}}) {
  	my $language = &get_language($assessment);
    if($assessment->{LEVEL} == 0 || exists $parent_language{ $assessment->{QUERY_ID} }{ $language }) {
      print {$program_output{$language}} &get_corrected_assessment_line($assessment, $language, %mention_type), "\n";
      print {$program_output{"XLING"}} &get_corrected_assessment_line($assessment, "XLING", %mention_type), "\n" 
        if $language ne "XLING";
    }
    else {
      print {$program_output{"XLING"}} &get_corrected_assessment_line($assessment, "XLING", %mention_type), "\n";
  	}
  }
}
print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";

# Close program output
foreach my $output_postfix(keys %language_options) {
  close $program_output{$output_postfix};
}

# Close error output
$logger->close_error_output();

exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Applying correction of EC_MENTION_TYPE within monolingual QREL split when the NAMed mention was found 
#       in another language but not in the language of the split.
# 1.2 - Removed a bug where filtering based on language identifiers were missing "_".
# 2017.1.0 - First release of 2017

1;
