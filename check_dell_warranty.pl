#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  check_dell_warranty.pl
#
#        USAGE:  ./check_dell_warranty.pl
#
#  DESCRIPTION: get the warranty details for hardware from the Dell website
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Natxo Asenjo (), nasenjo@asenjo.nl
#      COMPANY:
#      VERSION:  0.4
#      CREATED:  09/21/2010 09:25:54 PM
#     REVISION:  ---
#===============================================================================




#-------------------------------------------------------------------------------
#  load necessary modules
#-------------------------------------------------------------------------------
use strict;
use warnings;
use Mojo::UserAgent;
use Getopt::Long;
use Pod::Usage;
use DateTime;

binmode STDOUT, ':utf8';

#-------------------------------------------------------------------------------
# global variables 
#-------------------------------------------------------------------------------
my %ERRORS = (
    'OK'        => 0,
    'WARNING'   => 1,
    'CRITICAL'  => 2,
    'UNKNOWN'   => 3,
    'DEPENDENT' => 4,
);
my $warning        = 90;
my $critical       = 30;
my $version        = 1 ;
my $help           = 0;
my $host           = 0;
my $revision       = undef;

# variables we need for functions later
my $debug          = undef;
my $tag            = undef;
my $days_left      = undef;

# we will save the 'end date' field in this array. There usually are
# two rows with this field on the $url
my @end_date;

# @end_date array should have this number twice
my $end_date       = undef;

# variable to save the DateTime comparison objects $dt_now/$dt_dellsite
my $cmp_date       = undef;


#-------------------------------------------------------------------------------
# cli options 
#-------------------------------------------------------------------------------
Getopt::Long::Configure( "no_ignore_case", "bundling" );
GetOptions(
    'H|hostname=s' => \$host,
    't|tag=s'      => \$tag,
    'h|help|?'     => \$help,
    'v|verbose'    => \$debug,
    'V|version'    => \$revision,
    'w|warning=i'  => \$warning,
    'c|critical=i' => \$critical,
);

# get version info if requested and exit
if ($revision) {
    print "Version: $version\n";
    exit $ERRORS{OK};
}


#-------------------------------------------------------------------------------
# documentation 
#-------------------------------------------------------------------------------
 
pod2usage(1) if $help;

pod2usage( -verbose => 1, -noperldoc => 1, ) unless $host;


#-------------------------------------------------------------------------------
#  process cli switches
#-------------------------------------------------------------------------------
# if no tag is given from the cli and the check is run against localhost
# try getting it from dmidecode
if ( !defined $tag and $host eq "localhost" ) {
    dbg("Getting tag from dmidecode");
    _get_delltag_dmidecode();
    dbg("tag is $tag");
}

# :TODO:01/11/2011 11:03:58 PM::
# if $host is remote, then we need to check it from snmp;
# we kan get the serial number/service tag remotely from snmp:
# snmpwalk host -c public -v 1 1.3.6.1.4.1.674.10892.1.300.10.1.11.1
# returns a string: NMPv2-SMI::enterprises.674.10892.1.300.10.1.11.1 = STRING: "H980L4J"
# this will *not* work with vmware esxi because there is no snmp support
# grrrr

# If we cannot get a $tag either from the cli options or dmidecode or
# snmp, then we cannot go on. End script then.
unless ( defined $tag ) {
    print
"We could not find an appropriate dell tag string. Without one we cannot use this plugin.\n";
    exit $ERRORS{UNKNOWN};
}

#-------------------------------------------------------------------------------
#  main script
#-------------------------------------------------------------------------------

# create 2 DateTime objects that we need to compare: one is the actual date
# and the other one we create from the result we parse from the dell.com site.
# We need 2 DateTime objects because we can only compare DateTime objects to
# get the warranty days left.
my $dt_now = DateTime->now( time_zone => 'local' );

# this will be calculated from the info we get from dell.com, see
# _from_text_to_datetime function
my $dt_dellsite = undef;


# create mojolicious browser agent
# standard mojolicious does not follow redirects
my $ua = Mojo::UserAgent->new( max_redirects => 3, );

my $url =
"http://www.dell.com/support/my-support/us/en/04/product-support/servicetag/$tag";

