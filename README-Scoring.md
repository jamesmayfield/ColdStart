# 1 Introduction

February 19, 2016

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
6. CS-Score.pl (v2.4.3)

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
  -error\_file <value>   Specify a file to which error output should be
                          redirected (Default = STDERR).
  -groundtruth          Treat input file as ground truth (so don't, e.g.,
                          enforce single-valued slots)
  -help                 Show help
  -output\_file <value>  Specify an output file with warnings repaired. Omit for
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
  -output_file <value>  Where should program output be sent? (filename, stdout
                          or stderr) (Default = stdout).
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
  -tabs                 Use tabs to separate output fields instead of spaces
                          (useful for export to spreadsheet)
  -verbose              Print verbose output
  -version              Print version number and exit
  -wrong <value>        Colon-separated list of assessment codes, submitted
                          value corresponding to which to be counted as wrong
                          (post-policy) (see policy options below for legal
                          choices) (Default =
                          INCORRECT:INCORRECT_PARENT:INEXACT:DUPLICATE).
parameters are:
  files  Query files, submission files and judgment files (Required).

-discipline is one of the following:
  ASSESSED:     No match unless this exact entry appears in the assessments
  STRING_CASE:  String matches modulo case differences; provenance need not match
  STRING_EXACT: Exact string match, but provenance need not match
-fields is a colon-separated list drawn from the following:
  CORRECT:          Number of assessed correct submissions (pre-policy)
  EC:               Query or equivalence class name
  F:                F1 = 2PR/(P+R)
  GT:               Number of ground truth values
  IGNORED:          Number of submissions that were ignored (post-policy)
  INCORRECT:        Number of assessed incorrect submissions (pre-policy)
  INCORRECT_PARENT: Total number of submitted entries with parents incorrect
  INEXACT:          Number of assessed inexact submissions (pre-policy)
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
  CORRECT:          Number of assessed correct submissions. Legal choice for -right.
  DUPLICATE:        Number of duplicate submissions. Legal choice for -right, -wrong and -ignore.
  INCORRECT:        Number of assessed incorrect submissions. Legal choice for -wrong.
  INCORRECT_PARENT: Number of submissions that had incrorrect (grand-)parent. Legal choice for -wrong and -ignore.
  INEXACT:          Number of assessed inexact submissions. Legal choice for -right, -wrong and -ignore.
  UNASSESSED:       Number of unassessed submissions. Legal choice for -wrong and -ignore.
~~~

# 3 Generating the official scores

The scorer runs over submission in SF format. For participants of KB variant of ColdStart, the KB would need to be transformed to SF format which would then be used by the scorer. 

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

This bug was present in all the scripts released to TAC participants at the submission time for year 2015.

In order to apply the patch, you may run the following command:

~~~
perl CS-ValidateSF-QueryIDCorrector.pl -docs tac_2015_kbp_english_cold_start_evaluation_source_corpus.doclengths.txt -error_file CSrun.errlog -output_file CSrun.SF.corrected tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.SF
~~~

This would create a patched file `CSrun.SF.corrected`.

If you needed to apply the patch, you would need to rename the file `CSrun.SF.corrected` as `CSrun.SF` before moving on to the next section.

## 3.3 Validate SF output

The next step is to validate SF output produced in the previous step. This may be done by runing the following command:

~~~
perl CS-ValidateSF.pl -docs tac_2015_kbp_english_cold_start_evaluation_source_corpus.doclengths.txt -error_file CSrun.errlog -output_file CSrun.valid.ldc.tab.txt tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.SF
~~~

This will produce validated SF output in `CSrun.valid.ldc.tab.txt`.

## 3.4 Score output 

Finally, the last step is to produce scores for the submission. The micro-average score computes a single P/R/F1 by summing counts across all selected queries. The macro-average score computes P/R/F1 for each query, and finally takes the mean of the query-level F1 scores for queries that have a known answer.  (Note that because the macro-average score ignores queries that have no known answer, a separate metric is needed to evaluate queries with no known answer.)

### 3.4.1 Producing the Scores

Following command may be run to produce the CS-SF scores.

~~~
perl CS-Score.pl -output_file CSrun.score.cssf.txt -queries cssf_queryids.txt tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries_v2.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

In order to produce CS-LDC level scores in addition to CS-SF score, you may run the following command:

~~~
perl CS-Score.pl -output_file CSrun.score.all.txt -queries cssf_queryids.txt -expand CSSF15_ENG tac_kbp_2015_english_cold_start_evaluation_queries_v2.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

Notice that we have used the -queries switch to score selected queries. Also, note that our is assumption is that the assessment are placed in `pool.assessed.fqec`.

The difference between the above examples is that the later one uses LDC queries file requiring the scorer to convert these queries to SF queries for scoring. The scorer does this by using an expansion string specified through the switch `-expand CSSF15_ENG`.

The scores will be produced in the file specified through the `-output_file` switch.

# 4 Understanding the output

## 4.1 Aggregates

The scorer may produce more than one score variant depending on the options selected. Aggregates reported for the variants are:

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
	
Macro-averages are computed as the mean of all F1.

## 4.2 Score Variants

The scorer may produce the following score variant depending on the query file used for scoring:

	1. SF        Slot-filling score variant considering all entrypoints as a separate query,
	2. LDC-MAX   LDC level score variant considering the run's best entrypoint per LDC query,
	3. LDC-MEAN  LDC level score variant considering averaging scores for all corresponding entrypoints, and

In order to have the scorer produce LDC-MAX and LDC-MEAN score variants, the scorer must use: 

	a. LDC queries file (for example, `tac_kbp_2015_english_cold_start_evaluation_queries_v2.xml`), and 
	b. -expand switch with correct expansion string (for example, `-expand CSSF15_ENG`).

Summary of scores is presented towards the end of the scorer output.

## 4.3 Output fields

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
    Ignored	    Number of responses in the submission that were ignored for the purpose of score computation, as specified by argument to swtich `-ignore`,
    Precision   Computed as: Right / (Right + Wrong),
    Recall      Computed as: Right / GT,
    F1          Computed as: 2 * Precision * Recall / (Precision + Recall).
    
where Right, Wrong, and Ignored are computed based on selected post-policy decision, specified using switches `-right, -wrong, and -ignore` (See the usage for detail). 
    
Note that for the score variant LDC-MEAN, for each query and hop level, the scorer only outputs the F1 field.

Also note that scores for round # 2 (or hop-1) are reported at the equivalence class (EC) level and not at the generated query level. For example, the scores given for `CSSF15_ENG_0458206f71:2` are the scores corresponding to the entity found as answer for round # 1 (or hop-0) query `CSSF15_ENG_0458206f71` which was placed by assessors in equivalence class 2. Similarly, the scores given for `CSSF15_ENG_0458206f71:0` are the scores corresponding to all hop-1 answers which correspond to incorrect hop-0 fillers. 
