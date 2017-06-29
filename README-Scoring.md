# 1 Introduction

June 29, 2017

This document describes:

1. How to generate the official scores for a KB/SF submission for 2017; and
2. How to interpret scores output.
3. How to read the debug file

# 2 Scripts

Refer to README-Usage for details on how to use various scripts

# 3 Generating the official scores

The scorer runs over submission in SF format. For participants of KB variant of ColdStart, the KB would need to be transformed to SF format which would then be used by the scorer. 
README-Usage provides a detail of how to generate a valid input file for evaluation of slot filling component from a KB submission. We treat redundant responses differently depending on if we are scoring an SF submission or an SF file generated from a submitted KB (referred to as KB->SF). Redundant responses are considered spurious if coming from an SF submission and are ignored otherwise. This is why we have to specify the post-policy decision differently. Both the cases are described separately below:

## 3.1 Scoring a KB->SF submission

We are reporting AP-based score as described in the task description in addition to the scores produced last year. In particular, we are reporting (1) macro averages AP scores for SF and LDC-MEAN and, (2) same as last year, micro and macro averages P/R/F1 over SF and LDC-MAX scores, and macro average P/R/F1 over LDC-MEAN score. The scores based on last year specifications would ignore the redundants by default. In order to compute scores that are comparable to last year see Section 3.2 below. 

The micro-average P/R/F score computes a single P/R/F1 by summing counts across all selected queries. The macro-average P/R/F score computes P/R/F1 for each query, and finally takes the mean of the query-level P/R/F1 scores for queries that have a known answer.  (Note that because the macro-average score ignores queries that have no known answer, a separate metric is needed to evaluate queries with no known answer.)

~~~
perl CS-Score.pl -output_file CSrun_score -queries queryids.txt -error_file CSrun_score.errlog -expand CSSF17 tac_kbp_2017_cold_start_evaluation_queries.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~

Notice that the queries file used here is the LDC-level queries file `tac_kbp_2017_cold_start_evaluation_queries.xml`. In this case the scorer will use the expansion string `CSSF17` as specified by the `-expand CSSF17` switch to convert LDC queries into SF queries internally which will be used to score SF submissions. Given this the scorer will produce SF, LDC-MAX and LDC-MEAN scores.

You may also invoke the scorer without the `-expand CSSF17` switch and by using SF queries file (instead of the LDC queries file), for example, `tac_kbp_2017_cold_start_slot_filling_evaluation_queries.xml` or a language specific SF queries file, for example,

tac_kbp_2017_chinese_cold_start_slot_filling_evaluation_queries.xml or
tac_kbp_2017_english_cold_start_slot_filling_evaluation_queries.xml or
tac_kbp_2017_spanish_cold_start_slot_filling_evaluation_queries.xml

In this case only SF scores are going to be produced.

Also notice that we have used the `-queries queryids_file` switch to produce scores using only selected queries as specified by the queryids_file.

You may optionally specify the bootstrap resample file (made available to you) using the -samples switch. In which cases the scorer will produces bootstrap sample statistics and confidence intervals using the percentile method.

The scores will be produced in a set of files whose prefix is specified through the `-output_file CSrun_score` switch.

A subset of the following files would be produced depending on selected options:
* CSrun_score.params
* CSrun_score.confidence
* CSrun_score.debug
* CSrun_score.errlog
* CSrun_score.ap (New in 2017; contains AP-based scores)
* CSrun_score.ldcmax
* CSrun_score.ldcmean
* CSrun_score.sample
* CSrun_score.samplescores
* CSrun_score.sf
* CSrun_score.summary

Its worth mentioning here that the scorer also produces a debug file `CSrun_score.debug` as output. The objective of this file is to increase transparency of the scoring system. You may use it to further your research by examining the assessments applied to each response in your submission. In particular, each response in the submission file is mapped with corresponding response-assessment from the assessment file (empty if the response is not assessed), and assessments at PREPOLICY and POSTPOLICY levels.

In addition to the information included in the debug file last year, this year we are adding 

(1) the TARGET_QUERY_ID (which is the hash to be used for next round query) with each submission,
(2) FQNODEID (which is the fully-qualified KB nodeid) with each submission line, and
(3) the debug information for computing AP-based score.

PREPOLICY assessments refers to correctness of the response as decided by the assessor whereas POSTPOLICY assessment categorizes the responses into RIGHT, WRONG and IGNORE as specified by the switches `-right`, `-wrong` and `-ignore`. RIGHT, WRONG and IGNORE counts are used primarily by the scorer to produce scores.

