# 1 Introduction

September 22, 2016

This document describes:

1. How to generate the official scores for a KB/SF submission for 2016; and
2. How to interpret scores output.

# 2 Scripts

You are provided the following scripts:

1. CS-GenerateQueries-MASTER.pl (v2.0)
2. CS-ResolveQueries-MASTER.pl (v2016.1.0)
3. CS-ValidateKB-MASTER.pl (v5.3)
4. CS-ValidateSF-MASTER.pl (v2.0)
6. CS-Score-MASTER.pl (v3.0)

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
  -docs <value>        Tab-separated file containing docids and document
                         lengths, measured in unnormalized Unicode characters
  -error_file <value>  Specify a file to which error output should be redirected
                         (Default = STDERR).
  -help                Show help
  -valid               Ensure valid XML output by escaping angle brackets and
                         ampersands
  -version             Print version number and exit
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
  -docs <value>         Tab-separated file containing docids and document
                          lengths, measured in unnormalized Unicode characters
  -error_file <value>   Specify a file to which error output should be
                          redirected (Default = STDERR).
  -help                 Show help
  -ignore <value>       Colon-separated list of warnings to ignore. Legal values
                          are: BAD_QUERY, COLON_OMITTED, DUPLICATE_ASSERTION,
                          DUPLICATE_QUERY, DUPLICATE_QUERY_FIELD,
                          DUPLICATE_QUERY_ID, EMPTY_FIELD, EMPTY_FILE,
                          FAILED_LANG_INFERENCE, ILLEGAL_LINK_SPECIFICATION,
                          IMPROPER_CONFIDENCE_VALUE, MISMATCHED_HOP_SUBTYPES,
                          MISMATCHED_HOP_TYPES, MISMATCHED_RUNID,
                          MISMATCHED_TAGS, MISSING_CANONICAL,
                          MISSING_DECIMAL_POINT, MISSING_INVERSE,
                          MISSING_MENTION, MULTIPLE_CORRECT_GROUND_TRUTH,
                          MULTIPLE_FILLS_ENTITY, MULTIPLE_FILLS_SLOT,
                          MULTIPLE_LINKS, MULTIPLE_RUNIDS, NO_MENTIONS,
                          NO_QUERIES_LOADED, OFF_TASK_SLOT,
                          POSSIBLE_DUPLICATE_QUERY, PREDICATE_ALIAS,
                          TOO_MANY_CHARS, TOO_MANY_PROVENANCE_TRIPLES,
                          UNASSERTED_MENTION, UNKNOWN_QUERY_FIELD,
                          UNKNOWN_QUERY_ID_WARNING, UNLOADED_QUERY,
                          UNQUOTED_STRING, WRONG_SLOT_NAME
  -labels <value>       Colon-separated list of triple labels for output. Useful
                          in conjunction with -predicates switch. (Default =
                          TAC).
  -linkkb <value>       Specify which links should be used to produce KB IDs for
                          the "-output edl" option. Legal values depend upon the
                          prefixes found in the argument to 'link' relations in
                          the KB being validated. This option has no effect
                          unless "-output edl" has been specified. (Default =
                          none).
  -multiple <value>     Are multiple assertions of the same triple allowed?
                          Legal values are: MANY (any number of duplicate
                          assertions allowed), ONE (only one allowed - no
                          duplicates), ONEPERDOC (at most one allowed per
                          document) (Default = ONE).
  -output <value>       Specify the output format. Legal formats are [edl, tac,
                          none]. Use 'none' to perform error checking with no
                          output. (Default = none).
  -output_file <value>  Specify a file to which output should be redirected
                          (Default = STDOUT).
  -predicates <value>   File containing specification of additional predicates
                          to allow
  -stats_file <value>   Specify a file into which statistics about the KB being
                          validated will be placed
  -task <value>         Specify task to validate. Legal values are: CSED (Cold
                          Start Entity Discovery variant), CSEDL (Cold Start
                          Entity Discovery and Linking variant), CSKB (Cold
                          Start Knowledge Base variant). (Default = CSKB).
  -version              Print version number and exit
parameters are:
  filename  File containing input KB specification. (Required).
~~~

### 2.1.4 Usage of CS-ValidateSF-MASTER.pl
~~~
CS-ValidateSF-MASTER.pl:  Validate a TAC Cold Start Slot Filling variant output
                          file, checking for common errors.

