#! /usr/bin/perl
use strict;
use bugInstance;
use XML::Twig;
use Getopt::Long;
use XML::Writer;
use IO;

my $file_csv;
my $tool_version = '0.0.0.0';
my $uuid = '1234-5678-4321-8765';
my $build_id = 'xxxxxxxx';
my $output_file;
my $result = GetOptions('file_csv=s' => \$file_csv,
			'output_file=s' => \$output_file,
			'tool_version=s' => \$tool_version,
			'uuid=s' => \$uuid,
			'build_id=s' => \$build_id);

if (!defined($output_file))
{
	$output_file = $file_csv."_output.xml";
}
open (my $output, ">",$output_file);
my $writer = new XML::Writer(OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2 );
$writer->xmlDecl('UTF-8');

open(my $fd,"<",$file_csv) or die ("file not found");

my %hash_csv;
my @csv_array;
my $tool;
while (<$fd>)
{
	my $csv_line  = $_;
	chomp ($csv_line);
        @csv_array = split('\",\"',$csv_line);
	if (($#csv_array != 8) | ($csv_array[0] =~/ID/))
	{
		next;
	}
        s/\\"//g for @csv_array;
        s/"//g for @csv_array;
	my $bugId = $csv_array[0];
	my $severity = $csv_array[1];
	my $status = $csv_array[2];
	my $cwe = $csv_array[3];
	   $tool = $csv_array[4];
	my $bug_code = $csv_array[5];
	my $rule = $csv_array[6];
	my @file_path = split(':',$csv_array[7]);
	my @line_num  = split('\-',$file_path[1]);
 	my $start_line;
	my $end_line;
	if ($#line_num == 1)
	{
		$start_line = $line_num[0];
		$end_line  = $line_num[1];
	}
	else
	{
		$start_line = $line_num[0];
		$end_line = $line_num[0];
	}
	my $bug_msg = $csv_array[8];
	my $bugObject = new bugInstance($bugId);
	$hash_csv{$bugId}=$bugObject;
	
	$bugObject->setBugLocation(1,"",$file_path[0],$start_line,$end_line,-1,-1,"",'true','true');
	$bugObject->setBugMessage($bug_msg);
	$bugObject->setBugSeverity($severity);
	$bugObject->setBugCode($bug_code);

}
$writer->startTag('AnalyzerReport' ,'tool_name' => "$tool", 'tool_version' => "$tool_version", 'uuid'=> "$uuid" );
foreach my $object (sort {$a<=>$b} keys %hash_csv)
{
	$hash_csv{$object}-> printXML($writer,$file_csv,$build_id)
}
$writer->endTag();
$writer->end();
$output->close(); 
