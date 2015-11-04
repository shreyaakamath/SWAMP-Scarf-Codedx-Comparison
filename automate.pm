#! /usr/bin/perl

use strict;
use Getopt::Long;

my $scarf_location; 
#= "/afs/cs.wisc.edu/u/s/h/shreyakamath/Documents/SWAMP/SWAMP_Parser_Analysis/rawToScarf/java/PMD/JSPwiki/JSPWiki-2.5.139---rhel-6.4-64---pmd---justparse/";
my $codedx_csv="../report.csv";
my $codedx_xml = "../codedx.xml";
my $diff_output = "../diff_output";
my $log_file = "../JSPWiki-2.5.139---rhel-6.4-64---pmd.log";
my $log;


parse_cmd_args();
upload_and_download();
csv_to_xml();
scarf_codedx_diff();

sub parse_cmd_args{
	my $result = GetOptions ('path=s' => \$scarf_location,'output=s' => \$diff_output,'log=s' => \$log_file);
	if(!defined($scarf_location)){
		print "ERROR Correct Usage:./automate.pl --path=scarf_file_location --output=output_file --log=log_file\n";
		exit 1;
	}
	if(!defined($log_file)){
		print "ERROR Correct Usage:./automate.pl --path=scarf_file_location --output=output_file --log=log_file\n";
		exit 1;
	}
	open($log,">",$log_file) or die ("cannot create output file $log_file");
}

sub upload_and_download{
	print $log localtime(time)." Starting upload of assessment\n";
	system("upload.sh $scarf_location");
	print $log localtime(time)." Upload to codedx complete\n";
	my $runId = $? >> 8;
	print $log localtime(time)." Run ID of assessment is $runId\n";
	print $log localtime(time)." Sleeping before downloading assessment	\n";
	sleep(10);
	print $log localtime(time)." Starting download of assessment \n";
	system("download_report.sh -o $codedx_csv $runId");
	print $log localtime(time)." Download of assessment from codedx complete\n";
}

sub csv_to_xml{
	system("csv_to_xml_codedx.pl --file_csv=$codedx_csv --output_file=$codedx_xml");
	print $log localtime(time)." Converting codedx results from csv file to xml file complete\n";
}

sub scarf_codedx_diff{
	my $scarf_file = $scarf_location."parsed_results/parsed_assessment_result.xml";
	system("diff_scarf.pl --file1=$scarf_file --file2=$codedx_xml --output=$diff_output --type=\"scarfToCodedx\" --compare=\"code,line,file\"");
	print $log localtime(time)." Scarf to codedx diff complete\n";
}

