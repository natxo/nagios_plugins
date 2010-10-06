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
#      VERSION:  1.0
#      CREATED:  09/21/2010 09:25:54 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use WWW::Mechanize;
use File::Temp;
use Getopt::Long;
use Pod::Usage;

my $file_is_text = undef;
my $file_is_binary= undef;
my $debug = 0;
my $version = "0.01";
my $host = 0;
my $tag = 0;

Getopt::Long::Configure('no_ignore_case');
GetOptions(
    'H|host=s'      =>  \$host,
    't|tag=s'       =>  \$tag,
    'h|help'        =>  sub { help(); },
    'v|verbose'     =>  \$debug,
    'V|version'     =>  \$version,
) or help();

#pod2usage(-verbose=>0, -noperldoc => 1,) if help();
#pod2usage(-verbose=>0, -noperldoc => 1,) unless $tag;
pod2usage(0) unless $tag;

# we will save the 'days left' field in this array. There usually are
# two rows with this field on the $url
my @days_left;

# this is the final number of days left we are interested in. The
# @days_left array should have twice this number
my $days_left = undef;

# create a temporary file where we will save the Dell website with the
# warranty info. The file will clear itself when the script is finished
dbg("create a temporary file to store the Dell site with the warranty
    info");
my $content = File::Temp->new();


# define the mechanize object
my $mech = WWW::Mechanize->new( autocheck => 1 );

# set the user agent that will show in dell's logs
$mech->agent('check_dell_warranty/0.01; nagios plugin to monitor the number of days left before the warranty expires');

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
    dbg( "Yes, we need to gunzip!");
    _extract_file($content);
    _days_warranty_left($content);
    _get_days_left(@days_left);
}
elsif ( defined $file_is_text ) {
    dbg( "no compression found, proceeding with the rest");
    _days_warranty_left();
    _get_days_left(@days_left);
    print "tag 3GHKN4J has $days_left days of warranty left\n";
}

#get the table with headers: Description, Provider, Warranty, Start,
#End, Days. These are a list of regular expressions per header, so the
#first header can be 'Description of the Warranty' but you shorten it
#to 'Description'. Every header corresponds with a column in the table. I
#declare an array @headers in order to make the $te object more easily
#readable, you do not nead to predeclare it, you could use an anonymous
#array reference like :
#headers => [ qw(Description Provider Warranty Start End Days) ];
#If the headers change, just change them here.

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
    my ( $content ) = @_;
    use HTML::TableExtract;
    my @headers = qw(Description Provider Warranty Start End Days) ;
    my $te = HTML::TableExtract->new( headers => \@headers );

    #parse the $content 
    dbg("parsing the $content file");
    $te->parse_file( $content) ;

    # get the rows
    sleep 10;
    dbg("get rows in the html tables");
    for my $ts($te->tables) {

        for my $row_ref ($ts->rows) {

            # store the days left value in global @days_left
            dbg("save the value in the days left cell in \@days_left");
            push @days_left, $row_ref->[5];
        };
    };

    dbg("@days_left");
    return @days_left;
}	# ----------  end of subroutine days_warranty_left  ----------


#===  FUNCTION  ================================================================
#         NAME:  get_days_left
#      PURPOSE:  compare the @days_left array, get just one of the two
#                values if they are equal
#   PARAMETERS:  @days_left
#      RETURNS:  $days_left
#  DESCRIPTION:  ????
#       THROWS:  no exceptions
#     COMMENTS:  none
#     SEE ALSO:  n/a
#===============================================================================

sub _get_days_left {
    if ( scalar(@days_left) == 2 ) {
        if ($_[1] == $_[0]) {
           $days_left = $_[1];
           dbg("getting the array \@days_left");
           return $days_left;
        }
    }
    else {
        dbg("Something wet wrong while comparing \@days_left");
        dbg(scalar(@days_left));
        dbg(@days_left);
        return "UNKONWN";
    }
}


sub _is_days_left_defined {
    ( $days_left )	= @_;
    if ( defined $days_left) {
    return ;
    }
    else {
        print "Could not find the number of days left in the warranty.\n";
        print "Have you entered a correct Service Tag?\n";
        exit 3;
    }
}	# ----------  end of subroutine _is_days_left_defined  ----------
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
    my	( $dumped_file )	= @_;
    if ( -T $dumped_file) {
        dbg("$content is a text file!");
        return $file_is_text = 1 ;
    }
    elsif ( -B $dumped_file ) {
        dbg("$content is a binary file!");
        return $file_is_binary = 1;
    }
}	# ----------  end of subroutine _is_file_text_or_bin  ----------


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
    my	( $compressed_file )	= @_;
    use File::Copy;
    my $gzippedfile = "$content\.gz";
    my $htmlfile = "$content\.html";

    dbg("rename $content to $gzippedfile");
    move($content,$gzippedfile) or
        die "couldn't move $content to $gzippedfile: $!";

    dbg("extract $gzippedfile");
    if ( -e "$gzippedfile" ) {
        system("/bin/gunzip $gzippedfile");

        dbg("rename $content to $htmlfile");
        move($content,$htmlfile) or die
            "could not move $content to $htmlfile: $!\n";
        
        $content = $htmlfile;
        }
    if (-B $content) {
        dbg("$content is binary, HTML::Extract cannot parse it");
    }
}	# ----------  end of subroutine _extract_file  ----------

sub dbg {
    print STDERR "--", shift, "\n" if $debug;
}	# ----------  end of subroutine dbg  ----------

sub help {
    my $heredoc = <<EOF;
        -H, --host
        -t, --tag
        -V, --verbose
        -v, --version

EOF
    print $heredoc;
}

=head1 NAME

check_dell_warranty

=head1 SYNOPSIS

check_dell_warranty -H [hostname] -t [service tag number]

=head1 DESCRIPTION

Nagios plugin to check the remaining days of warranty left for Dell
hardware.

The plugin requires the installation of the HTML::TableExtract module,
available from your Perl distributor repositories or CPAN.

=head1 ARGUMENTS

--host  Hostname/ip address of server to monitor

--tag   Dell service tag number of server to monitor

--version

--help

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