policy options are a colon-separated list drawn from the following:
  CORRECT:          Number of assessed correct responses. Legal choice for -right.
  DUPLICATE:        Number of duplicate responses. Legal choice for -right, -wrong and -ignore.
  INCORRECT:        Number of assessed incorrect responses. Legal choice for -wrong.
  INCORRECT_PARENT: Number of responses that had incorrect (grand-)parent. Legal choice for -wrong and -ignore.
  INEXACT:          Number of assessed inexact responses. Legal choice for -right, -wrong and -ignore.
  UNASSESSED:       Number of unassessed responses. Legal choice for -wrong and -ignore.

## 3.2 Scoring an SF submission

Scoring an SF submission differs from that of a KB->SF submission because of the way we treat redundants. Multiple justifications are not allowed in an SF submission so it should not return a redundant response, same as last year. Therefore, we change the post-policy decision accordingly. o

An example command to score such a submission is shown below. Note that this also applies to the case when we want to compute a last-year comparable score for a KB->SF submission.

~~~
perl CS-Score.pl -output_file CSrun_score -queries queryids.txt -error_file CSrun_score.errlog -expand CSSF17 -justifications 1:1 -ignore UNASSESSED -wrong INCORRECT:INCORRECT_PARENT:INEXACT:DUPLICATE tac_kbp_2017_cold_start_evaluation_queries.xml CSrun.valid.ldc.tab.txt pool.assessed.fqec
~~~


# 4 Understanding the output

## 4.1 Aggregates

The scorer may produce either SF score variant or all of the following depending on the options selected. Aggregates reported for the variants are:

~~~
|               |   Aggregates Reported         |
|               |-------------------------------|
|               | Micro-average | Macro-average |
|               |---------------|---------------|
| Score Variant | AP | P/R/F1   |  AP | P/R/F1  |
|---------------|----|----------|-----|---------|
| SF            | No | Yes      | Yes |Yes      |
|---------------|----|----------|-----|---------|
| LDC-MAX       | No | Yes      | No  |Yes      |
|---------------|----|----------|-----|---------|
| LDC-MEAN      | No | No       | Yes |Yes      |
~~~

Aggregates are computed for the hops individually and also as combined across all hops.

### 4.1.1 Computation of Micro-Average 

Micro-averages are computed as:

	Total_Precision = Total_Right / (Total_Right + Total_Wrong)
	Total_Recall = Total_Right / Total_GT
	Total_F1 = 2 * Total_Precision * Total_Recall / (Total_Precision + Total_Recall)
	
### 4.1.2 Computation of Macro-Average 
	
Macro-averages are computed as the mean Precision, mean Recall, mean F1 and mean AP.

## 4.2 Score Variants

The official score for 2017 is an AP-based score for which the following score variants are produced:

	1. SF        Slot-filling score variant considering all entrypoints as a separate query,
	2. LDC-MEAN  LDC level score variant in which AP for each LDC query is the mean of APs of all entrypoints for that LDC query.

The scorer may produce the following score variants for P/R/F1 depending on the query file used for scoring:

	1. SF        Slot-filling score variant considering all entrypoints as a separate query,
	2. LDC-MAX   LDC level score variant considering the run's best entrypoint per LDC query on the basis of F1 score combined across both hops,
	3. LDC-MEAN  LDC level score variant in which the Precision, Recall, and F1 for each LDC query is the mean Precision, mean Recall, and mean F1 for all entrypoints for that LDC query.

In order to have the scorer produce LDC-MAX and LDC-MEAN score variants, the scorer must use: 

	a. LDC queries file (for example, `tac_kbp_2016_cold_start_evaluation_queries.xml`), and 
	b. -expand switch with correct expansion string (for example, `-expand CSSF16`).

Summary of scores is presented towards the end of the scorer output.

## 4.3 Computation of AP-based score

The official score for 2017 is an AP-based score which is computed as described below.

Before we descibe the official score computation, lets understand that Average Precision is a rank based measure that is used to report quality of a ranked list. Let there be five known correct answers to a query for which we got the following ranked list: RNRRNR (where the left-most item is represents the first result and R represents relevant and N represents no-relevant).

| Rank | R/N | Precision at Rank |
|----|----|----|
| 1 | R | 1/1 |
| 2 | N | -   |
| 3 | R | 2/3 |
| 4 | R | 3/4 |
| 5 | N | -   |
| 6 | R | 4/6 |

AP = (1 + 2/3 + 3/4 + 4/)/5

Similarly, AP of RRRRNN is (1+1+1+1)/5 and that of NNRRRR is (1/3+2/4+3/5+4/6)/5.

