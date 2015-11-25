# 1 Introduction

November 25, 2015

This document describes:

1. How to generate the official scores for a KB/SF submission for 2015; and
2. How to interpret scores output.

# 2 Scripts

You are provided the following scripts:

1. CS-GenerateQueries.pl (v1.8)
2. CS-ResolveQueries.pl (v2015.1.1)
3. CS-ValidateKB.pl (v4.9)
4. CS-ValidateSF.pl (v1.9)
5. CS-ValidateSF-QueryIDCorrector.pl (v1.6)
6. CS-Score.pl (v2.3.1)
7. CS-ProjectSFScoreToLDCScores.pl (v1.2)

## 2.1 Scripts usage

The usage of above mentioned scripts can be seen by running with option -h or without any argument. For record, the usage of these scripts is given below:

### 2.1.1 Usage of CS-GenerateQueries.pl
~~~
CS-GenerateQueries.pl:  Generate a query file for a Cold Start Slot Filling
                        variant submission. With two arguments, it updates the
                        input queries with the <slot> field. With three
                        arguments it generates a second round query file based
                        on the first round slot filling output.

Usage: CS-GenerateQueries.pl {-switch {-switch ...}} queryfile outputfile {runfile}

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

### 2.1.2 Usage of CS-ResolveQueries.pl
~~~
CS-ResolveQueries.pl:  Apply a set of evaluation queries to a knowledge base to
                       produce Cold Start output for assessment.

Usage: CS-ResolveQueries.pl {-switch {-switch ...}} queryfile runfile output_file

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

### 2.1.3 Usage of CS-ValidateKB.pl
~~~
CS-ValidateKB.pl:  Validate a TAC Cold Start KB file, checking for common
                   errors, and optionally exporting to a variety of formats.

Usage: CS-ValidateKB.pl {-switch {-switch ...}} filename

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
                          ILLEGAL_LINK_SPECIFICATION, MISMATCHED_HOP_SUBTYPES,
                          MISMATCHED_HOP_TYPES, MISMATCHED_RUNID,
                          MISMATCHED_TAGS, MISSING_CANONICAL,
                          MISSING_DECIMAL_POINT, MISSING_INVERSE,
                          MISSING_TYPEDEF, MULTIPLE_CORRECT_GROUND_TRUTH,
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
  -task <value>         Specify task to validate. Legal values are: CSED (Cold
                          Start Entity Discovery variant), CSEDL (Cold Start
                          Entity Discovery and Linking variant), CSKB (Cold
                          Start Knowledge Base variant). (Default = CSKB).
  -version              Print version number and exit
parameters are:
  filename  File containing input KB specification. (Required).
~~~

### 2.1.4 Usage of CS-ValidateSF.pl
~~~
CS-ValidateSF.pl:  Validate a TAC Cold Start Slot Filling variant output file,
                   checking for common errors.

Usage: CS-ValidateSF.pl {-switch {-switch ...}} queryfile filename

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

### 2.1.5 Usage of CS-ValidateSF-QueryIDCorrector.pl
~~~
CS-ValidateSF-QueryIDCorrector.pl:  Validate a TAC Cold Start Slot Filling
                                    variant output file, checking for common
                                    errors.

Usage: CS-ValidateSF-QueryIDCorrector.pl {-switch {-switch ...}} queryfile filename

Legal switches are:
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

### 2.1.6 Usage of CS-Score.pl
~~~
CS-Score.pl:  Score one or more TAC Cold Start runs

Usage: CS-Score.pl {-switch {-switch ...}} files...

Legal switches are:
  -combo <value>        How scores should be combined (see below for options)
                          (Default = MICRO).
  -discipline <value>   Discipline for identifying ground truth (see below for
                          options) (Default = ASSESSED).
  -error_file <value>   Where should error output be sent? (filename, stdout or
                          stderr) (Default = stderr).
  -expand <value>       Expand multi-entrypoint queries, using string provided
                          as base for expanded query names
  -help                 Show help
  -output_file <value>  Where should program output be sent? (filename, stdout
                          or stderr) (Default = stdout).
  -queries <value>      file (one query ID per line) or colon-separated list of
                          query IDs to be scored (if omitted, all query files in
                          'files' parameter will be scored)
  -runids <value>       Colon-separated list of run IDs to be scored (if
                          omitted, all runids will be scored)
  -tabs                 Use tabs to separate output fields instead of spaces
                          (useful for export to spreadsheet)
parameters are:
  files  Query files, submission files and judgment files (Required).

Discipline is one of the following:
  ASSESSED:     No match unless this exact entry appears in the assessments
  STRING_CASE:  String matches modulo case differences; provenance need not match
  STRING_EXACT: Exact string match, but provenance need not match
Combo is one of the following:
  MACRO: Macro-average scores across entrypoints  (UNTESTED - do not exercise this option)
  MICRO: Micro-average scores across entrypoints
  UNION: Estimate performance if system took union of answers for all entrypoints (UNTESTED - do not exercise this option)
