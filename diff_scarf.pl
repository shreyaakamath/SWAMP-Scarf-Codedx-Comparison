#! /usr/bin/perl

use strict;
use Twig;
use Data::Dumper;
use Getopt::Long;
use Switch;

#vars for command line parsing
my $file1;
my $file2;
my $output;
my $compare;
my $type_str;
my $dupsOnly_ip;
my $elem_xml;
my $tag_elem=1;
my $type=3;
my $dup=0;
my $missing=0;
my $dupsOnly=0;
my $summary_ip=1;
my $summary=0;
my $isCsv=0;
my $isXml=0;
my $isDiff=1;
my $outputFormat="diff";
#vars for dup removal and file comparison
my $hash_csv_count;
my $hash_xml_count;
my $count_xml = 0;
my %hash_xml;
my %hash_csv;
my %hash_xml2;
my $count_dup_file1 = 0;
my $count_dup_file2 =0;	
my $fh;
my $fh_out;


parse_cmd_args();
parse_files();
print_results();

###########sub-routine to parse the command line options###################
sub parse_cmd_args {
	my $result = GetOptions ('file1=s' => \$file1,
								'file2=s' => \$file2,
								'output=s' => \$output,
								'type=s' => \$type_str,
								'compare=s' => \$compare,
								'dupsOnly=s' => \$dupsOnly_ip,
								'summary=s' => \$summary,
								'outputFormat=s' => \$outputFormat);
	if (!defined($output))
	{
					$output = "diff_out";
	}
	open($fh,"<",$file2) or die ("file not found"); 
	open($fh_out,">",$output) or die ("cannot create output file");
	
	#use the compare tag elements to decide which key to use while creating the hash 
	my @words = split/,/,$compare;
	my %hash_words = map{$_ => 1}@words;
	my $key_code = "code";
	my $key_line = "line";
	my $key_file = "file";
	if(exists $hash_words{$key_code} && exists $hash_words{$key_line} && $hash_words{$key_file}){
		$tag_elem = 1; 
	}
	elsif( exists $hash_words{$key_line} && $hash_words{$key_file}){
		$tag_elem = 2; 
	}
	
	elsif($hash_words{$key_file}){
		$tag_elem = 3; 
	}
	elsif(exists $hash_words{$key_code}){
		$tag_elem = 4; 
	}
	
	#use the type tag elements to decide which type of files are being compared 
	my $s2c = "scarfToCodedx";
	my $c2s = "codedxToScarf";
	my $c2c = "codedxToCodedx";
	my $s2s = "scarfToScarf";
	
	if($type_str eq $s2c) {
					$type=1;
	} 
	elsif($type_str eq $c2s){
					$type=2;
	}
	elsif($type_str eq $c2c){
					$type=3;
	}
	elsif($type_str eq $s2s){
					$type =3;
	}
	
	#find out if we need to print only dups or print the diff of the files 
	my $yes ="yes";
	my $no = "no";
	
	if(uc($dupsOnly_ip) eq uc($yes)){
					$dupsOnly=1;
	}
	elsif(uc($dupsOnly_ip) eq uc($no)){
		$dupsOnly=0;
	}
	#do we need to print the summary 
	if(uc($summary) eq uc($yes)){
					$summary=1;
	}
	elsif(uc($summary) eq uc($no)){
		$summary=0;
	}
	
	
	#is output expected in csv,xml,diff 
	my $csv = "csv";
	my $diff = "diff";
	my $xml = "xml";
	
		if(uc($outputFormat) eq uc($csv)){
			$isCsv=1;
			$isDiff=0;
			print "csv output\n"
		}elsif(uc($outputFormat) eq uc($diff)){
			$isDiff=1;
		}elsif(uc($outputFormat) eq uc($xml)){
			$isXml=1;
		}
	

}

###############subroutine to parse the necessary files##############################
sub parse_files{
	my $xpath = "BugInstance";  
	my $twig = new XML::Twig(TwigHandlers => {
									$xpath => \&parse_routine
									});
	$twig->parsefile($file1);
	
	my $twig2 = new XML::Twig(TwigHandlers => {
									$xpath => \&parse_routine2
									});
	$twig2->parsefile($file2);

}


