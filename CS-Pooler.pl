#!/usr/bin/perl
use strict;

if(scalar @ARGV != 4){
	print "USAGE: perl $0 hop batch-dir batch query\n\n";
	print "\thop -- 0 or 1 representing the hop for which the pool is being created\n";
	print "\tbatch-dir -- the directory containing batches\n";
	print "\tbatch -- batchid of the batch for which the pool is being created\n";
	print "\tquery -- queryid of the query for which the pool is being created\n";
	exit;
}

my ($hop, $batch_dir, $batch, $query) = @ARGV;

my $cmd;

if($hop == 0) {
	$cmd .= "perl CS-Pool-MASTER.pl ";
	$cmd .= "-output_file $batch_dir/$batch/$query/hop0_pool.csldc ";
	$cmd .= "$batch_dir/$batch/$query/tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries.xml ";
	$cmd .= "$batch_dir/$batch/$query/queries.index "; 
	$cmd .= "$batch_dir/$batch/$query/runs/";
	
	print "--running command: $cmd\n";
	`$cmd`;	
}
elsif($hop==1) {
	
	$cmd = "perl CS-ExpandAssessments-MASTER.pl ";
	$cmd .= "-output_file $batch_dir/$batch/$query/hop0_pool.cssf.assessed ";
	$cmd .= "-hop1_query_file $batch_dir/$batch/$query/hop1_queries.xml ";
	$cmd .= "$batch_dir/$batch/$query/tac_kbp_2015_english_cold_start_evaluation_queries.xml ";
	$cmd .= "$batch_dir/$batch/$query/tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries.xml ";
	$cmd .= "$batch_dir/$batch/$query/hop0_pool.csldc.assessed ";
	$cmd .= "$batch_dir/$batch/$query/queries.index";
	
	print "--running command: $cmd\n\n";
	`$cmd`;	
	
	$cmd = "perl CS-Pool-MASTER.pl ";
	$cmd .= "-output_dir $batch_dir/$batch/$query/ ";
	$cmd .= "-hop0_assessment_file $batch_dir/$batch/$query/hop0_pool.cssf.assessed ";
	$cmd .= "$batch_dir/$batch/$query/tac_kbp_2015_english_cold_start_slot_filling_evaluation_queries.xml ";
	$cmd .= "$batch_dir/$batch/$query/queries.index ";
	$cmd .= "$batch_dir/$batch/$query/runs/";	

	print "--running command: $cmd\n\n";
	`$cmd`;
}
