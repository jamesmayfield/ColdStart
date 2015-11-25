# ColdStart
Scripts for the TAC Cold Start task
<br>James Mayfield
<br>Shahzad Rajput

| Name                | Description                                               |
|---------------------|-----------------------------------------------------------|
| ColdStartLib.pm     | A set of classes and functions useful across many scripts |
| *-MASTER.pl         | Scripts that do not include routines from ColdStartLib.pm |
| Include.pl          | A script to merge the appropriate code from ColdStartLib.pm into a -MASTER.pl script |

In general the -MASTER scripts can be run directly if your environment is set up to allow perl to see ColdStartLib. To allow scripts to reside in a single file with no external dependencies, Include.pl will munge together ColdStartLib with the -MASTER file to produce the appropriate script on stdout.

The following MASTER scripts are available:

| Name                     | Description                                                |
|--------------------------|------------------------------------------------------------|
| CS-GenerateQueries       | Generate first and second round CSSF queries.              |
| CS-LDC2TAC               | Convert an LDC ground truth file to CSSF submission format |
| CS-PackageOutput         | Put CSSF output files together into a valid submission     |
| CS-Pool                  | Combine CSSF runs into a single anonymized file            |
| CS-ResolveQueries        | Apply evaluation queries to a KB                           |
| CS-Score                 | Score a CSKB or CSSF run                                   |
| CS-Stats                 | Generate various statistics about queries, runs, etc.      |
| CS-ValidateKB            | Verify that a CSKB submission is well-formed               |
| CS-ValidateQueries       | Correct common problems with queries; expand multiple entry points |
| CS-ValidateSF            | Verify that a CSSF submission is well-formed               |

