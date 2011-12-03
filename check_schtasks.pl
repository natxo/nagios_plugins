#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  schtasks.pl
#
#        USAGE:  ./schtasks.pl
#
#  DESCRIPTION: nagios plugin to check if the scheduled tasks have run fine
#               The script parses the output of schtasks.exe
#
#      OPTIONS:  ---
# REQUIREMENTS:  Text::CSV_XS must be installed
#         BUGS:  plenty, but not yet found
#        NOTES:  ---
#       AUTHOR:  nasenjo@asenjo.nl
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  06-10-2010 13:47:51
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Text::CSV_XS;

# variables
my ( $version, $revision, $help, %lastresult_of, $checknow, %exclusions,
    %lastresult_excl );
my %ERRORS = (
    'OK'        => 0,
    'WARNING'   => 1,
    'CRITICAL'  => 2,
    'UNKNOWN'   => 3,
    'DEPENDENT' => 4,
);

$version = '1.1';

Getopt::Long::Configure( "no_ignore_case", "bundling" );
GetOptions(
    'c|checknow'  => \$checknow,
    'h|help|?'    => \$help,
    'V|version'   => \$revision,
    'e|exclude=s%' => sub{ push ( @{$exclusions{$_[1]}}, $_[2] ) },
);

# get version info if requested and exit
if ($revision) {
    print "$0 version: $version\n";
    exit $ERRORS{OK};
}
pod2usage( -verbose => 2, -noperldoc => 1, ) if $help;

pod2usage( -verbose => 1, -noperldoc => 1, ) unless $checknow;

#if ( $^O ne "MSWin32" ) {
#    print "Sorry, this is a MS Windows(TM) check, run it in a MS Windows(TM) host\n";
#    exit $ERRORS{UNKNOWN};
#}

# run schtaks, keep output in JOBS memory handle
# switches for schtasks.exe:
# /query: get the list of scheduled jobs
# /fo csv: dump the list as in csv format
# /v: verbose
# open (JOBS, "schtasks /query /fo csv /v |") or die "couldn't exec schtasks: $!\n";

# create a Text::CSV_XS object
my $csv = Text::CSV_XS->new();

# parse JOBS memory handle. The output is a csv file. The second column ($columns[1] is "Taskname",
# the 7th $columns[6] is "Last Result". I only need the values of "Last Result" which are NOT 0 (0 is good, it means it ran well).
# Because in windows 2008 the task scheduler has been revamped, there are a lot of new scheduled jobs that are not important, so I
# filter them in the next if statements

while ( my $line = <DATA> ) {
    chomp $line;
    last if $line =~ /^INFO: There are no scheduled tasks.*$/;

    if ( $csv->parse($line) ) {
        my @columns = $csv->fields();

        # Skip lines

        # skip the header
        next if $columns[1] eq "TaskName";

        # skip if next run time is 'disabled'
        next if $columns[2] eq "Disabled"; 

        # skip if status column is 'disabled'
        next if $columns[3] eq "Disabled"; 

        # skip if the task is running now
        next if $columns[3] eq "Running";  

        # skip if last run time is empty
        next if $columns[5] eq "N/A";    

        # skip if 19th colum is 'At logon time"
        next if $columns[18] eq "At logon time";    

        # process the cli exclussions now
        # These are stored in a hash containing array references as values, so
        # first we check the value is an array ref, then we skip the line if
        # the exclusion matches with $columns[1] and $columns[6]. Thanks to
        # perlmonk Eliya for helping me out with this: http://www.perlmonks.org/?node_id=941495
        if ( $columns[6] != 0 ) {
            if ( ref ( my $excl = $exclusions{$columns[1]} ) eq "ARRAY") {
                next if grep $_ == $columns[6], @$excl;
                }
            }

        # if last result is other than 0, save taskname and last result
        # in the %lastresult_of
        if ( $columns[6] != 0 ) {
            $lastresult_of{ $columns[1] } = $columns[6];
        }
    }
}

# if the %lastresult_of is empty, this will be zero
if ( scalar keys %lastresult_of == 0 ) {
    print "0K: All scheduled tasks seem to have run fine\n";
    exit $ERRORS{OK};
}
else {
    while ( my ( $key, $value ) = each(%lastresult_of) ) {
        print "WARNING: scheduled task [$key] finished with error [$value]\n";
    }
    exit $ERRORS{WARNING};
}

=head1 NAME

check_schtasks

=head1 SYNOPSIS

check_schtasks -c [-e name_scheduled_job=exitvalue]

=head1 DESCRIPTION

Nagios plugin to check the status of Windows scheduled tasks.

This plugin *must* be run in a Windows hosts. Check it from NRPE.

The plugin requires Perl in the Windows hosts with the Text::CSV_XS
module. You can install this easily from activestate.com

The way the plugin works is running schtasks.exe /query /fo csv /v
and parsing its output.

Standard this plugin will skip disabled, running tasks or jobs that
run at logon time. I also skip the 'Customer Experience' tasks,
they mostly run incorrectly without an internet connection anyway
and in my modest opinion they should not be there in the first place.

You can also exclude scheduled tasks. If the name of the task has empty
spaces, enclose in inverted quotes ( --exclude "name with space"=3
). You can exclude multiple tasks, but only the same task once (I am
trying to work out that limitation).

This plugin has been tested in Windows 2003(r2) and 2008(r2), both 32
and 64 bit editions.

This plugin will probably not work in locales other that English without
changes to the script. As I only work with Windows versions in English,
I cannot help you if it does not work in a French, German, ..., locale.
Just adapt the script to your needs.

=head1 ARGUMENTS

-c | --checknow:        required