####################3parse first file######################################
sub parse_routine {
				my $start_line;
				my $end_line;
					
				my ($tree,$elem) = @_;
				my $file_name = $elem->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
				$file_name = lc($file_name);
				if($type ==2){
					$file_name =~ s/(.*?)\///;
				}

				if ( $elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)
				{
								$start_line = $elem->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
				}
				else
				{
								$start_line = 'NA';
				}

				if ($elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)
				{
								$end_line = $elem->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
				}
				else
				{
								$end_line = 'NA';
				}
				my $bug_code;
				if ($elem->first_child('BugCode') != 0)
				{
								$bug_code = $elem->first_child('BugCode')->field;
								$bug_code = lc($bug_code);
				}
				my $location = $elem->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
				my $bug_id  = $elem->{'att'}->{id};
				my $bug_msg;
				if ($elem->first_child('BugMessage') != 0)
				{
								$bug_msg = $elem->first_child('BugMessage')->field;
								$bug_msg =~ s/"//g; 
												$bug_msg = lc ($bug_msg);
								$bug_msg =~ s/\s+$//;
				}
				my $tag;
				switch ($tag_elem)
				{
								case "1" {$tag = $file_name.':'.$start_line.":".$end_line.":".$bug_code}
								case "2" {$tag = $file_name.':'.$start_line.":".$end_line}
								case "3" {$tag = $file_name}
								case "4" {$tag = $bug_code}
				}
				if (!exists($hash_xml{$tag}))
				{
								$hash_xml{$tag} = {'count'=>1,'bugid'=>$bug_id, 'startline'=>$start_line, 'endline'=>$end_line, 'filename'=>$file_name,'bugcode'=>$bug_code};
				}
				else
				{
								$hash_xml{$tag}->{count} = $hash_xml{$tag}->{count}+1;
								$count_dup_file1++;
				}
				$tree->purge;

}

