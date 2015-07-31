#!/usr/bin/perl
use strict;

my $num_args = scalar @ARGV;

if( $num_args < 2 or $num_args > 3 ){
	my $script_name = $0;
	$script_name =~ s/\/(.*?\/)+//g;
	print STDERR "Usage: perl $script_name <runs-directory> <query file> {optional hop0 assessments file}\n";
	exit;
}

my $runs_dir = $ARGV[0];
my $hop0_assessment_file;
my $queries_file = $ARGV[1];

if( $num_args == 3 ){
	$hop0_assessment_file = $ARGV[2];
}

my $relation_description_formats = <<'END_RELATION_DESCRIPTION_FORMATS';

# Type          Relation Name						    Relation Description
# ----          -------------     						-------------

########## Relation Description
GPE				births_in_city							people born in [%s] (city)
GPE				births_in_country						people born in [%s] (country)
GPE				births_in_stateorprovince				people born in [%s] (state/province)
GPE				deaths_in_city							people died in [%s] (city)
GPE				deaths_in_country						people died in [%s] (country)
GPE				deaths_in_stateorprovince				people died in [%s] (state/province)
GPE				headquarters_in_city					organizations having their headquarters in [%s] (city)
GPE				headquarters_in_country					organizations having their headquarters in [%s] (country)
GPE				headquarters_in_stateorprovince			organizations having their headquarters in [%s] (state/province)
GPE				residents_of_city						residents of [%s] (city)
GPE				residents_of_country					residents of [%s] (country)
GPE				residents_of_stateorprovince			residents of [%s] (state or province)
ORG				city_of_headquarters*					city of the headquarters of [%s] (organization)
ORG				country_of_headquarters*				country of the headquarters of [%s] (organization)
ORG				date_dissolved*							date on which [%s] (organization) was desolved
ORG				date_founded*							date on which [%s] (organization) was founded
ORG				founded_by								founders of [%s] (organization)
ORG				members									members of [%s] (organization)
ORG				number_of_employees_members*			number of employees/members of [%s] (organization)
ORG				parents									parents of [%s] (organization)
ORG				political_religious_affiliation			political/religious affiliation of [%s] (organization)
ORG				shareholders							shareholders of [%s] (organization)
ORG				stateorprovince_of_headquarters*		state/province of the headquarters of [%s] (organization)
ORG				students								students of [%s] (organization)
ORG				top_members_employees					top members/employees of [%s] (organization)
ORG				website*								website of [%s] (organization)
ORG,GPE			employees_or_members					members/employees of [%s] (organization)
ORG,GPE			member_of								member of [%s] (organization/gpe)
ORG,GPE			subsidiaries							subsidiaries of [%s] (organization/gpe)
PER				age*									age of [%s] (person)
PER				cause_of_death*							cause of death of [%s] (person)
PER				charges									charges against [%s] (person)
PER				children								children of [%s] (person)
PER				cities_of_residence						cities of residence of [%s] (person)
PER				city_of_birth*							city of birth of [%s] (person)
PER				city_of_death*							city of death of [%s] (person)
PER				countries_of_residence					countries of residence of [%s] (person)
PER				country_of_birth*						country of birth of [%s] (person)
PER				country_of_death*						country of death of [%s] (person)
PER				date_of_birth*							date of birth of [%s] (person)
PER				date_of_death*							date of death of [%s] (person)
PER				employee_or_member_of					employee/member of [%s] (person)
PER				origin									origin of [%s] (person)
PER				other_family							other_family of [%s] (person)
PER				parents									parents of [%s] (person)
PER				religion*								religion of [%s] (person)
PER				schools_attended						schools attended by [%s] (person)
PER				siblings								siblings of [%s] (person)
PER				spouse									spouse of [%s] (person)
PER				stateorprovince_of_birth*				state/province of birth of [%s] (person)
PER				stateorprovince_of_death*				state/province of death of [%s] (person)
PER				statesorprovinces_of_residence			states/provinces of residence of [%s] (person)
PER				title									title of [%s] (person)
PER				top_member_employee_of					top member/employee of [%s] (person)
PER,ORG			alternate_names							alternate names of [%s] (person/organization)
PER,ORG,GPE		holds_shares_in							organizations in which [%s] (person/organization/gpe) holds share in. 
PER,ORG,GPE		organizations_founded					organizations founded by [%s] (person/organization/gpe)