~~~

### 2.1.7 Usage of CS-ProjectSFScoreToLDCScores.pl
~~~
CS-ProjectSFScoreToLDCScores.pl:  Score one TAC Cold Start runs

Usage: CS-ProjectSFScoreToLDCScores.pl {-switch {-switch ...}} index_file score_file

Legal switches are:
  -error_file <value>   Where should error output be sent? (filename, stdout or
                          stderr) (Default = stdout).
  -help                 Show help
  -mapping <value>      File containing one SF queryid mapped to an LDC queryid.
                          This option is required when using the RANDOM scoring
                          option.
  -output_file <value>  Where should program output be sent? (filename, stdout
                          or stderr) (Default = stdout).
  -queries <value>      File containing list of LDC queryids that should be
                          reported in the evaluation
  -score <value>        Specify scoring option. Legal values are: MAX (Pick the
                          highest scoring entrypoint), MEAN (Pick the mean
                          across all entrypoints), RANDOM (Pick a random
                          entrypoint). (Default = MAX).
  -tabs                 Use tabs to separate output fields instead of spaces
parameters are:
  index_file  Filename which contains mapping from output query name to original
                LDC query name (Required).
  score_file  CSSF Score file to be converted (Required).
~~~

# 3 Generating the official scores

The scorer runs over submission in SF format. For participants of KB variant of ColdStart, the KB would need to be transformed to the SF format which would then be used by the scorer. 

In order to generate scores for an SF submission, please skip to Section # 3.2 of this README. For transforming the KB submission to SF format, please move on to the next section.

## 3.1 Transforming a KB submission to SF format

This step is only required for teams participating in the KB variant of Cold Start. For scoring the SF submission as produced by teams participating in the SF variant of Cold Start please skip to Section # 3.2 of this README. 

In order to generate SF output from a KB submission, please follow the steps given below:

1. Validate KB
2. Transform validated KB to SF output format

### 3.1.1 Validate KB

In order to validate a KB named `CSrun`, you may run the following command:

~~~
perl CS-ValidateKB.pl -docs tac_2015_kbp_english_cold_start_evaluation_source_corpus.doclengths.txt -task CSKB -output tac -error_file CSrun.errlog -output_file CSrun.valid CSrun
~~~

This will produce the validated KB in file `CSrun.valid`.

### 3.1.2 Transform validated KB to SF output format

In order to transform the validated KB `CSrun.valid` to SF output, you may run the following command:

~~~
perl CS-ResolveQueries.pl -error_file CSrun.errlog tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.valid CSrun.SF
~~~

This will produce the transformed SF output in `CSrun.SF`.

## 3.2 Apply a patch to correct query IDs generated for round # 2 (or hop-1)

If round # 2 (or hop-1) query IDs were generated from the scripts generated from the ColdStartLib.pm that contained a bug in how these query IDs were generated, you would need to apply a patch to the SF submission or SF output transformed from validated KB as produced in Section # 3.1.2 in this README.

This bug was present in all the scripts released to TAC participants at this year submission time.

In order to apply the patch, you may run the following command:

~~~
perl CS-ValidateSF-QueryIDCorrector.pl -docs tac_2015_kbp_english_cold_start_evaluation_source_corpus.doclengths.txt -error_file CSrun.errlog -output_file CSrun.SF.corrected tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.SF
~~~

This would created a patched file `CSrun.SF.corrected`.

If you needed to apply the patch, you would need to rename the file `CSrun.SF.corrected` as `CSrun.SF` before moving on to the next section.

### 3.3 Validate SF output

The next step is to validate SF output produced in the previous step. This may be done by runing the following command:

~~~
perl CS-ValidateSF.pl -docs tac_2015_kbp_english_cold_start_evaluation_source_corpus.doclengths.txt -error_file CSrun.errlog -output_file CSrun.valid.ldc.tab.txt tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.SF
~~~

This will produce validated SF output in `CSrun.valid.ldc.tab.txt`.

### 3.4 Score SF output 

Finally, the last step is to produce scores for the submission. The micro-average score computes a single P/R/F1 by summing counts across all selected queries. The macro-average score computes P/R/F1 for each query, and finally takes the mean of the query-level F1 scores for queries that have a known answer.  (Note that because the macro-average score ignores queries that have no known answer, a separate metric is needed to evaluate queries with no known answer.)

#### 3.4.1 Producing the CS-SF level scores

Following command may be run to produce the micro average scores at the CS-SF level.

~~~
perl CS-Score.pl -output_file CSrun.score.cssf.txt -queries cssf_queryids.txt -combo MICRO tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

Notice that we have used the -queries switch to score selected queries. Also, note that our is assumption is that the assessment are placed in `pool.assessed.fqec`.

The scores will be produced in `CSrun.score.cssf.txt`.

#### 3.4.2 Producing the CS-LDC level scores (COMBO)  (UNTESTED - do not exercise this option)

