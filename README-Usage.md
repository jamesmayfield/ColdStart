Last modified: 19th April 2017

# 1 Introduction

This document describes:

1. the usage of various scripts, and
2. how to use these scripts for selected scenarios

# 2 Scripts

The content in this README is focused at the participants of various TAC tracks therefore only related scripts are covered below:

1. CS-GenerateQueries-MASTER.pl (v2017.1.0)
2. CS-ResolveQueries-MASTER.pl (v2017.1.0)
3. CS-ValidateKB-MASTER.pl (v2017.1.0)
4. CS-ValidateSF-MASTER.pl (v2017.1.0)

## 2.1 Scripts usage

The usage of above mentioned scripts can be seen by running with option -h or without any argument. For record, the usage of these scripts is given below:

### 2.1.1 Usage of CS-GenerateQueries-MASTER.pl
~~~
CS-GenerateQueries-MASTER.pl:  Generate a query file for a Cold Start Slot
                               Filling variant submission. With two arguments,
                               it updates the input queries with the <slot>
                               field. With three arguments it generates a second
                               round query file based on the first round slot
                               filling output.

Usage: CS-GenerateQueries-MASTER.pl {-switch {-switch ...}} queryfile outputfile {runfile}

Legal switches are:
  -docs <value>            Tab-separated file containing docids and document
                             lengths, measured in unnormalized Unicode
                             characters
  -error_file <value>      Specify a file to which error output should be
                             redirected (Default = STDERR).
  -help                    Show help
  -justifications <value>  Are multiple justifications allowed? Legal values are
                             of the form A:B where A represents justifications
                             per document and B represents total justifications.
                             Use 'M' to allow any number of justifications, for
                             e.g., 'M:10' to allow multiple justifications per
                             document but overall not more than 10 (best or top)
                             justifications. (Default = M:M).
  -valid                   Ensure valid XML output by escaping angle brackets
                             and ampersands
  -version                 Print version number and exit
parameters are:
  queryfile   File containing queries used to generate the file being validated
                (Required).
  outputfile  File into which new queries are to be placed. (Required).
  runfile     File containing query output. Omit to generate initial queries.
~~~

### 2.1.2 Usage of CS-ResolveQueries-MASTER.pl
~~~
CS-ResolveQueries-MASTER.pl:  Apply a set of evaluation queries to a knowledge
                              base to produce Cold Start output for assessment.

Usage: CS-ResolveQueries-MASTER.pl {-switch {-switch ...}} queryfile runfile output_file

Legal switches are:
  -error_file <value>  Specify a file to which error output should be redirected
                         (Default = STDERR).
  -help                Show help
  -version             Print version number and exit
parameters are:
  queryfile    XML file containing queries to be resolved (Required).
  runfile      Files containing input KBs (Required).
  output_file  File into which to place slot fills (Required).
~~~

### 2.1.3 Usage of CS-ValidateKB-MASTER.pl
~~~
CS-ValidateKB-MASTER.pl:  Validate a TAC Cold Start KB file, checking for common
                          errors, and optionally exporting to a variety of
                          formats.

Usage: CS-ValidateKB-MASTER.pl {-switch {-switch ...}} filename

