#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

### DO NOT INCLUDE
use ColdStartLib;

### DO INCLUDE
##################################################################################### 
# This program converts from LDC’s original queries containing multiple entry points, 
# to multiple queries that can be distributed to CSSF teams.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.3";

print STDERR "CS-ExpandQueries.pl has been superseded by CS-ValidateQueries.pl\n";

################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Modified to obfuscate the relationships among queries
# 1.2 - Added type match checking
# 1.3 - Replaced functionality by CS-ValidateQueries.pl

1;