The official score computation differs from the AP computation because for our ranking of the nodes the V value is not binary, as shown below. Our ranked list in the example given below is 0.6667, 1, 0, 0, 0, 0.

| Rank | V | Precision at Rank |
|----|----|----|
| 1 | 0.6667 | 0.6667/1 |
| 2 | 1.0000 | 1.6667/2   |
| 3 | 0.0000 | - |
| 4 | 0.0000 | - |
| 5 | 0.0000 | - |
| 6 | 0.0000 | - |

Therefore the official AP-based score is (0.6667 + 1.6667/2)/4.
~~~
=============================================================================================
QUERY_ID:         CSSF17_ENG_afddc4ed21
LEVEL:            1
AP:               0.3750
NUM_GROUND_TRUTH: 4
GROUND TRUTH:
  CSSF17_ENG_afddc4ed21:1:1
  CSSF17_ENG_afddc4ed21:1:2
  CSSF17_ENG_afddc4ed21:2:1
  CSSF17_ENG_afddc4ed21:2:2
RANKING:
........
RANK NODEID                                     CONFIDENCE  MAPPED_EC                  V
---------------------------------------------------------------------------------------------
1    CSSF17_ENG_afddc4ed21:Entity102:Entity111  0.7396      CSSF17_ENG_afddc4ed21:1:2  0.6667
2    CSSF17_ENG_afddc4ed21:Entity102:Entity110  0.6001      CSSF17_ENG_afddc4ed21:1:1  1.0000
3    CSSF17_ENG_afddc4ed21:Entity103:Entity111  0.4653      -                          0.0000
4    CSSF17_ENG_afddc4ed21:Entity104:Entity110  0.4581      -                          0.0000
5    CSSF17_ENG_afddc4ed21:Entity104:Entity111  0.4513      -                          0.0000
6    CSSF17_ENG_afddc4ed21:Entity103:Entity110  0.4172      -                          0.0000
=============================================================================================
~~~

## 4.4 Output files

As mentioned above that the scorer produces a subset of the following files depending on the options selected.

    CSrun_score.params       Lists when, how, and with what options the scorer was invoked
    CSrun_score.errlog       Reports errors encounterd while scoring, if any
    CSrun_score.ap           Lists SF and LDC-MEAN variants of the AP scores including the summary at the end
    CSrun_score.debug        Includes response level pre-policy and post-policy assessments and AP computation steps
    CSrun_score.sf           Lists counts and scores based on SF variant
    CSrun_score.ldcmax       Lists counts and scores based on LDC-MAX variant
    CSrun_score.ldcmean      Lists counts and scores based on LDC-MEAN variant
    CSrun_score.summary      Lists summary of the P/R/F1 scores
    CSrun_score.sample       Lists the bootstrap resample in format matching the samplesscores
    CSrun_score.samplescores Lists the bootstrap resample statistics
    CSrun_score.confidence   Reports confidence intervals based on the bootstrap resampling statistics using the percentile method

## 4.5 Output fields

By default, for each query and hop level, the scorer outputs the following counts:

    GT          Total number of ground truth answers (equivalence classes) as found by the assessors,
    Submitted   Number of responses in the submission,
    Correct     Number of responses in the submission that were assessed as Correct,
    Incorrect   Number of responses in the submission that were assessed as Wrong,
    Inexact     Number of responses in the submission that were assessed as Inexact,
    PIncorrect  Number of responses in the submission that had incorrect ancestor,
    Unassessed  Number of responses in the submission that were not assessed,
    Dup         Number of responses that were assessed as Correct but found to be duplicate of another Correct in the same submission, 
    Right       Number of responses in the submission counted as Right, as specified by argument to swtich `-right`,
    Wrong       Number of responses in the submission counted as Wrong, as specified by argument to swtich `-wrong`, 
    Ignored     Number of responses in the submission that were ignored for the purpose of score computation, as specified by argument to the switch `-ignore`,
    AP          Computed as described in Section 4.3 above,
    Precision   Computed as: Right / (Right + Wrong),
    Recall      Computed as: Right / GT,
    F1          Computed as: 2 * Precision * Recall / (Precision + Recall).
    
where Right, Wrong, and Ignored are computed based on selected post-policy decision, specified using switches `-right, -wrong, and -ignore` (See the usage for detail). 
    
Note that scores for round # 2 (or hop-1) are reported at the equivalence class (EC) level and not at the generated query level. For example, the scores given for `CSSF15_ENG_0458206f71:2` are the scores corresponding to the entity found as answer for round # 1 (or hop-0) query `CSSF15_ENG_0458206f71` which was placed by assessors in equivalence class 2. Similarly, the scores given for `CSSF15_ENG_0458206f71:0` are the scores corresponding to all hop-1 answers which correspond to incorrect hop-0 fillers. 