Following command may be run to produce the micro average scores at the CS-LDC level.

~~~
perl CS-Score.pl -output_file CSrun.score.csldc.combo.txt -queries csldc_queryids.txt -combo UNION -expand CSSF15_ENG tac_kbp_2015_english_cold_start_evaluation_queries_v2.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

The scores will be produced in `CSrun.score.csldc.combo.txt`.

#### 3.4.3 Producing the CS-LDC level scores (CS-ProjectSFScoreToLDCScores.pl)

The following variants of CS-LDC level scores are supported by the CS-ProjectSFScoreToLDCScores.pl scorer. Please note that the CS-SF level scores must have already been computed before creating the projected scores at the CS-LDC level.

##### 3.4.3.1 MAX Score

The MAX score considers only one entry point (SF query) per LDC query.  The entry point that is selected for a given LDC query as the entrypoint for which F1 combined over both hops is maximal for that LDC query.  Following command may be run to compute micro-average and macro-average MAX scores for the submission.  

~~~
perl CS-ProjectSFScoreToLDCScores.pl -score MAX -output_file CSrun.score.csldc.max.txt queries.index CSrun.score.cssf.txt
~~~

The scores will be produced in `CSrun.score.csldc.max.txt`.

##### 3.4.3.2 RANDOM Score

The RANDOM score considers only one entry point (SF query) per LDC query.  The entry point that is (possibly randomly) selected for each LDC query must be specified in a separate mapping file.  Following command may be run to compute micro-average and macro-average RANDOM scores for the submission.


~~~
perl CS-ProjectSFScoreToLDCScores.pl -score RANDOM -mapping sample-mapping.txt -output_file CSrun.score.csldc.random.txt queries.index CSrun.score.cssf.txt
~~~

This requires a file which contains information about which entrypoint was selected for a given LDC query at random. This file contains LDC-QueryID, SF-QueryID pair perl line separated by a space as shown below:

~~~
CS15_ENG_0001 CSSF15_ENG_811cc7bb37
CS15_ENG_0002 CSSF15_ENG_2891c91dfa
... ...
~~~

The scores will be produced in `CSrun.score.csldc.random.txt`.

##### 3.4.3.3 MEAN Score

The MEAN score is a macro-average score that considers all entry points for each LDC query.  The LDC query-level F1 is the mean of the F1 of its entry points, and the macro-average MEAN score is the mean of the LDC query-level F1.  Following command may be run to compute the macro-average MEAN score for the submission.

~~~
perl CS-ProjectSFScoreToLDCScores.pl -score MEAN -output_file CSrun.score.csldc.mean.txt queries.index CSrun.score.cssf.txt
~~~

The scores will be produced in `CSrun.score.csldc.mean.txt`. 

It is important to note that only macro-average is reported in this case.

# 4 Understanding the output

## 4.1 CS-SF level scores - MICRO AVERAGE

For each query and hop level, the CS-Score.pl scorer outputs the following counts:
    GT	       Total number of ground truth answers (equivalence classes) as found by the assessors,
    Right      Number of correct answers (equivalence classes) found in the submission,
    Wrong      Number of responses in the submission counted as Wrong, 
    Dup	       Number of responses counted as Wrong because they were assessed as Correct but found to be duplicate of another Correct in the same submission, 

For each query and hop level, Precision, Recall and F1 are computed as:
	Precision	= Right / (Right + Wrong)
	Recall		= Right / GT
	F1			= 2 * Precision * Recall / (Precision + Recall)

Note that scores for round # 2 (or hop-1) are reported at the equivalence class (EC) level and not at the generated query level. For example, the scores given for `CSSF15_ENG_0458206f71:2` are the scores corresponding to the entity found as answer for round # 1 (or hop-0) query `CSSF15_ENG_0458206f71` which was placed by assessors in equivalence class 2. Similarly, the scores given for `CSSF15_ENG_0458206f71:0` are the scores corresponding to all hop-1 answers which correspond to incorrect hop-0 fillers. 

Final scores are micro averages and are computed for both hops separately and combined. 
These final scores are computed as:

	Total_Precision = Total_Right / (Total_Right + Total_Wrong)
	Total_Recall = Total_Right / Total_GT
	Total_F1 = 2 * Total_Precision * Total_Recall / (Total_Precision + Total_Recall)

## 4.2 CS-LDC level MAX scores - MICRO AVERAGE

These scores are computed from the SF level scores as described in Section # 4.1 of this README. In this case, the LDC level scores and counts are the same as the SF level scores and counts corresponding to the entry point for the LDC query that has maximal F1 combined over both hops.

## 4.3 CS-LDC level RANDOM scores - MICRO AVERAGE

These scores are computed from the SF level scores as described in Section # 4.1 of this README. In this case, the LDC level scores and counts are the same as the SF level scores and counts corresponding to the entry point for the LDC query that is specified in the mapping file.