Usage: CS-ValidateSF-MASTER.pl {-switch {-switch ...}} queryfile filename

Legal switches are:
  -allow_comments       Enable comments introduced by a pound sign in the middle
                          of an input line
  -docs <value>         Tab-separated file containing docids and document
                          lengths, measured in unnormalized Unicode characters
  -error_file <value>   Specify a file to which error output should be
                          redirected (Default = STDERR).
  -groundtruth          Treat input file as ground truth (so don't, e.g.,
                          enforce single-valued slots)
  -help                 Show help
  -output_file <value>  Specify an output file with warnings repaired. Omit for
                          validation only (Default = none).
  -version              Print version number and exit
parameters are:
  queryfile  File containing queries used to generate the file being validated
               (Required).
  filename   File containing query output. (Required).
~~~

### 2.1.5 Usage of CS-Score-MASTER.pl
~~~
CS-Score-MASTER.pl:  Score one or more TAC Cold Start runs

Usage: CS-Score-MASTER.pl {-switch {-switch ...}} files...

Legal switches are:
  -discipline <value>   Discipline for identifying ground truth (see below for
                          options) (Default = ASSESSED).
  -error_file <value>   Where should error output be sent? (filename, stdout or
                          stderr) (Default = stderr).
  -expand <value>       Expand multi-entrypoint queries, using string provided
                          as base for expanded query names
  -fields <value>       Colon-separated list of output fields to print (see
                          below for options) (Default =
                          EC:RUNID:LEVEL:GT:SUBMITTED:CORRECT:INCORRECT:INEXACT:INCOR/
                          RECT_PARENT:UNASSESSED:REDUNDANT:RIGHT:WRONG:IGNORED:P:R:F).
  -help                 Show help
  -ignore <value>       Colon-separated list of assessment codes, submitted
                          value corresponding to which to be ignored
                          (post-policy) (see policy options below for legal
                          choices) (Default = UNASSESSED).
  -output_file <value>  Where should program output be sent? (prefix of
                          filename, stdout or stderr) (Default = stdout).
  -queries <value>      file (one LDC query ID, SF query ID pair, separated by
                          space, per line with an optional number separated by
                          space representing the hop upto which evaluation is to
                          be performed) or colon-separated list of SF query IDs
                          to be scored (if omitted, all query files in 'files'
                          parameter will be scored)
  -right <value>        Colon-separated list of assessment codes, submitted
                          value corresponding to which to be counted as right
                          (post-policy) (see policy options below for legal
                          choices) (Default = CORRECT).
  -runids <value>       Colon-separated list of run IDs to be scored (if
                          omitted, all runids will be scored)
  -samples <value>      Specify the Bootstrap resamples file.
  -tabs                 Use tabs to separate output fields instead of spaces
                          (useful for export to spreadsheet)
  -version              Print version number and exit
  -wrong <value>        Colon-separated list of assessment codes, submitted
                          value corresponding to which to be counted as wrong
                          (post-policy) (see policy options below for legal
                          choices) (Default =
                          INCORRECT:INCORRECT_PARENT:INEXACT:DUPLICATE).
parameters are:
  files  Query file, submission file and judgment file (Required).

-discipline is one of the following:
  ASSESSED:     No match unless this exact entry appears in the assessments
  STRING_CASE:  String matches modulo case differences; provenance need not match
  STRING_EXACT: Exact string match, but provenance need not match
-fields is a colon-separated list drawn from the following:
  CORRECT:          Number of assessed correct responses (pre-policy)
  EC:               Query or equivalence class name
  F:                F1 = 2PR/(P+R)
  GT:               Number of ground truth values
  IGNORED:          Number of responses that were ignored (post-policy)
  INCORRECT:        Number of assessed incorrect responses (pre-policy)
  INCORRECT_PARENT: Total number of submitted entries with parents incorrect
  INEXACT:          Number of assessed inexact responses (pre-policy)
  LEVEL:            Hop level
  P:                Precision
  R:                Recall
  REDUNDANT:        Number of duplicate submitted values in equivalence clase (post-policy)
  RIGHT:            Number of submitted values counted as right (post-policy)
  RUNID:            Run ID
  SUBMITTED:        Total number of submitted entries
  UNASSESSED:       Total number of unassessed submitted entries
  WRONG:            Number of submitted values counted as wrong (post-policy)