## 4.6 Understanding the debug file

The debug file has been extended in 2017. Major changes include:

(1) Addition of debug information for AP computation, and
(2) Storing TARGET_QID and FQNODEID with each submission entry.

This section describes the content of the debug file in details. The file can be broken down into two major parts:

(1) Per-query response pre/post-policy assessment
(2) AP computation debug information

### 4.6.1 Per-query response pre-and-post-policy assessment

The debug file begins with per-query response pre-and-post-policy assessment information where each query response is mapped to its pre-and-post-policy assessment, in particular, if the response has an assessment, the line from the assessment file is paired with it.

An example line is shown below:

~~~
        FQNODEID:       CSSF17_ENG_afddc4ed21:Entity104
        SUBMISSION:     CSSF17_ENG_afddc4ed21   per:children    SCORER_TS_SPLIT SIMPSONS_012:67-112     Lisa Simpson    PER     SIMPSONS_012:81-94      0.9864  :Entity104
        TARGET_QID:     CSSF17_ENG_afddc4ed21_1fa227e2e937
        ASSESSMENT:     CSSF17_ENG_afddc4ed21_0_011     CSSF17_ENG_afddc4ed21:per:children      SIMPSONS_012:67-112     Lisa Simpson    SIMPSONS_012:81-94      C       NAM     C       CSSF17_ENG_afddc4ed21:1 NAM

        PREPOLICY ASSESSMENT:   CORRECT
        POSTPOLICY ASSESSMENT:  IGNORE,REDUNDANT
~~~

These fields are described here:

   FQNODEID               Fully-qualified KB node ID corresponding to the response in case of KB->SF submission (or the automatically generated node ID in case of SF submission) 
   SUBMISSION             A response line in the submission file
   TARGET_QID             Query ID of the next round query
   ASSESSMENT             Line from the assessment file that corresponds to this answer, if any
   PREPOLICY ASSESSMENT   The assessment of the response in the assessment file
   POSTPOLICY ASSESSMENT  The categorization of the response for the purpose of scoring; MOTE that the categorization of REDUNDANT responses affects only P/R/F1

### 4.6.2 AP computation debug information

AP computation debug information is printed at the end of the debug file beginning with line:

~~~
AP COMPUTATION DEBUG INFO BEGINS:
~~~

This section presents debug information for each query-and-hop separately. An example is shown below:

~~~
QUERY_ID:         CSSF17_ENG_afddc4ed21
LEVEL:            1
AP:               1.0000
NUM_GROUND_TRUTH: 4
GROUND TRUTH:
  CSSF17_ENG_afddc4ed21:1:1
  CSSF17_ENG_afddc4ed21:1:2
  CSSF17_ENG_afddc4ed21:2:1
  CSSF17_ENG_afddc4ed21:2:2
RANKING:
........
RANK NODEID CONFIDENCE MAPPED_EC V
1 CSSF17_ENG_afddc4ed21:Entity103:Entity111 0.7516 CSSF17_ENG_afddc4ed21:1:2 1.0000
2 CSSF17_ENG_afddc4ed21:Entity103:Entity110 0.6633 CSSF17_ENG_afddc4ed21:1:1 1.0000
3 CSSF17_ENG_afddc4ed21:Entity102:Entity111 0.5120 CSSF17_ENG_afddc4ed21:2:2 1.0000
4 CSSF17_ENG_afddc4ed21:Entity102:Entity110 0.5031 CSSF17_ENG_afddc4ed21:2:1 1.0000
5 CSSF17_ENG_afddc4ed21:Entity104:Entity110 0.3694 - 0.0000
6 CSSF17_ENG_afddc4ed21:Entity104:Entity111 0.3573 - 0.0000
~~~

For each query-and-hop, we provide the following:

   QUERY_ID          The query ID
   LEVEL             The hop number
   AP                AP-based score computed using the V values in list given in the corresponding RANKING section
   NUM_GROUND_TRUTH  The number of correct answers (used as the denomerator for AP computation)
   GROUND TRUTH      The list of equivalence classes assigned by LDC *1
   RANKING           The ranked list used for AP computation *2

*1: The number of equivalence classes as assigned by LDC might differ from NUM_GROUND_TRUTH (for e.g. in case of singluar valued slots when LDC found two ages of a person, in which case, NUM_GROUND_TRUTH would be set to 1)
*2: The ranked list provides a list of NODES with (1) its confidence, (2) the equivalence class which the node is aligned to (MAPPED_EC), and (3) the value V