Legal switches are:
  -docs <value>        Tab-separated file containing docids and document
                         lengths, measured in unnormalized Unicode characters
  -error_file <value>  Specify a file to which error output should be redirected
                         (Default = STDERR).
  -help                Show help
  -ignore <value>      Colon-separated list of warnings to ignore. Legal values
                         are: BAD_QUERY, COLON_OMITTED, DISCARDED_ENTRY,
                         DUPLICATE_ASSERTION, DUPLICATE_LINE, DUPLICATE_QUERY,
                         DUPLICATE_QUERY_FIELD, DUPLICATE_QUERY_ID, EMPTY_FIELD,
                         EMPTY_FILE, FAILED_LANG_INFERENCE,
                         ILLEGAL_LINK_SPECIFICATION, IMPROPER_CONFIDENCE_VALUE,
                         MISMATCHED_HOP_SUBTYPES, MISMATCHED_HOP_TYPES,
                         MISMATCHED_RUNID, MISMATCHED_TAGS, MISSING_CANONICAL,
                         MISSING_DECIMAL_POINT, MISSING_INVERSE,
                         MISSING_MENTION, MULTIPLE_CORRECT_GROUND_TRUTH,
                         MULTIPLE_FILLS_ENTITY, MULTIPLE_FILLS_SLOT,
                         MULTIPLE_LINKS, MULTIPLE_RUNIDS, NO_MENTIONS,
                         NO_QUERIES_LOADED, OFF_TASK_SLOT,
                         POSSIBLE_DUPLICATE_QUERY, PREDICATE_ALIAS,
                         SEMICOLON_AS_SEPARATOR, TOO_MANY_CHARS,
                         TOO_MANY_PROVENANCE_TRIPLES, UNASSERTED_MENTION,
                         UNEXPECTED_JUSTIFICATIONS, UNKNOWN_QUERY_FIELD,
                         UNKNOWN_QUERY_ID_WARNING, UNLOADED_QUERY,
                         UNQUOTED_STRING, WRONG_SLOT_NAME
  -labels <value>      Colon-separated list of triple labels for output. Useful
                         in conjunction with -predicates switch. (Default =
                         TAC).
  -linkkb <value>      Specify which links should be used to produce KB IDs for
                         the "-output edl" option. Legal values depend upon the
                         prefixes found in the argument to 'link' relations in
                         the KB being validated. This option has no effect
                         unless "-output edl" has been specified. (Default =
                         LDC2015E42).
  -multiple <value>    Are multiple assertions of the same triple allowed? Legal
                         values are: MANY (any number of duplicate assertions
                         allowed), ONE (only one allowed - no duplicates),
                         ONEPERDOC (at most one allowed per document) (Default =
                         MANY).
  -output <value>      Colon-separated list of output formats. Legal formats are
                         [eag, edl, eng, sen, tac, none]. Use 'none' to perform
                         error checking with no output. (Default = none).
  -output_dir <value>  Specify a directory to which output files should be
                         written. Default would be the directory containing the
                         KB to be validated.
  -predicates <value>  File containing specification of additional predicates to
                         allow
  -stats_file <value>  Specify a file into which statistics about the KB being
                         validated will be placed
  -task <value>        Specify task to validate. Legal values are: CSED (Cold
                         Start Entity Discovery variant), CSEDL (Cold Start
                         Entity Discovery and Linking variant), CSKB (Cold Start
                         Knowledge Base variant). (Default = CSKB).
  -version             Print version number and exit
parameters are:
  filename  File containing input KB specification. (Required).
~~~

### 2.1.4 Usage of CS-ValidateSF-MASTER.pl
~~~
CS-ValidateSF-MASTER.pl:  Validate a TAC Cold Start Slot Filling variant output
                          file, checking for common errors.

Usage: CS-ValidateSF-MASTER.pl {-switch {-switch ...}} queryfile filename

Legal switches are:
  -allow_comments          Enable comments introduced by a pound sign in the
                             middle of an input line
  -docs <value>            Tab-separated file containing docids and document
                             lengths, measured in unnormalized Unicode
                             characters
  -error_file <value>      Specify a file to which error output should be
                             redirected (Default = STDERR).
  -groundtruth             Treat input file as ground truth (so don't, e.g.,
                             enforce single-valued slots)
  -help                    Show help
  -justifications <value>  Are multiple justifications allowed? Legal values are
                             of the form A:B where A represents justifications
                             per document and B represents total justifications.
                             Use 'M' to allow any number of justifications, for
                             e.g., 'M:10' to allow multiple justifications per
                             document but overall not more than 10 (best or top)
                             justifications. (Default = 1:3).
  -output_file <value>     Specify an output file with warnings repaired. Omit
                             for validation only (Default = none).
  -version                 Print version number and exit
parameters are:
  queryfile  File containing queries used to generate the file being validated
               (Required).
  filename   File containing query output. (Required).
~~~

# 3 Overview of various scenarios

Starting in 2017, the ColdStart KB will allow assertions involving events, and sentiments, in addition to the those involving standard slot-filling slots from the previous year. The participants will also be encouraged to specify external links to the nodes.

The ColdStart KB will undergo evaluations at multiple levels: 