policy options are a colon-separated list drawn from the following:
  CORRECT:          Number of assessed correct responses. Legal choice for -right.
  DUPLICATE:        Number of duplicate responses. Legal choice for -right, -wrong and -ignore.
  INCORRECT:        Number of assessed incorrect responses. Legal choice for -wrong.
  INCORRECT_PARENT: Number of responses that had incrorrect (grand-)parent. Legal choice for -wrong and -ignore.
  INEXACT:          Number of assessed inexact responses. Legal choice for -right, -wrong and -ignore.
  UNASSESSED:       Number of unassessed responses. Legal choice for -wrong and -ignore.
~~~

# 3 Generating the official scores

The scorer runs over submission in SF format. For participants of KB variant of ColdStart, the KB would need to be transformed to SF format which would then be used by the scorer. 

In order to generate scores for an SF submission, please skip to Section # 3.2 of this README. For transforming the KB submission to SF format, please move on to the next section.

## 3.1 Transforming a KB submission to SF format

This step is only required for teams participating in the KB variant of Cold Start. For scoring an SF submission as produced by teams participating in the SF variant of Cold Start please skip to Section # 3.2 of this README. 

In order to generate SF output from a KB submission, please follow the steps given below:

1. Validate KB
2. Transform validated KB to SF output format

### 3.1.1 Validate KB

In order to validate a KB named `CSrun`, you may run the following command:

~~~
perl CS-ValidateKB.pl -docs tac_kbp_2016_evaluation_source_corpus_character_counts.tsv -task CSKB -output tac -error_file CSrun.errlog -output_file CSrun.valid CSrun
~~~

This will produce the validated KB in file `CSrun.valid`.

Please note that if your KB submission is only in a specific language then you would need to use the document lengths file as specified by -docs switch specific to that language. For that purpose, the following files have been distributed:

tac_kbp_2016_chinese_evaluation_source_corpus_character_counts.tsv
tac_kbp_2016_english_evaluation_source_corpus_character_counts.tsv
tac_kbp_2016_spanish_evaluation_source_corpus_character_counts.tsv

### 3.1.2 Transform validated KB to SF output format

In order to transform the validated KB `CSrun.valid` to SF output, you may run the following command:

~~~
perl CS-ResolveQueries.pl -error_file CSrun.errlog tac_kbp_2016_cold_start_slot_filling_evaluation_queries.xml CSrun.valid CSrun.SF
~~~

This will produce the transformed SF output in `CSrun.SF`.

Please note that in order apply queries in a specific language to a given KB `CSrun.valid` you would need to use language specific queries files instead of tac_kbp_2016_cold_start_slot_filling_evaluation_queries.xml. For this purpose, the following files have been distributed:

tac_kbp_2016_chinese_cold_start_slot_filling_evaluation_queries.xml
tac_kbp_2016_english_cold_start_slot_filling_evaluation_queries.xml
tac_kbp_2016_spanish_cold_start_slot_filling_evaluation_queries.xml

Also note that using a language specific queries file does not guarantee that the transformed SF output would be in that language, all it does is apply queries originating in a given language. If producing a language specific SF output is desired then the source KB should be specific to that language.

## 3.3 Validate SF output

The next step is to validate SF output produced in the previous step. This may be done by running the following command:

~~~
perl CS-ValidateSF.pl -docs tac_kbp_2016_evaluation_source_corpus_character_counts.tsv -error_file CSrun.errlog -output_file CSrun.valid.ldc.tab.txt tac_kbp_2016_cold_start_slot_filling_evaluation_queries.xml CSrun.SF
~~~

This will produce validated SF output in `CSrun.valid.ldc.tab.txt`.

Please note that if your submission is only in a specific language then you would need to use both:
(1) the document lengths file specific to that language as specified by -docs switch, and 
(2) queries files specific to that language. 

For that purpose, the following files have been distributed:

tac_kbp_2016_chinese_evaluation_source_corpus_character_counts.tsv
tac_kbp_2016_english_evaluation_source_corpus_character_counts.tsv
tac_kbp_2016_spanish_evaluation_source_corpus_character_counts.tsv