# save the site in $tx
my $tx = $ua->get( $url);

if ( my $res = $tx->success ) {

# let mojo do its magic
# find an element in the dom containing a <div> tag with class id span6 *and*
# a link containing the anchor '#warrantyModal'. Inside that, you will find
# the end date for the hardware warranty
    for my $e ( $tx->res->dom->find('div.span6 a[href^=#warrantyModal]')->text) {
        #say $e;
        push @end_date, $e;
        _get_end_date(@end_date);
        _find_days_left() ;
        _compare_date_objects();
        _get_crit_warning($days_left);
    }
}
else {
    my ($err, $code) = $tx->error;
    print $code ? "$code response: $err" : "Connection error: $err\n";
    exit 1;
}

#-------------------------------------------------------------------------------
#  functions
#-------------------------------------------------------------------------------

#===  FUNCTION  ================================================================
#         NAME:  _get_end_date
#      PURPOSE:  compare the @end_date array, get just one of the two
#                values if they are equal
#   PARAMETERS:  @end_date
#      RETURNS:  $end_date
#  DESCRIPTION:  ????
#       THROWS:  if we do not get 2 values in @end_date, croak.
#                If the 2nd value is '0', then there is no next business
#                day support (only 4hr mission critical support), so
#                just skip the second value
#                If we get 3 values then we have prosupport and 4 hour
#                mission critical (yay)
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================

sub _get_end_date {
    if ( scalar(@end_date) == 1 ) {
            $end_date = $_[0];
            dbg("getting the array \@end_date");
            return $end_date;
        }
    else {
        dbg(
"We did not get 2 values in \@end_date, do we have the right dell tag?"
        );
        dbg( scalar(@end_date) );
        dbg(@end_date);
        return "UNKONWN";
    }
}

sub _is_end_date_defined {
    ($end_date) = @_;
    if ( defined $end_date ) {
        return;
    }
    else {
        print
"Could not find the number of days left in the warranty. Have you entered a correct Service Tag?\n";
        exit $ERRORS{UNKNOWN};
    }
}    # ----------  end of subroutine _is_end_date_defined  ----------


#===  FUNCTION  ================================================================
#         NAME: _from_text_to_datetime
#      PURPOSE: convert $days_left string to DateTime object
#   PARAMETERS: 
#      RETURNS: DateTime object with warranty end date from dell.com site
#  DESCRIPTION: after dell.com changed their site we no longer get a 'days
#  left cell we can use, only a 'start date' and 'end date' cell. We need to
#  compare the string in mm/dd/yyyy format. Using the DateTime module we can
#  compare the dates and get the days left we used to :-)
#
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub _from_text_to_datetime {
    # $end_date is in the format mm/dd/yyyy, so we split the string using the
    # '/' separator in 3 new variables
    dbg("\$end_date is $end_date");
    my ( $month, $day, $year ) = split('/', $end_date );

    # fill the DateTime object with these values
    $dt_dellsite = DateTime->new (
        year           => $year,
        month          => $month,
        day            => $day,
        time_zone      => 'local',
    ); 

    return $dt_dellsite;
} ## --- end sub _from_text_to_datetime


sub _find_days_left {

    _from_text_to_datetime;

    my $dur = $dt_dellsite->delta_days($dt_now); 
    $days_left = $dur->in_units('days');
    return $days_left;
} ## --- end sub _find_days_left


#===  FUNCTION  ================================================================
#         NAME: _compare_date_objects
#      PURPOSE: find out if $dt_now is older or newer than $dt_dellsite
#   PARAMETERS: none
#      RETURNS: $cmp_date: 
#               -1 if $dt_dellsite < $dt_now
#               0  if $dt_dellsite == $dt_now
#               1  if $dt_dellsite > $dt_now
#  DESCRIPTION: 
#       THROWS: no exceptions
#     COMMENTS: if I do now compare this, after reaching 0 days warranty, the
#     clock starts counting the other way ;-), which is obviosly a bug in my
#     script.
#     SEE ALSO: n/a
#===============================================================================
sub _compare_date_objects {
    $cmp_date = DateTime->compare( $dt_dellsite, $dt_now );
    dbg("$dt_dellsite, $dt_now, $cmp_date");
    return $cmp_date;
}

