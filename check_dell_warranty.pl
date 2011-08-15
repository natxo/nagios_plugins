#!/usr/bin/perl 
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
#      VERSION:  0.3
#      CREATED:  09/21/2010 09:25:54 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use WWW::Mechanize;
use File::Temp;
use Getopt::Long;
use Pod::Usage;

my %ERRORS = (
    'OK'        => 0,
    'WARNING'   => 1,
    'CRITICAL'  => 2,
    'UNKNOWN'   => 3,
    'DEPENDENT' => 4,
);
my $file_is_text   = undef;
my $file_is_binary = undef;
my $debug          = 0;
my $help           = 0;
my $host           = 0;
my $tag            = undef;
my $version        = "0.03";
my $revision       = undef;
my $warning        = 90;
my $critical       = 30;

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

pod2usage(1) if $help;

#pod2usage(-verbose=>0, -noperldoc => 1,) if help();
#pod2usage(-verbose=>0, -noperldoc => 1,) unless $tag;
pod2usage( -verbose => 1, -noperldoc => 1, ) unless $host;

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

# we will save the 'days left' field in this array. There usually are
# two rows with this field on the $url
my @days_left;

# this is the final number of days left we are interested in. The
# @days_left array should have this number twice
my $days_left = undef;

# create a temporary file where we will save the Dell website with the
# warranty info. The file will clear itself when the script is finished
dbg(
    "create a temporary file to store the Dell site with the warranty
    info"
);
my $content = File::Temp->new();

# define the mechanize object
my $mech = WWW::Mechanize->new( autocheck => 1 );

# set the user agent that will show in dell's logs
$mech->agent(
"check_dell_warranty/$version; nagios plugin to monitor number of days left before warranty expires"
);

my $url =
"http://support.dell.com/support/topics/global.aspx/support/my_systems_info/details?c=us&l=en&s=gen&ServiceTag="
  . $tag;

dbg("site is $url");

# dump the page to the temporary file $content
dbg("dump the site to the temporary file $content");
$mech->get( $url, ":content_file" => "$content" );

die "cannot get the page: ", $mech->response->status_line
  unless $mech->success;

# check if $content is gzipped
_is_file_text_or_bin($content);

# if the module Compress::Zlib is installed, WWW::Mechanize will offer
# to download the file with gzip compression enabled. If it is not
# compressed, it will be HTML text. If it is compressed, it will be
# binary. Once we know that, we can extract the file, parse it and get
# the results in one go
if ( defined $file_is_binary ) {
    dbg("Yes, we need to gunzip!");
    _extract_file($content);
    _days_warranty_left($content);
    _get_days_left(@days_left);
    _get_crit_warning($days_left);
}
elsif ( defined $file_is_text ) {
    dbg("no compression found, proceeding with the rest");
    _days_warranty_left();
    _get_days_left(@days_left);
    _get_crit_warning($days_left);
}

# get the table with headers: Description, Provider, Warranty, Start,
# End, Days. These are a list of regular expressions per header, so the
# first header can be 'Description of the Warranty' but you shorten it
# to 'Description'. Every header corresponds with a column in the table. I
# declare an array @headers in order to make the $te object more easily
# readable, you do not nead to predeclare it, you could use an anonymous
# array reference like :
# headers => [ qw(Description Provider Warranty Start End Days) ];
# If the headers change, just change them here.

#===  FUNCTION  ================================================================
#         NAME:  _days_warranty_left
#      PURPOSE:  get the remaining days of warranty
#   PARAMETERS:  ????
#      RETURNS:  an array with the days left of warranty (usually 2
#                items with the same value
#  DESCRIPTION:  ????
#       THROWS:  no exceptions
#     COMMENTS:  none
#     SEE ALSO:  pod file above
#===============================================================================
sub _days_warranty_left {
    my ($content) = @_;
    use HTML::TableExtract;
    my @headers = qw(Description Provider Start End Days);
    my $te = HTML::TableExtract->new( headers => \@headers );

    #parse the $content
    dbg("parsing the $content file");
    $te->parse_file($content);

    # get the rows
    dbg("get rows in the html tables");
    for my $ts ( $te->tables ) {

        for my $row_ref ( $ts->rows ) {

            # store the days left value in global @days_left
            dbg("save the value in the days left cell in \@days_left");
            push @days_left, $row_ref->[4];
        }
    }

    dbg("@days_left");
    return @days_left;
}    # ----------  end of subroutine days_warranty_left  ----------

#===  FUNCTION  ================================================================
#         NAME:  _get_days_left
#      PURPOSE:  compare the @days_left array, get just one of the two
#                values if they are equal
#   PARAMETERS:  @days_left
#      RETURNS:  $days_left
#  DESCRIPTION:  ????
#       THROWS:  if we do not get 2 values in @days_left, croak.
#                If the 2nd value is '0', then there is no next business
#                day support (only 4hr mission critical support), so
#                just skip the second value
#                If we get 3 values then we have prosupport and 4 hour
#                mission critical (yay)
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================

