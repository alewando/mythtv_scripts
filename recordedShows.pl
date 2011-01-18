#!/usr/bin/perl


use DBI();

my $dsn = "DBI:mysql:database=mythconverg";
my $user = "mythtv";
my $pw = "mythtv";
my $hours = 24;

my $dbh = DBI->connect($dsn,$user,$pw) || die;
print "Programs recorded in the last $hours hours:\n\n";

# Retreive recently recorded shows
my $sth = $dbh->prepare("select title, subtitle, description, starttime, CONCAT(hour(endtime-starttime), ':', LPAD(minute(endtime-starttime),2,'0')) length, channum, callsign, originalairdate, previouslyshown from recorded r, channel c where r.chanid = c.chanid AND DATE_SUB(CURDATE(),INTERVAL $hours HOUR) <= starttime order by starttime asc;");
$sth->execute() || die $sth->errstr;
my $rowCount = 0;
while(my @row = $sth->fetchrow_array) {
 my ($title,$subtitle,$description,$starttime,$length,$channum,$callsign,$originalairdate,$previouslyshown) = @row;
 ++$rowCount;
 $length = "Unknown" if !$length;

 my $titleStr = "$title";
 print "-------------------------------------------------------------------\n";
 $titleStr .= " - $subtitle" if $subtitle; 
 print "$titleStr\n";
 print $callsign . "[$channum], Length $length, Start $starttime";
 print ", Original Air Date $originalairdate" if $previouslyshown == 1;
 print "\n";
 print "$description\n" if $description;
}
$sth->finish();
if($rowCount > 0) {
 print "-------------------------------------------------------------------\n\n";
 print "$rowCount recorded programs\n";
} else {
 print "No programs have been recorded.\n";
}

$dbh->disconnect();