sub dbg {
    print STDERR "--", shift, "\n" if $debug;
}    # ----------  end of subroutine dbg  ----------

#===  FUNCTION  ================================================================
#         NAME:  _get_delltag_dmidecode
#      PURPOSE:  get the dell tag using dmidecode
#   PARAMETERS:
#      RETURNS:  dell tag string
#  DESCRIPTION:  when run on the localhost, we can get the dell tag
#                with dmidecode --type system
#       THROWS:  no exceptions
#     COMMENTS:  as this plugin will probably run as user nagios, we
#                need to use sudo. dmidecode can only run as root
#                To enable sudo dmidecode for the user nagios, edit the
#                sudoers file with visudo and set something like this:
#                nagios     ALL = NOPASSWD: /usr/sbin/dmidecode
#     SEE ALSO:  n/a
#===============================================================================
sub _get_delltag_dmidecode {
    my $dmidecode = "sudo dmidecode --type system";
    dbg("running and parsing $dmidecode");
    open my $outputdmidecode, '-|', $dmidecode or die "$!\n";
    while (<$outputdmidecode>) {
        chomp;    # dump hidden new lines please

        # we need to match Serial Number: *****, we save everything
        # after the : until a space in $1 which later becomes $tag
        # update: now we return the lower case tag after an update of
        # Dell's site
        if ( $_ =~ m/^.*Serial Number: (.*)\s*$/ ) {
            $tag = lc $1;
        }
    }

    close $outputdmidecode;

    dbg("this system\'s dell tag is $tag");

    return $tag;
}    # ----------  end of subroutine _get_delltag_dmidecode  ----------

#===  FUNCTION  ================================================================
#         NAME:  _get_crit_warning
#      PURPOSE:  check if the value in $days_left should is bigger or
#                smaller than $warning or $critical. It now removes the
#                temporary file created by the script.
#                if $cmp_date == 1 then still under warranty
#                if $cmd_date == 0 or == -1, then no more warranty
#   PARAMETERS:  $days_left
#      RETURNS:  OK, WARNING or CRITICAL
#  DESCRIPTION:  ????
#       THROWS:  no exceptions
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================
sub _get_crit_warning {
    my ($days_left) = @_;
    dbg("number of days left now is $days_left");
    if ( $days_left >= $warning && $cmp_date == 1 ) {
        print "OK: $days_left days of warranty left\n";
        exit $ERRORS{OK};
    }
    # here was the bug, if $cmp_date is 1, then still under warranty
    elsif ( ( $days_left < $warning && $days_left > $critical )
                && $cmp_date == 1 ) {
        print "WARNING: $days_left days of warranty left\n";
        exit $ERRORS{WARNING};
    }
    elsif ( $days_left <= $critical && $cmp_date <= 0 ) {
        print "CRITICAL: server already $days_left days out of warranty.\n";
        exit $ERRORS{CRITICAL};
    }
    elsif ( $days_left <= $critical ) {
        print "CRITICAL: $days_left days of warranty left\n";
        exit $ERRORS{CRITICAL};
    }
}


#-------------------------------------------------------------------------------
#  Plain Old Documentation
#-------------------------------------------------------------------------------

=head1 NAME

check_dell_warranty

=head1 SYNOPSIS

check_dell_warranty -H [hostname] -[tcwvVh]

=head1 DESCRIPTION

Nagios plugin to check the remaining days of warranty left for Dell
hardware.

The plugin requires the installation of the HTML::TableExtract module,
available from your Perl distributor repositories or CPAN.

=head1 ARGUMENTS

-H | --host     Hostname/ip address of server to monitor (required)

-t | --tag      Dell service tag number of server to monitor; if you do
not specify one on the command line, the script will try to get it from
dmidecode (only localhost), snmp (todo) or omreport (todo, only localhost)

-V | --version  prints the version of this program

-v | --verbose  prints extra debugging information

-w | --warning  days before nagios gives a warning; default is 90

-c | --critical days before nagios gives a critical alert; default is 30

-h | --help | -?  print this help text

=head1 AUTHOR

natxo asenjo in his spare time
