#!/usr/bin/perl
use strict;
use threads;

if(scalar @ARGV != 6){
	my $script_name = $0;
	$script_name =~ s/\/(.*?\/)+//g;
	print STDERR "Usage: perl $script_name <runs-directory> <run-file-name-pattern> <output-file-postfix> <assessment-file> <queries-file> <stderr>\n\n";
	print STDERR "For eg.:\n\tperl $script_name ../data/runs/ valid.ldc.tab.txt scores.master.v1.1.txt ../data/KBP2014_English_CS_Assessments_V4.0 ../data/Queries-2014.xml 1\n";
	exit;
}

my ($runs_dir, $run_name_pattern, $output_postfix, $assessment_file, $queries_file, $stderr) = @ARGV;

$runs_dir =~ s/\/$//;

my @run_files = split("\n", `ls -l $runs_dir/*/*$run_name_pattern* | awk 'BEGIN {FS=\"[ ]+\"}{print \$9}'`); 

my @cmds;

foreach my $run_file( @run_files ){
	$run_file =~ /\/?(.*?\/)+(.*?)\.$run_name_pattern/;
	my ($run_file_dir, $run_file_name) = ($1,$2);
	my $output_file_name = $run_file_name.".".$output_postfix;
	my $output_file = "$runs_dir/$run_file_dir$output_file_name";
	push(@cmds, "perl CS-Score.pl $assessment_file $run_file $queries_file > $output_file");
	#print "--running cmd=$cmd\n";
	#`$cmd`;
}

score_wrapper(@cmds);

sub score_wrapper(){
	my @cmds = @_;
	my @threads = ();
	my $total_threads = scalar @cmds;
	my $remaining_threads = $total_threads;
	my $MAX_THREADS = 4;

	for( my $i=0; $i < $MAX_THREADS; $i++ ){
		last if( $remaining_threads == 0 );
		my $thread_num = $i;
		my $cmd = shift(@cmds);
		$threads[ $thread_num ] = threads->create( {'stack_size'=>64*65536}, \&score, $thread_num, $cmd, $stderr);
		$remaining_threads--;
	}	
	
	my $threads_done = 0;
	while( $threads_done < $total_threads ){
		#printe( "Main thread sleeping for 3 seconds. (threads_done=$threads_done)\n" );
		sleep( 1 );
		for( my $i = 0; $i < $MAX_THREADS; $i++ ){
			next if not defined $threads[ $i ];
			if( $threads[ $i ]->is_joinable() ){
				$threads_done++;
				$threads[ $i ]->join;
				last if( $remaining_threads == 0 );
				
				my $thread_num = $i;
				my $cmd = shift(@cmds);
				$threads[ $thread_num ] = threads->create( {'stack_size'=>64*65536}, \&score, $thread_num, $cmd, $stderr);
				
				$remaining_threads--;	
			}
		}
	}
}

sub score{
	my ($thread_num, $cmd, $stderr) = @_;

	printe( "Running: $cmd\n" );
	`$cmd`;
	printe( "Finished: $cmd\n" );
}

sub printe{
	my (@msgs) = @_;
	#my $time = `date`; chomp $time;
	if( $stderr == 1 ){
		foreach my $msg( @msgs ){
			if( $msg =~ /^=>/ ){ my $time = `date`; chomp $time; $msg = "At $time:\t$msg"; }
			print STDERR $msg;
		}
	}
}
