Last modified: 19th April 2017

# Outline
1. How to setup the *TestSuite*
2. How to validate all existing KB and SF test cases
3. How to validate an existing KB test case
4. How to validate an existing SF test case
5. How to add a new KB test case
6. How to add a new SF test case
7. List of existing test cases

# How to setup the *TestSuite*

The *TestSuite* makes use of a few source documents in order to perform certain checks. Since the source documents are protected by copyright, these documents have not been included in the repository. In order to make it work, kindly place the following files in: 

CS-TestSuite/AUX-Files/Example-Documents

NYT_ENG_20130602.0025.xml
NYT_ENG_20130603.0033.xml
NYT_ENG_20131113.0264.xml

In order to verfiy if the setup is working, run the following:

**make validate-all**
**make diff-all**

The former would validate all existing test cases and the later compares the error logs (in files with extension errlog) with original error logs (in files with extension orig_err). So if the later does not produce any difference then the setup is successfull.

# How to validate all existing KB and SF test cases

In order to validate all the existing KB and SF test cases, run the following:

**make validate-all**

# How to validate an existing KB test case

In order to validate a KB test case *TEST_CASE*, run the following command:

**make validate-kb KB=TEST_CASE**

*(Replace TEST_CASE with one of the existing KB test cases given at the end of this README file)*

The validated KB will be produced at CS-TestSuite/KB-TestSuite/TEST_CASE/TEST_CASE.tac.valid. In addition to this, the validated files for various component evaluation will be produced at the same directory. 

These output files are described below:

 | Evaluation Task | Validated File |
 | - | - |
 | KB | TEST_CASE.tac.valid |
 | EDL | TEST_CASE.edl.valid |
 | Event Nugget | TEST_CASE.eng.valid |
 | Event Argument | Inside the directory named: **event_arguments** |
 | BeST | Inside the directory named: **sentiments** |
 
None of these files will be produced in case of error(s). The error(s) or warning(s) encountered while validaing the test case can be found in TEST_CASE.errlog. Notice that for the existing test cases, the copy of error(s) encountered while validating has been placed in the file TEST_CASE.orig_err for reference. 
 
# How to validate an existing SF test case

In order to validate a SF test case *TEST_CASE*, run the following command:

**make validate-sf SF=TEST_CASE**

The validated SF would be stored in TEST_CASE.valid.ldc.tab.txt and the error log would be written in TEST_CASE.errlog.

# How to add (and validate) a new KB test case

In order to add a new KB test case NEW_TEST, follow the steps given below:

1. Create a directory CS-TestSuite/KB-TestSuite/NEW_TEST
2. Store the new test case in the file CS-TestSuite/KB-TestSuite/NEW_TEST/NEW_TEST.tac
3. Validate using: **make validate-kb KB=NEW_TEST**

**NOTE: Make sure the doclength file (at CS-TestSuite/AUX-Files/doclength.txt) contains the information about any new document you might be using in the NEW_TEST case.**

# How to add (and validate) a new SF test case

In order to add a new SF test case NEW_TEST, follow the steps given below:

1. Create a directory CS-TestSuite/SF-TestSuite/NEW_TEST
2. Store the new test case in the file CS-TestSuite/KB-TestSuite/NEW_TEST/NEW_TEST
3. Place the SF queries in the file CS-TestSuite/KB-TestSuite/NEW_TEST/NEW_TEST/sf-query.xml
4. Validate using: **make validate-sf SF=NEW_TEST**

**NOTE: Make sure the doclength file (at CS-TestSuite/AUX-Files/doclength.txt) contains the information about any new document you might be using in the NEW_TEST case.**

# List of existing test cases

### KB Test Cases

Following KB test cases are part of the *TestSuite*:

 | S# | Name |
 | - | - |
 | 1 | AMBIGUOUS_PREDICATE |
 | 2 | COLON_OMITTED |
 | 3 | DUPLICATE_ASSERTION |
 | 4 | ILLEGAL_CONFIDENCE_VALUE |
 | 5 | ILLEGAL_DOCID |
 | 6 | ILLEGAL_NODE_NAME |
 | 7 | ILLEGAL_NODE_TYPE |
 | 8 | ILLEGAL_OFFSET |
 | 9 | ILLEGAL_OFFSET_PAIR |
 | 10 | ILLEGAL_PREDICATE |
 | 11 | ILLEGAL_PREDICATE_TYPE |
 | 12 | ILLEGAL_PROVENANCE |
 | 13 | INCOMPATIBLE_NODE_NAME |
 | 14 | INCORRECT_MENTION_STRING |
 | 15 | INVERSES_IN_MULTIPLE_JUSTIFICATIONS |
 | 16 | MISSING_CANONICAL |
 | 17 | MISSING_INVERSE |
 | 18 | MISSING_RUNID |
 | 19 | MISSING_TYPEDEF |
 | 20 | MULTIPLE_CANONICAL |
 | 21 | MULTIPLE_FILLS |
 | 22 | MULTITYPED_ENTITY |
 | 23 | NO_ERRORS |
 | 24 | NO_MENTIONS |
 | 25 | PREDICATE_ALIAS |
 | 26 | REALIS_VERIFICATION |
 | 27 | STRING_USED_FOR_ENTITY |
 | 28 | SUBJECT_PREDICATE_MISMATCH |
 | 29 | SYNTAX_ERROR |
 | 30 | UNASSERTED_CANONICAL |
 | 31 | UNASSERTED_MENTION |
 | 32 | UNATTESTED_RELATION_ENTITY |
 | 33 | UNKNOWN_TYPE |
 | 34 | UNQUOTED_STRING |

### SF Test Cases

Following SF test cases are part of the *TestSuite*:

 | S# | Name |
 | - | - |
 | 1 | ILLEGAL_CONFIDENCE_VALUE |
 | 2 | ILLEGAL_DOCID |
 | 3 | ILLEGAL_OFFSET |
 | 4 | ILLEGAL_PROVENANCE |
 | 5 | ILLEGAL_VALUE_TYPE |
 | 6 | MULTIPLE_DOCIDS |
 | 7 | MULTIPLE_RUNIDS |
 | 8 | NO_ERRORS |
 | 9 | WRONG_NUM_OF_COLUMNS |
 | 10 | WRONG_QUERY |
 | 11 | WRONG_SLOT_NAME |

