#!/usr/bin/perl -w

use strict;
use XML::SAX::Machines qw( Pipeline );
use XML::SAX::Base;
use Date::Calc qw(:all);

my $inputFile = "nba_listings.xml";
$inputFile = $ARGV[0] if($ARGV[0]);

# Length of all games (in minutes). All games will have their end time altered to match this length.
our $gameMins =  150; #2.5 hours

# Maps startTime+subtitle -> list of channels
our %gameChannels;

# Maps startTime+chan+subtitle -> 1 if game is on an HD channel
our %hdGames;

our ($currentElement,$start,$channel,$title,$subtitle,$desc,$categories);

# Pass #1, building channel lists for each game
Pipeline(
  "XML::Filter::BufferText",
  "Pass1"
)->parse_file($inputFile);


# Pass #2, altering data
our $pipe = Pipeline(
  "XML::Filter::BufferText",
  "Pass2"
  , \*STDOUT 
);
#our $gen = Pipeline(XML::Filter::BufferText,{Handler => $pipe});
$pipe->parse_file($inputFile);


# Pass 1 handler, collects game information
package Pass1;
use base qw(XML::SAX::Base);

sub start_element {
  my $self = shift;
  my $element = shift;
  
  $currentElement = $element->{LocalName};
  #print "start: $currentElement\n";
  my %attrs = %{$element->{Attributes}};
  
  if($currentElement eq "programme") { 
		$start=$channel=$title=$subtitle=$desc=$categories = "";
  	$start = $attrs{"{}start"}->{Value};
  	$channel = $attrs{"{}channel"}->{Value};  	  	
  }
  
  $self->SUPER::start_element($element); 
}

sub characters {
  my $self = shift;
  my $element = shift;
	my $data = $element->{Data};
	
	if($data !~ "") {
		$title = $data if $currentElement eq "title";
		$subtitle = $data if $currentElement eq "sub-title";
		#print "subtitle set to '$subtitle'\n" if $currentElement eq "sub-title";
		$desc = $data if $currentElement eq "desc";
		$categories .= $data if $currentElement eq "category";
	}
	
	#print "data: $data\n";	
	$self->SUPER::characters($element); 
}

sub end_element {
  my $self = shift;
  my $element = shift;
  
  #print "end: $element->{LocalName}\n";
  if($element->{LocalName} eq "programme") {
  	my $gameId=$start . $subtitle;
  	#if($desc =~ /LEAGUE PASS HD/) {
  	if($channel =~ /-/) { # If channel contains a dash, it's HD
	  	# Add game to HD list 
	  	my $progId = $start . $channel . $subtitle;
 			$hdGames{$progId}=1;
 			
 			#print "gameId: $gameId\n";
	  	if (! $gameChannels{$gameId}) {
	  		$gameChannels{$gameId} = [];
	  	}
	  	
	 		my @channels = @{$gameChannels{$gameId}};
	 		#print "adding channel $channel to existing list of size " . @channels . "\n"; 		
	  	push(@channels,$channel);
	  	$gameChannels{$gameId} = \@channels;	  	
	  } 
  	#print "start=$start, channel=$channel\n";
  	#print "title=$title, subtitle=$subtitle\n";
  	#print "desc=$desc\n";
  	#print "----------------\n";
  	
  	# Clear program data variables;
  	($start,$channel,$title,$subtitle,$desc) = "";
  }  
 	$currentElement = "";

  $self->SUPER::end_element($element); 
}

# Pass 2 handler, modifies output
package Pass2;
use base qw(XML::SAX::Base);

sub new {
  my $class = shift;
  my %options = @_;
  #print Data::Dumper->Dump([\%options]);
  return bless \%options, $class;
}

sub start_element {
  my $self = shift;
  my $element = shift;
  
  $currentElement = $element->{LocalName};
  #print "start: $currentElement\n";
  my %attrs = %{$element->{Attributes}};
  
  if($currentElement eq "programme") { 
		$start=$channel=$title=$subtitle=$desc = "";
  	$start = $attrs{"{}start"}->{Value};
  	$channel = $attrs{"{}channel"}->{Value};  	
  	
		# Alter end time 
		my $stopOrig = $attrs{"{}stop"}->{Value}; 
		my ($y, $m, $d, $h, $min, $s) = $start =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/;
		#print "orig: " . $_;
		# Add the specified number of hours and minutes to the start time
		# This seems to be somewhat off (11 mins longer than I expected)
		my ($ey, $em, $ed, $eh, $emin, $es) = Date::Calc::Add_Delta_DHMS($y, $m, $d, $h, $m, $s, 0, 0, $gameMins, 0);
		my $newEndTs = sprintf("%04d%02d%02d%02d%02d%02d", $ey, $em, $ed, $eh, $emin, $es);
		my %attrs = %{$element->{Attributes}};
		my $newStop = $stopOrig;
		$newStop =~ s/\d+(.*)/$newEndTs$1/;
  	$attrs{"{}stop"}->{Value} = $newStop;
  	
  }
  
  $self->SUPER::start_element($element); 
}

sub characters {
  my $self = shift;
  my $element = shift;
	my $data = $element->{Data};
	#print "data: $data\n";	
	
	if($data !~ "") {
		$title = $data if $currentElement eq "title";
		$desc = $data if $currentElement eq "desc";
		if($currentElement =~ /sub-title/) {			
			$subtitle = $data;
			# Check if this game is in HD and on multiple channels
	  	my $gameId=$start . $subtitle;
	  	my $programId = $start . $channel  . $subtitle;
			my $newSubtitle = $subtitle;
			$newSubtitle =~ s/^\s+|\s+$//g; # Strip whitespace
	  	if($gameChannels{$gameId} && $hdGames{$programId}) {
				my @channels = @{$gameChannels{$gameId}};
				if (@channels > 1) {
					if(@channels > 2) {
						print("<!-- WARNING: Game is on more than 2 channels. This is not expected -->\n");
					}
					# Alter subtitle to indicate (with an asterisk) home team vs visiting team's coverage.
					# Visiting team is on the lower channel, home team is on the higher channel
					my @sortedChans = sort(@channels);
					if($channel eq $sortedChans[0]) {
						$newSubtitle =~ s/(.*)/*$1/;
					} else {
						$newSubtitle =~ s/(.*) at (.*)/$1 at *$2/;
					}
				}
			}
			$element->{Data} = $newSubtitle;
		}
	}
	
	$self->SUPER::characters($element); 	
}

sub end_element {
  my $self = shift;
  my $element = shift;
  
  my $elemName = $element->{LocalName}; 
  
	if($elemName =~ /programme/) {		  	
	  # Clear program data variables;
	  ($start,$channel,$title,$subtitle,$desc) = "";    
	}
 	$currentElement = "";

  $self->SUPER::end_element($element); 
}