END_RELATION_DESCRIPTION_FORMATS

my %relations;

foreach (grep {!/^\s*#/} split(/\n/, lc $relation_description_formats)) {
	my $line = $_;
	$line =~ s/^\s+//g;
	$line =~ s/[^[:print:]]+/ /g;
	
	#print "$line\n";
	while( $line =~ /(.*?)\s+(.*?)\s+(.*?)$/g ){
		my ($enttype, $relation_name, $desc_format) = ($1, $2, $3);
		my $type = 'multiple';
		#print "--$enttype--$relation_name--$desc_format\n";
		if( $relation_name =~ /\*$/ ){
			$type = 'single';
		}
		$relation_name =~ s/\*$//;
		$relations{ $relation_name } = {TYPE=>$type, FORMAT=>$desc_format};
	}
}

## Read queries
print STDERR "--reading queries file: $queries_file\n";
open(FILE, $queries_file);
my $query_file_text = join('',<FILE>);
close(FILE);

## populate %queries
my %queries;
while( $query_file_text =~ m/<query id="(CS14_ENG_\d\d\d.*?)">(.*?)<\/query>/gs ){
	my ($queryid, $data) = ($1, $2);
	while($data =~ /<(.*?)>(.*?)<\/(.*?)>/g){
		my ($tag_open, $tag_value, $tag_close) = ($1, $2, $3);
		exit if $tag_open ne $tag_close;
		$queries{ $queryid }{ TAGS }{ $tag_open } = $tag_value;
	}
}

## prepare query descriptions
## This is only used for summarizing the query
foreach my $queryid( sort keys %queries ){
	my $hop = ($queryid =~/ENG_\d\d\d_/) ? 1 : 0;
	#print "$queryid\t\t\t$hop\n";
	#next;
	my $base_queryid = substr($queryid,0,12);
	my $value = $queries{ $queryid }{ TAGS }{ "name" };
	my $docid = $queries{ $queryid }{ TAGS }{ "docid"};
	my $beg = $queries{ $queryid }{ TAGS }{ "beg" };
	my $end = $queries{ $queryid }{ TAGS }{ "end" };
	my $slot = $queries{ $queryid }{ TAGS }{ "slot" };
	my $slot1 = $queries{ $queryid }{ TAGS }{ "slot1" };
	my ($enttype, $relation_name) = split(":", $slot);
	my $value_provenance_string = "$docid:$beg-$end";
	$queries{ $queryid }{ HOP } = $hop;
	#print "$queryid--------$queries{ $queryid }{ DESCRIPTION }\n";
}

## process hop1 queries
my %lookup; 
foreach my $queryid( keys %queries ){
	my $hop = $queries{ $queryid }{ HOP };
	if( $hop == 1){
		my $hop1_queryid = $queryid;
		my $base_queryid = substr($hop1_queryid,0,12);
		my $value = $queries{ $hop1_queryid }{ TAGS }{ "name" };
		my $docid = $queries{ $hop1_queryid }{ TAGS }{ "docid"};
		my $beg = $queries{ $hop1_queryid }{ TAGS }{ "beg" };
		my $end = $queries{ $hop1_queryid }{ TAGS }{ "end" };
		my $value_provenance_string = "$docid:$beg-$end";
		my $hop0_query_value_provenance = "$base_queryid:$value:$value_provenance_string";
		$lookup{ HOP0QRYVALPRO_TO_HOP1QUERYID }{ $hop0_query_value_provenance } = $hop1_queryid;
		$lookup{ HOP1QUERYID_TO_HOP0QRYVALPRO }{ $hop1_queryid } = $hop0_query_value_provenance;
	}
}

my %pool;

if( $num_args == 2 ){

	#### create hop0 pool

	## Read hop0 answers from all the files and load data
	my @list_of_files = <$runs_dir/*valid*>;
	
	foreach my $file( @list_of_files ){
		print STDERR "--reading file=$file\n";
		
		open( FILE, $file );
		while( my $line = <FILE> ){
			chomp $line;
			my ($queryid, $enttype_slot, $run_name, $relation_prov, $filler_string, $filler_prov, $confidence) = split("\t", $line);
			my $hop = $queries{ $queryid }{ HOP };
			if( $hop == 0 ){
				my $answer = "$relation_prov\t$filler_string\t$filler_prov";
				$pool{ $queryid }{ $enttype_slot }{ $answer }{ $run_name }++;
			}
		}
		close( FILE );
	}
	
	## Print the pool	
	foreach my $queryid( sort keys %pool ){
		foreach my $enttype_slot( sort keys %{ $pool{ $queryid } } ){
			foreach my $answer( sort keys %{ $pool{ $queryid }{ $enttype_slot } } ){
				print join("\t", ($queryid, $enttype_slot, "Pool", $answer, "1.0") ), "\n";
			}
		}
	}
	
}
else{
	#### create hop1 pool
	
	## Load hop0 assessments
	my %answers;
	print STDERR "--reading assessment file: ", $hop0_assessment_file, "\n";
	open( FILE, $hop0_assessment_file );
	while(<FILE>){
		chomp;
		my @elements = split(/\t/);
		my ($query_enttype_slot, $relation_prov, $value, $value_prov, $value_assessment, $relation_assessment, $equivalence_class) = map {$elements[$_]} (1..7);
		my ($queryid, $enttype, $slot) = split(":", $query_enttype_slot);
		my $hop = $queries{ $queryid }{ HOP };
		$equivalence_class =~ s/[^[:print:]]+//g;
		next if( $hop == 1);
		#next if( $equivalence_class eq "0" );
		$equivalence_class = "$queryid:1" if ($equivalence_class ne "0" && $relations{ $slot }{ TYPE } eq 'single' );
		my $query_value_provenance = "$queryid:$value:$value_prov";
		$answers{ $query_value_provenance } = { VALUE_ASSESSMENT => $value_assessment, REL_ASSESSMENT => $relation_assessment, EQCLASS => $equivalence_class };
	}
	close(FILE);
		
	## Read hop1 answers from all the files and load data
	my @list_of_files = <$runs_dir/*valid*>;
	
	foreach my $file( @list_of_files ){
		print STDERR "--reading file=$file\n";
		
		open( FILE, $file );
		while( my $line = <FILE> ){
			chomp $line;
			my ($queryid, $enttype_slot, $run_name, $relation_prov, $filler_string, $filler_prov, $confidence) = split("\t", $line);
			my $hop = $queries{ $queryid }{ HOP };
			if( $hop == 1 ){
				my $base_queryid = substr($queryid, 0, 12);
				my $hop0_query_value_provenance = $lookup{ HOP1QUERYID_TO_HOP0QRYVALPRO }{ $queryid };
				my $hop0_equivalence_class = $answers{ $hop0_query_value_provenance }{ EQCLASS };
				next if( $hop0_equivalence_class eq "0" );
				my $corrected_hop1_pool_queryid = $hop0_equivalence_class;
				#if( $corrected_hop1_pool_queryid eq "" ){
				#	print "$line\n"; 
				#	getc();
				#}
				my $answer = "$relation_prov\t$filler_string\t$filler_prov";
				$pool{ $corrected_hop1_pool_queryid }{ $enttype_slot }{ $answer }{ $run_name }++;
			}
		}
		close( FILE );
	}
	
	## Print the pool	
	foreach my $queryid( sort keys %pool ){
		#print "--queryid=--$queryid--\n"; next;
		foreach my $enttype_slot( sort keys %{ $pool{ $queryid } } ){
			foreach my $answer( sort keys %{ $pool{ $queryid }{ $enttype_slot } } ){
				print join("\t", ($queryid, $enttype_slot, "Pool", $answer, "1.0") ), "\n";
			}
		}
	}	
	
}