tac_kbp_2016_chinese_cold_start_slot_filling_evaluation_queries.xml
tac_kbp_2016_english_cold_start_slot_filling_evaluation_queries.xml
tac_kbp_2016_spanish_cold_start_slot_filling_evaluation_queries.xml

## 3.4 Score output 

Finally, the last step is to produce scores for the submission. We are reporting micro and macro averages over SF and LDC-MAX scores, and macro average over LDC-MEAN score. The micro-average score computes a single P/R/F1 by summing counts across all selected queries. The macro-average score computes P/R/F1 for each query, and finally takes the mean of the query-level P/R/F1 scores for queries that have a known answer.  (Note that because the macro-average score ignores queries that have no known answer, a separate metric is needed to evaluate queries with no known answer.)

### 3.4.1 Producing the Scores

Following command may be run to produce the scores.

~~~
perl CS-Score.pl -output_file CSrun.score -queries queryids.txt -error_file CSrun.score.errlog -expand CSSF16 tac_kbp_2016_cold_start_evaluation_queries.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

Notice that the queries file used here is the LDC-level queries file `tac_kbp_2016_cold_start_evaluation_queries.xml`. In this case the scorer will use the expansion string `CSSF16` as specified by the `-expand CSSF16` switch to convert LDC queries into SF queries internally which will be used to score SF submissions. Given this the scorer will produce SF, LDC-MAX and LDC-MEAN scores.

You may also invoke the scorer without the `-expand CSSF16` switch and by using SF queries file (instead of the LDC queries file), for example, `tac_kbp_2016_cold_start_slot_filling_evaluation_queries.xml` or a language specific SF queries file, for example, 

tac_kbp_2016_chinese_cold_start_slot_filling_evaluation_queries.xml or
tac_kbp_2016_english_cold_start_slot_filling_evaluation_queries.xml or
tac_kbp_2016_spanish_cold_start_slot_filling_evaluation_queries.xml

In this case only SF scores are going to be produced.

Also notice that we have used the `-queries queryids_file` switch to produce scores using only selected queries as specified by the queryids_file.

You may optionally specify the bootstrap resample file (made available to you) using the -samples switch. In which cases the scorer will produces bootstrap sample statistics and confidence intervals using the percentile method. 

The scores will be produced in a set of files whose prefix is specified through the `-output_file CSrun.score` switch.

A subset of the following files would be produced depending on selected options:
* CSrun.score.params
* CSrun.score.confidence
* CSrun.score.debug
* CSrun.score.errlog
* CSrun.score.ldcmax
* CSrun.score.ldcmean
* CSrun.score.sample
* CSrun.score.samplescores
* CSrun.score.sf
* CSrun.score.summary

Its worth mentioning here that the scorer also produces a debug file `CSrun.score.debug` as output. The objective of this file is to increase transparency of the scoring system. You may use it to further your research by examining the assessments applied to each response in your submission. In particular, each response in the submission file is mapped with corresponding response-assessment from the assessment file (empty if the response is not assessed), and assessments at PREPOLICY and POSTPOLICY levels. 

PREPOLICY assessments refers to correctness of the response as decided by the assessor whereas POSTPOLICY assessment categorizes the responses into RIGHT, WRONG and IGNORE as specified by the switches `-right`, `-wrong` and `-ignore`. RIGHT, WRONG and IGNORE counts are used primarily by the scorer to produce Precision, Recall, and F1 scores.

policy options are a colon-separated list drawn from the following:
  CORRECT:          Number of assessed correct responses. Legal choice for -right.
  DUPLICATE:        Number of duplicate responses. Legal choice for -right, -wrong and -ignore.
  INCORRECT:        Number of assessed incorrect responses. Legal choice for -wrong.
  INCORRECT_PARENT: Number of responses that had incorrect (grand-)parent. Legal choice for -wrong and -ignore.
  INEXACT:          Number of assessed inexact responses. Legal choice for -right, -wrong and -ignore.
  UNASSESSED:       Number of unassessed responses. Legal choice for -wrong and -ignore.

# 4 Understanding the output

## 4.1 Aggregates

