#!/usr/bin/perl
package bugInstance;

#use strict;

use bugLocation;
use bugMethod;

sub new
{
	my $class=shift;
	my $self= {
			_bugId=>shift
		  };
        #my %_bugLocationHash;
        bless $self,$class;
        return $self;
}

sub setBugMessage
{
	my ($self,$bugMessage)=@_;
	$self->{_bugMessage}=$bugMessage if defined ($bugMessage);
        return $self->{_bugMessage};
}


sub setBugLocation_old
{
	my ($self,$bugLocation)=@_;
	$self->{_bugLocation}=$bugLocation if defined ($bugLocation);
        return $self->{_bugLocation};
}

sub setBugLocation
{
	my ($self,$bugLocationId,$bugClassname,$SourceFile,$startLineNo,$endLineNo,$beginColumn,$endColumn,$bugMessage,$primary,$resolvedFlag)=@_;
	my $locationObject;
	if ( $resolvedFlag eq 'true' or $startLineNo ne "")
	{
        	$locationObject = new bugLocation($bugLocationId,$bugClassname,$SourceFile,$startLineNo,$endLineNo,$beginColumn,$endColumn,$bugMessage,$primary);
	}
	else
	{       
        	$locationObject = new bugLocation($bugLocationId,$bugClassname,$self->{_classSourceFile},$self->{_classStartLine},$self->{_classEndLine},$beginColumn,$endColumn,$self->{_classMessage},$primary);
	}	
	$self->{_bugLocationHash}{$bugLocationId}=$locationObject;
}

sub setBugMethod
{
	my ($self,$methodId,$className,$methodName,$primary)=@_;
        my $methodObject = new bugMethod($methodId,$methodName,$className,$primary);
        $self->{_bugMethodHash}{$methodId}=$methodObject;
        #print $self->{_bugMethodHash}{$methodId}, "\n";
}

sub setSourceFile
{
        my ($self,$sourceFile)=@_;
        $self->{_sourceFile}=$sourceFile if defined ($sourceFile);
        return $self->{_sourceFile};
}

sub setClassName
{
        my ($self,$className)=@_;
        $self->{_className}=$className if defined ($className);
        return $self->{_className};
}

sub setClassAttribs
{
	my($self,$classname,$sourcefile,$start,$end,$classMessage) = @_;
	#print $sourcefile, "\n";
        $self->{_classSourceFile}=$sourcefile if defined ($sourcefile);
        $self->{_className}=$classname if defined ($classname);
        $self->{_classStartLine}=$start if defined ($start);
        $self->{_classEndLine}=$end if defined ($end);
	$self->{_classMessage}=$classMessage if defined ($classMessage);
}

sub setBugSeverity
{
        my ($self,$bugSeverity)=@_;
        $self->{_bugSeverity}=$bugSeverity if defined ($bugSeverity);
        return $self->{_bugSeverity};
}

sub setBugRank
{
        my ($self,$bugRank)=@_;
        $self->{_bugRank}=$bugRank if defined ($bugRank);
        return $self->{_bugRank};
}

sub setCweId
{
        my ($self,$cweId)=@_;
        $self->{_cweId}=$cweId if defined ($cweId);
        return $self->{_cweId};
}

sub setBugGroup
{
       my($self,$group)=@_;
       $self->{_bugGroup}=$group if defined ($group);
       return $self->{_bugGroup};
}

sub setBugCode
{
       my($self,$code)=@_;
       $self->{_bugCode}=$code if defined ($code);
       return $self->{_bugCode};
}

sub setBugSuggestion
{
       my($self,$suggestion)=@_;
       $self->{_bugSuggestion}=$suggestion if defined ($suggestion);
       return $self->{_bugSuggestion};
}

sub setBugPath
{
        my ($self,$bugPath)=@_;
        $self->{_bugPath}=$bugPath if defined ($bugPath);
        return $self->{_bugPath};
}



sub setBugLine
{
        my ($self,$bugLineStart,$bugLineEnd)=@_;
        $self->{_bugLineStart}=$bugLineStart if defined ($bugLineStart);
        $self->{_bugLineEnd}=$bugLineEnd if defined ($bugLineEnd);
}

sub printBugId
{
	my($self)=@_;
	return $self->{_bugId}
}

sub printBugInstance
{
      my ($self)=@_;
      my $locn;
      foreach $locn (keys %{$self->{_bugLocationHash}})
      {
          print "Location : ";
          print $self->{_bugLocationHash}{$locn}->printBugLocation(), "\n";
      }
      my $method;
      #print $self->{_bugMethodHash}{1}->printBugMethod(),"\n";
      foreach $method (keys %{$self->{_bugMethodHash}})
      {
          print "Method : ";
          print $self->{_bugMethodHash}{$method}->printBugMethod(), "\n";
      }
      return $self->{_bugId} . " :: ". $self->{_bugMessage} . " :: " . $self->{_bugSeverity} . " :: " . $self->{_bugRank} . " :: " . $self->{_bugPath} . " :: " . $self->{_cweId} . " :: " . $self->{_bugSuggestion} . " :: " . $self->{_bugGroup};
}