sub _get_days_left {
    if ( scalar(@days_left) >= 1 ) {
        if ( $_[1] == $_[0] ) {
            $days_left = $_[1];
            dbg("getting the array \@days_left");
            return $days_left;
        }
        # if the 2nd or 3rd result are 0, keep the first
        elsif ( $_[1]  == 0 )  {
            $days_left = $_[0];
            return $days_left;
        }
        elsif ( $_[2]  == 0 )  {
            $days_left = $_[0];
            return $days_left;
        }
    }
    else {
        dbg(
"We did not get 2 values in \@days_left, do we have the right dell tag?"
        );
        dbg( scalar(@days_left) );
        dbg(@days_left);
        return "UNKONWN";
    }
}

sub _is_days_left_defined {
    ($days_left) = @_;
    if ( defined $days_left ) {
        return;
    }
    else {
        print
"Could not find the number of days left in the warranty. Have you entered a correct Service Tag?\n";
        exit $ERRORS{UNKNOWN};
    }
}    # ----------  end of subroutine _is_days_left_defined  ----------

#===  FUNCTION  ================================================================
#         NAME:  _is_file_text_or_bin
#      PURPOSE:  find out if dumped file is compressed or text only
#   PARAMETERS:  the path to the html file dumped to the hard disk
#      RETURNS:  true for either text or binary files
#  DESCRIPTION:  if the Compress::Zlib module is installed, then
#                WWW::Mechanize offers to downlogd gzipped files. We
#                need to find out if the file is gzipped of not
#       THROWS:  no exceptions
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================
sub _is_file_text_or_bin {
    my ($dumped_file) = @_;
    if ( -T $dumped_file ) {
        dbg("$content is a text file!");
        return $file_is_text = 1;
    }
    elsif ( -B $dumped_file ) {
        dbg("$content is a binary file!");
        return $file_is_binary = 1;
    }
}    # ----------  end of subroutine _is_file_text_or_bin  ----------

#===  FUNCTION  ================================================================
#         NAME:  _extract_file
#      PURPOSE:  extract the compressed dumped file
#   PARAMETERS:  path to the dumped file
#      RETURNS:  nothing
#  DESCRIPTION:  if the file is compressed, then we rename it with the
#                extension .gz. Otherwise gunzip complains
#       THROWS:  no exceptions
#     COMMENTS:  once the gzipped file is extrated, we need to rename it
#                to *.html or HTML::Extract cannot understand it
#     SEE ALSO:  n/a
#===============================================================================
sub _extract_file {
    my ($compressed_file) = @_;
    use File::Copy;
    my $gzippedfile = "$content\.gz";
    my $htmlfile    = "$content\.html";

    dbg("rename $content to $gzippedfile");
    move( $content, $gzippedfile )
      or die "couldn't move $content to $gzippedfile: $!";

    dbg("extract $gzippedfile");
    if ( -e "$gzippedfile" ) {
        system("/bin/gunzip $gzippedfile");

        dbg("rename $content to $htmlfile");
        move( $content, $htmlfile )
          or die "could not move $content to $htmlfile: $!\n";

        $content = $htmlfile;
    }
    if ( -B $content ) {
        dbg("$content is binary, HTML::Extract cannot parse it");
    }
}    # ----------  end of subroutine _extract_file  ----------

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
#   PARAMETERS:  $days_left
#      RETURNS:  OK, WARNING or CRITICAL
#  DESCRIPTION:  ????
#       THROWS:  no exceptions
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================
sub _get_crit_warning {
    my ($days) = @_;
    dbg("number of days left now is $days");
    if ( $days >= $warning ) {
        unlink $content
          if -e $content
              or warn "could not delete $content: $!\n";
        print "OK: $days days of warranty left\n";
        exit $ERRORS{OK};
    }
    elsif ( $days_left < $warning && $days_left > $critical ) {
        unlink $content
          if -e $content
              or warn "could not delete $content: $!\n";
        print "WARNING: $days days of warranty left\n";
        exit $ERRORS{WARNING};
    }
    elsif ( $days_left <= $critical ) {
        unlink $content
          if -e $content
              or warn "could not delete $content: $!\n";
        print "CRITICAL: $days days of warranty left\n";
        exit $ERRORS{CRITICAL};
    }
}

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

=head1 Debugging HTML::TableExtract

How to debug HTML::TableExtract
Replace the $te object and for loop with this to get *all tables* and
their location in the $content

 
    my $te = HTML::TableExtract->new();

    $te->parse_file($url);

    for my $ts ($te->tables) {
        print "Table (", join(',', $ts->coords), "):\n";

        for my $row_ref ($ts->rows) {
            print join(',', @$row_ref), "\n";
        }
    }

You get all the tables in $content and the one we want is something like this:

Table found at 6,0:
Description,Provider,Warranty Extension Notice *,Start Date,End Date,Days Left
Next Business Day,DELL,No,2/24/2010,2/25/2013,888
NBD ProSupport For IT On-Site,DELL,No,2/24/2010,2/25/2013,888

so we want to get the table at depth 6 count 0

get the table at depth 6 and count 0 because that one has the info we
want

my $te = HTML::TableExtract->new( depth => 6, count => 0);
=cut