##########################parse second file######################################
sub parse_routine2 {	
				my $start_line_csv;
				my $end_line_csv;
				my ($tree_csv,$elem_csv) = @_;
				if ($elem_csv->first_child('BugLocations') == 0){
								next;
				}
				my $file_name_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('SourceFile')->field;
				$file_name_csv = lc($file_name_csv);
				if($type==1){
					$file_name_csv =~ s/(.*?)\///;
				}
				if ( $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine') != 0)
				{
								$start_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('StartLine')->field;
				}
				else
				{
								$start_line_csv = 'NA';
				}
				if ($elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine') != 0)
				{
								$end_line_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->first_child('EndLine')->field;
				}
				else
				{
								$end_line_csv = 'NA';
				}
				my $bug_code_csv;
				if ($elem_csv->first_child('BugCode') != 0)
				{
								$bug_code_csv = $elem_csv->first_child('BugCode')->field;
								$bug_code_csv = lc($bug_code_csv);
				}
				my $location_csv = $elem_csv->first_child('BugLocations')->first_child('Location')->{'att'}->{primary};
				my $bug_id_csv  = $elem_csv->{'att'}->{id};
				my $bug_msg_csv;
				if ($bug_msg_csv = $elem_csv->first_child('BugMessage') != 0)
				{
								$bug_msg_csv = $elem_csv->first_child('BugMessage')->field;
								$bug_msg_csv =~ s/"//g; 
												$bug_msg_csv = lc ($bug_msg_csv);
								$bug_msg_csv =~ s/\s+$//;
				}
				my $tag_csv;
				switch ($tag_elem)
				{
								case "1" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv.':'.$bug_code_csv}
								case "2" {$tag_csv = $file_name_csv.':'.$start_line_csv.':'.$end_line_csv}
								case "3" {$tag_csv = $file_name_csv}
								case "4" {$tag_csv = $bug_code_csv}
				}

				if ($hash_csv{$tag_csv} == 0)
				{
								$hash_csv{$tag_csv} = {'count'=>1,'bugid'=>$bug_id_csv, 'startline'=>$start_line_csv, 'endline'=>$end_line_csv, 'filename'=>$file_name_csv,'bugcode'=>$bug_code_csv};
								
				}
				else
				{
								$hash_csv{$tag_csv}->{count} = $hash_csv{$tag_csv}->{count}+1;
								$count_dup_file2++;
								
				}
				$tree_csv->purge;
}	

###################print the results based on command line input####################################
sub print_results {
	#get total no of bug instances in each file
	$hash_csv_count = keys %hash_csv;
	$hash_xml_count = keys %hash_xml;
		
	#do not display the details about the duplicates in each file,if user has selected to view only summary, this function does not print detailed results
	if($dupsOnly == 0){
		if($isDiff == 1 && $summary==0){
		print $fh_out "\n\tBugID\tStartLine\t\tEndLine\t\tBugCode\t\t\tFileName\n";
		}elsif($isCsv == 1 && $summary==0){
		print $fh_out "Diff,BugID,StartLine,EndLine,BugCode,FileName\n";
		}
		foreach my $elem_xml (keys %hash_xml)
		{
			if (( $hash_csv{$elem_xml}==0))
			{
				$missing++;
				if($isDiff == 1 && $summary==0){
				print $fh_out "-\t $hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t$hash_xml{$elem_xml}->{bugcode}\t\t$hash_xml{$elem_xml}->{filename}\n";
				}
				elsif($isCsv == 1 && $summary==0){
				print $fh_out "-, $hash_xml{$elem_xml}->{bugid},$hash_xml{$elem_xml}->{startline},$hash_xml{$elem_xml}->{endline},$hash_xml{$elem_xml}->{bugcode},$hash_xml{$elem_xml}->{filename}\n";	
				}
			}
			else
			{
				$dup++;
				if($isDiff == 1 && $summary==0){
				print $fh_out "+\t$hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t$hash_xml{$elem_xml}->{bugcode}\t\t$hash_xml{$elem_xml}->{filename}\n";
				}elsif($isCsv==1 && $summary==0){
				print $fh_out "+,$hash_xml{$elem_xml}->{bugid},$hash_xml{$elem_xml}->{startline},$hash_xml{$elem_xml}->{endline},$hash_xml{$elem_xml}->{bugcode},$hash_xml{$elem_xml}->{filename}\n";	
				}
			}
		}
		
		if($isDiff == 1){
			print $fh_out "\nTotal unique bug instances found in $file1 = $hash_xml_count\n";
			print $fh_out "\nTotal unique bug instances found in $file2 = $hash_csv_count\n";
			print $fh_out "\nTotal duplicate bug instances found in $file1 = $count_dup_file1\n";
			print $fh_out "\nTotal duplicate bug instances found in $file2 = $count_dup_file2\n";
			print $fh_out "\nNumber of Bug Instances present in both $file1 and $file2= $dup\n ";
			print $fh_out "\nNumber of Bug Instances present in $file1 but NOT in  $file2= $missing\n \n";
		} elsif($isCsv==1){
			print $fh_out "Total unique bug instances found in $file1,$hash_xml_count\n";
			print $fh_out "Total unique bug instances found in $file2,$hash_csv_count\n";
			print $fh_out "Total duplicate bug instances found in $file1,$count_dup_file1\n";
			print $fh_out "Total duplicate bug instances found in $file2,$count_dup_file2\n";
			print $fh_out "Number of Bug Instances present in both $file1,$file2,$dup\n ";
			print $fh_out "Number of Bug Instances present in $file1 but NOT in  $file2,$missing\n \n";
		}
	} 
	#print the details about the duplicates in each file
	else{
		#print duplicated present in file1 if present
		if($count_dup_file1>0){
			print $fh_out "Duplicates in ".$file1." :\n";
			if($isDiff == 1){
				print $fh_out "\n\tBugID\tStartLine\t\tEndLine\t\tBugCode\t\t\tFileName\n";
			}elsif($isCsv == 1){
				print $fh_out "BugID,StartLine,EndLine,BugCode,FileName\n";
			}
			foreach my $elem_xml (keys %hash_xml){
				if($hash_xml{$elem_xml}->{count}>1){
					if($isDiff == 1){
					print $fh_out "\t $hash_xml{$elem_xml}->{bugid}\t\t$hash_xml{$elem_xml}->{startline}\t\t$hash_xml{$elem_xml}->{endline}\t$hash_xml{$elem_xml}->{bugcode}\t\t$hash_xml{$elem_xml}->{filename}\n";
					}elsif($isCsv ==1){
					print $fh_out "$hash_xml{$elem_xml}->{bugid},$hash_xml{$elem_xml}->{startline},$hash_xml{$elem_xml}->{endline},$hash_xml{$elem_xml}->{bugcode},$hash_xml{$elem_xml}->{filename}\n";
					}
				}
			}
		}
		#print duplicated present in file2 if present
		if($count_dup_file2>0){
			print $fh_out "Duplicates in ".$file2." :\n";
			if($isDiff == 1){
				print $fh_out "\n\tBugID\tStartLine\t\tEndLine\t\tBugCode\t\t\tFileName\n";
			}elsif($isCsv == 1){
				print $fh_out "BugID,StartLine,EndLine,BugCode,FileName\n";
			}
			foreach my $elem_xml (keys %hash_csv){
				if($hash_csv{$elem_xml}->{count} >1){
					if($isDiff == 1){
					print $fh_out "\t $hash_csv{$elem_xml}->{bugid}\t\t$hash_csv{$elem_xml}->{startline}\t\t$hash_csv{$elem_xml}->{endline}\t$hash_csv{$elem_xml}->{bugcode}\t\t$hash_csv{$elem_xml}->{filename}\n";
					}elsif($isCsv == 1){
					print $fh_out "$hash_csv{$elem_xml}->{bugid},$hash_csv{$elem_xml}->{startline},$hash_csv{$elem_xml}->{endline},$hash_csv{$elem_xml}->{bugcode},$hash_csv{$elem_xml}->{filename}\n";	
					}
				}
			}
	
		}
	
	}	
	close ($fh) or die ("unable to close the xml file");
	close ($fh_out) or die ("unable to close the csv file");
}