-V | --version:         prints the version of this program

-e | --exclude:         exclude tasks. This should be a key=value
combination, where key is the task name and value the task exit value.

-h | --help | -?:       print this help text

EXAMPLES:

To check all scheduled jobs without exceptions:

check_schtaks -c

To check all scheduled jobs except the task name "job with spaces in
it" with exit level 2:

check_schtasks -c --exclude "job with spaces in it"=2

=head1 AUTHOR

natxo asenjo in his spare time

=cut

__DATA__
"HostName","TaskName","Next Run Time","Status","Logon Mode","Last Run Time","Last Result","Creator","Schedule","Task To Run","Start In","Comment","Scheduled Task State","Scheduled Type","Start Time","Start Date","End Date","Days","Months","Run As User","Delete Task If Not Rescheduled","Stop Task If Runs X Hours and X Mins","Repeat: Every","Repeat: Until: Time","Repeat: Until: Duration","Repeat: Stop If Still Running","Idle Time","Power Management"
"host","Defrag C","04:00:00, 09-10-2011","","Interactive/Background","04:00:00, 02-10-2011","0","SYSTEM","At 04:00 every Sun of every week, starting 26-05-2010","C:\WINDOWS\system32\defrag.exe c:","C:\WINDOWS\system32","N/A","Enabled","Weekly","04:00:00","26-05-2010","N/A","SUNDAY","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","DkTknSrv","05:00:00, 07-10-2011","","Interactive/Background","05:00:00, 06-10-2011","0","SYSTEM","At 05:00 every day, starting 05-05-2011","d:\scripts\DkTknSrv\DkTknSrv.cmd ","d:\scripts\DkTknSrv","N/A","Enabled","Daily ","05:00:00","05-05-2011","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","logoff disconnected sessions","15:32:00, 06-10-2011","","Interactive/Background","14:32:00, 06-10-2011","0","SYSTEM","Every 1 hour(s) from 21:32 for 24 hour(s) every day, starting 16-02-2011","d:\perl\bin\perl.exe d:\scripts\logoffdisc.pl","d:\perl\bin","N/A","Enabled","Hourly ","21:32:00","16-02-2011","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","1 Hour(s)","None","24 Hour(s): 0 Minute(s)","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","Memory Optimization Schedule","Disabled","","Background only","Never","0","SYSTEM","Disabled","C:\Program Files\Citrix\Server Resource Management\Memory Optimization Management\Program\CtxBace.exe -optimize","N/A","N/A","Disabled","At system start up","At system start up","01-01-2001","N/A","N/A","N/A","NT AUTHORITY\SYSTEM","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","Memory Optimization Schedule","Disabled","","Background only","Never","0","SYSTEM","Disabled","C:\Program Files\Citrix\Server Resource Management\Memory Optimization Management\Program\CtxBace.exe -optimize","N/A","N/A","Disabled","Hourly ","03:00:00","01-01-1999","N/A","Everyday","N/A","NT AUTHORITY\SYSTEM","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","perfmon-srv","02:00:00, 07-10-2011","","Interactive/Background","02:00:09, 06-10-2011","0","SYSTEM","At 02:00 every day, starting 02-07-2010","d:\scripts\startup\termserv.cmd ","d:\scripts\startup","N/A","Enabled","Daily ","02:00:00","02-07-2010","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","blabla","At system start up","","Interactive/Background","01:36:17, 06-10-2011","0","administrator","Run at system startup","d:\scripts\bla\prog.vbs ","d:\scripts\bla","N/A","Enabled","At system start up","At system start up","02-02-2010","N/A","N/A","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","robocopy dir","15:22:00, 06-10-2011","","Interactive/Background","14:22:00, 06-10-2011","3","SYSTEM","Every 1 hour(s) from 02:22 for 24 hour(s) every day, starting 06-09-2011","d:\scripts\robocopy.exe source d:\dir /copyall /mir /purge /r:2 /w:3 /xf program.exe /xd archive /np /log+:d:\scripts\logs\robocopy.log","d:\scripts","N/A","Enabled","Hourly ","02:22:00","06-09-2011","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","1 Hour(s)","None","24 Hour(s): 0 Minute(s)","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","shutdown","01:30:00, 07-10-2011","","Interactive/Background","01:30:00, 06-10-2011","0","SYSTEM","At 01:30 every day, starting 04-12-2009","d:\scripts\shutdown\shutdown.cmd ","d:\scripts\shutdown","N/A","Enabled","Daily ","01:30:00","04-12-2009","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","startup","At system start up","","Interactive/Background","01:36:10, 06-10-2011","0","SYSTEM","Run at system startup","d:\Scripts\Startup\startup.cmd ","d:\Scripts\Startup","N/A","Enabled","At system start up","At system start up","04-12-2009","N/A","N/A","N/A","domain\SVC.Scheduler","Disabled","72:0","Disabled","Disabled","Disabled","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
"host","robocopy dir","15:22:00, 06-10-2011","","Interactive/Background","14:22:00, 06-10-2011","2","SYSTEM","Every 1 hour(s) from 02:22 for 24 hour(s) every day, starting 06-09-2011","d:\scripts\robocopy.exe source d:\dir /copyall /mir /purge /r:2 /w:3 /xf program.exe /xd archive /np /log+:d:\scripts\logs\robocopy.log","d:\scripts","N/A","Enabled","Hourly ","02:22:00","06-09-2011","N/A","Everyday","N/A","domain\SVC.Scheduler","Disabled","72:0","1 Hour(s)","None","24 Hour(s): 0 Minute(s)","Disabled","Disabled","No Start On Batteries, Stop On Battery Mode"