sub printXML_sate
{
	my($self,$writer)=@_;
#  if(keys %{$self->{_bugLocationHash}} > 0)
#  {
        $writer->startTag('weakness', 'id'=>$self->{_bugId});
        if (defined $self->{_cweId})
        {
          $writer->startTag('name', 'cweid'=>$self->{_cweId});
        } else {
          $writer->startTag('name');
	}
        $writer->characters($self->{_bugGroup});
        $writer->endTag();  #name end tag
        my $locn;
        foreach $locn (sort{$a <=> $b} keys %{$self->{_bugLocationHash}})
        {
#                print $self->{_classStartLine},$self->{_classEndLine},"\n";
          	$self->{_bugLocationHash}{$locn}->printXML($writer,$self->{_classStartLine},$self->{_classEndLine});
        }
        $writer->emptyTag('grade', 'severity' => $self->{_bugSeverity});
#        $writer->endTag(); #grade end tag
        $writer->startTag('output');
        $writer->startTag('textoutput');
        $writer->characters($self->{_bugMessage});
        $writer->endTag(); #textoutput end tag
        $writer->endTag(); #output end tag
        $writer->endTag(); #weakness end tag
#   }
}

sub printXML
{
	my($self,$writer,$report_file,$build_id)=@_;
        $writer->startTag('BugInstance', 'id'=>$self->{_bugId});
        
        if (defined $self->{_className})
	{
		$writer->startTag('ClassName');
		$writer->characters($self->{_className});
		$writer->endTag();
	}
          
        $writer->startTag('Methods');
	my $method;
	foreach $method (sort{$a <=> $b} keys %{$self->{_bugMethodHash}})
	{
		$self->{_bugMethodHash}{$method}->printXML($writer);
	}
        $writer->endTag();
	      
        $writer->startTag('BugLocations');
        my $locn;
        foreach $locn (sort{$a <=> $b} keys %{$self->{_bugLocationHash}})
        {
          	$self->{_bugLocationHash}{$locn}->printXML($writer,$self->{_classStartLine},$self->{_classEndLine});
        }
        $writer->endTag();

        if (defined $self->{_cweId})
        {
          $writer->startTag('CweId');
          $writer->characters($self->{_cweId});
	  $writer->endTag();
	}
	
        if (defined $self->{_bugGroup})
        {
          $writer->startTag('BugGroup');
          $writer->characters($self->{_bugGroup});
	  $writer->endTag();
	}
        
        if (defined $self->{_bugCode})
        {
          $writer->startTag('BugCode');
          $writer->characters($self->{_bugCode});
	  $writer->endTag();
	}

	if (defined $self->{_bugRank})
        {
          $writer->startTag('BugRank');
          $writer->characters($self->{_bugRank});
	  $writer->endTag();
	}

	if (defined $self->{_bugSeverity})
        {
          $writer->startTag('BugSeverity');
          $writer->characters($self->{_bugSeverity});
	  $writer->endTag();
	}

	
	if (defined $self->{_bugMessage})
        {
          $writer->startTag('BugMessage');
          $writer->characters($self->{_bugMessage});
	  $writer->endTag();
	}

	if (defined $self->{_bugSuggestion})
        {
          $writer->startTag('ResolutionSuggestion');
          $writer->characters($self->{_bugSuggestion});
	  $writer->endTag();
	}

	$writer->startTag('BugTrace');
	$writer->startTag('BuildId');
	$writer->characters($build_id);
	$writer->endTag();
	$writer->startTag('AssessmentReportFile');
	$writer->characters($report_file);
	$writer->endTag();
        if (defined $self->{_bugPath})
	{
		$writer->startTag('InstanceLocation');
		$writer->startTag('Xpath');
		$writer->characters($self->{_bugPath});
		$writer->endTag();
		$writer->endTag();
	}
        if (defined $self->{_bugLineStart} and defined $self->{_bugLineEnd})
	{
		$writer->startTag('InstanceLocation');
		$writer->startTag('LineNum');
		$writer->startTag('Start');
		$writer->characters($self->{_bugLineStart});
		$writer->endTag();
		$writer->startTag('End');
		$writer->characters($self->{_bugLineEnd});
		$writer->endTag();
		$writer->endTag();
		$writer->endTag();
	}
	$writer->endTag();
        
	
        $writer->endTag(); 
}

1;