(1) Query-based evaluation of the entire KB, and
(2) Evaluation of components extracted from the KB

This README describes steps required to generate the validated files necessary for the evaluations. 

## 3.1 Generating valid input file for query-based evaluation of the entire KB

This section describes how to produce a validated KB in order to support query-based KB evaluation. In order to validate a KB named `CSrun.tac`, you may run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output tac CSrun.tac
~~~

Notice that running this command with `-output tac` makes the validator produce nothing but a validated KB. The output will be written in the file named `CSrun.tac.valid` and will be stored at the location as that of the `CSrun.tac`. The location of the output can be changed by using `-output_dir /path/to/output`.

## 3.2 Generating valid input file for evaluating Slot Filling component

This section describes how to produce a valid input for component-based slot-filling evaluation. In order to produce this file, you may run the following command:

~~~
perl CS-ResolveQueries.pl -error_file CSrun.errlog tac_kbp_2017_cold_start_slot_filling_evaluation_queries.xml CSrun.tac.valid CSrun.SF
~~~

The output will be written in the file named `CSrun.SF`. Also, note that we are using the validated KB `CSrun.tac.valid` as one of the input files instead of the original KB `CSrun.tac`.

Once you have generated the validated KB `CSrun.tac.valid`, you would run the following command in order to generate the validated SF file necessary for component-based slot-filling evaluation:

~~~
perl CS-ValidateSF-MASTER.pl -error_file CSrun.SF.errlog -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -output_file CSrun.valid.ldc.tab.txt tac_kbp_2017_cold_start_slot_filling_evaluation_queries.xml CSrun.SF
~~~

The output of this step `CSrun.valid.ldc.tab.txt` will be used for component-based slot-filling evaluation.

## 3.3 Generating valid input file for evaluating Entity Discovery and Linking component

This section describes how to produce a valid input for component-based entity discovery and linking evaluation. In order to produce this file, you may run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output edl CSrun.tac
~~~

Notice that running this command with `-output edl` makes the validator produce nothing but a valid input for component-based entity discovery and linking evaluation. The output will be written in the file named `CSrun.edl.valid` and will be stored at the location as that of the `CSrun.tac`. The location of the output can be changed by using `-output_dir /path/to/output`.

## 3.4 Generating Valid input file for evaluating Event Arguments component

This section describes how to produce a valid input for component-based event arguments evaluation. In order to produce this file, you may run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output eag CSrun.tac
~~~

Notice that running this command with `-output eag` makes the validator produce nothing but a valid input for component-based event arguments evaluation. The output will be written in the directory named `event_arguments` and will be stored at the location as that of the `CSrun.tac`. The location of the output can be changed by using `-output_dir /path/to/output`.

## 3.5 Generating Valid input file for evaluating Event Nuggets component

This section describes how to produce a valid input for component-based event nuggets evaluation. In order to produce this file, you may run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output eng CSrun.tac
~~~

Notice that running this command with `-output eng` makes the validator produce nothing but a valid input for component-based event nuggets evaluation. The output will be written in the file named `CSrun.eng.valid` and will be stored at the location as that of the `CSrun.tac`. The location of the output can be changed by using `-output_dir /path/to/output`.

## 3.5 Generating Valid input file for evaluating BeST component

This section describes how to produce a valid input for component-based BeSt evaluation. In order to produce this file, you may run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output sen CSrun.tac
~~~

Notice that running this command with `-output sen` makes the validator produce nothing but a valid input for component-based BeSt evaluation. The output will be written in the directory named `sentiments` and will be stored at the location as that of the `CSrun.tac`. The location of the output can be changed by using `-output_dir /path/to/output`.

## 3.6 Generating Valid input file for evaluating multiple components at the same time

The value of the `-output` switch does not need to be a singular value, rather it can be a list of values separated by a colon (:). Therefore, given `CSrun.tac`, if you need to generate input files for any of the components, you would need to use the corresponding value as an element in the list for the value of `-output`. For example, given `CSrun.tac`, if you want to produce the input files for all of the above evaluations except that of slot-filling you would run the following command:

~~~
perl CS-ValidateKB-MASTER.pl -docs tac_kbp_2017_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output tac:edl:sen:eag:eng CSrun.tac
~~~