The scorer may produce either SF score variant or all of the follwing depending on the options selected. Aggregates reported for the variants are:

    |               |   Aggregates Reported         |
	| Score Variant | Micro-average | Macro-average |
	|---------------|---------------|---------------|
	| SF            |      Yes      |      Yes      |
	|---------------|---------------|---------------|
	| LDC-MAX       |      Yes      |      Yes      |
	|---------------|---------------|---------------|
	| LDC-MEAN      |      No       |      Yes      |
	

Aggregates are computed for the hops individually and as combined.

### 4.1.1 Computation of Micro-Average 

Micro-averages are computed as:

	Total_Precision = Total_Right / (Total_Right + Total_Wrong)
	Total_Recall = Total_Right / Total_GT
	Total_F1 = 2 * Total_Precision * Total_Recall / (Total_Precision + Total_Recall)
	
### 4.1.2 Computation of Macro-Average 
	
Macro-averages are computed as the mean Precision, mean Recall, and mean F1.

## 4.2 Score Variants

The scorer may produce the following score variants depending on the query file used for scoring:

	1. SF        Slot-filling score variant considering all entrypoints as a separate query,
	2. LDC-MAX   LDC level score variant considering the run's best entrypoint per LDC query on the basis of F1 score combined across both hops,
	3. LDC-MEAN  LDC level score variant in which the Precision, Recall, and F1 for each LDC query is the mean Precision, mean Recall, and mean F1 for all entrypoints for that LDC query.

In order to have the scorer produce LDC-MAX and LDC-MEAN score variants, the scorer must use: 

	a. LDC queries file (for example, `tac_kbp_2016_cold_start_evaluation_queries.xml`), and 
	b. -expand switch with correct expansion string (for example, `-expand CSSF16`).

Summary of scores is presented towards the end of the scorer output.

## 4.3 Output files

As mentioned above that the scorer produces a subset of the following files depending on the options selected.

    CSrun.score.params       Lists when, how, and with what options the scorer was invoked
    CSrun.score.errlog       Reports errors encounterd while scoring, if any
    CSrun.score.debug        Includes response level pre-policy and post-policy assessments
    CSrun.score.sf           Lists counts and scores based on SF variant
    CSrun.score.ldcmax       Lists counts and scores based on LDC-MAX variant
    CSrun.score.ldcmean      Lists counts and scores based on LDC-MEAN variant
    CSrun.score.summary      Lists summary of the scores
    CSrun.score.sample       Lists the bootstrap resample in format matching the samplesscores
    CSrun.score.samplescores Lists the bootstrap resample statistics
    CSrun.score.confidence   Reports confidence intervals based on the bootstrap resampling statistics using the percentile method

## 4.4 Output fields

By default, for each query and hop level, the scorer outputs the following counts:

    GT	        Total number of ground truth answers (equivalence classes) as found by the assessors,
    Submitted   Number of responses in the submission
    Correct     Number of responses in the submission that were assessed as Correct,
    Incorrect   Number of responses in the submission that were assessed as Wrong,
    Inexact     Number of responses in the submission that were assessed as Inexact,
    PIncorrect  Number of responses in the submission that had incorrect ancestor,
    Unassessed  Number of responses in the submission that were not assessed,
    Dup         Number of responses that were assessed as Correct but found to be duplicate of another Correct in the same submission, 
    Right       Number of responses in the submission counted as Right, as specified by argument to swtich `-right`,
    Wrong       Number of responses in the submission counted as Wrong, as specified by argument to swtich `-wrong`, 
    Ignored	    Number of responses in the submission that were ignored for the purpose of score computation, as specified by argument to the switch `-ignore`,
    Precision   Computed as: Right / (Right + Wrong),
    Recall      Computed as: Right / GT,
    F1          Computed as: 2 * Precision * Recall / (Precision + Recall).
    
where Right, Wrong, and Ignored are computed based on selected post-policy decision, specified using switches `-right, -wrong, and -ignore` (See the usage for detail). 
    
Note that scores for round # 2 (or hop-1) are reported at the equivalence class (EC) level and not at the generated query level. For example, the scores given for `CSSF15_ENG_0458206f71:2` are the scores corresponding to the entity found as answer for round # 1 (or hop-0) query `CSSF15_ENG_0458206f71` which was placed by assessors in equivalence class 2. Similarly, the scores given for `CSSF15_ENG_0458206f71:0` are the scores corresponding to all hop-1 answers which correspond to incorrect hop-0 fillers. 
