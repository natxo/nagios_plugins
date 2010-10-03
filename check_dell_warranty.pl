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

# we will save the 'days left' field in this array. There usually are
# two rows with this field on the $url
my @days_left;

# this is the final number of days left we are interested in. The
# @days_left array should have twice this number
my $days_left;

my $content = "/tmp/dell";
my $mech = WWW::Mechanize->new( autocheck => 1 );

# set the user agent that will show in dell's logs
$mech->agent('check_dell_warranty/0.01; nagios plugin to monitor the number of days left before the warranty expires');

my $url =
"http://support.dell.com/support/topics/global.aspx/support/my_systems_info/details?c=us&l=en&s=gen&ServiceTag=3GHKN4J";

# dump the page to the file $content
$mech->get( $url, ":content_file" => "$content" );
print $mech->dump_headers();

die "cannot get the page: ", $mech->response->status_line
    unless $mech->success;

_days_warranty_left();

get_days_left(@days_left);

print "tag 3GHKN4J has $days_left days of warranty left\n";
#my $page = $mech->get( "file://$url" );

=pod
get the table with headers: Description, Provider, Warranty, Start,
End, Days. These are a list of regular expressions per header, so the
first header can be 'Description of the Warranty' but you shorten it
to 'Description'. Every header corresponds with a column in the table. I
declare an array @headers in order to make the $te object more easily
readable, you do not nead to predeclare it, you could use an anonymous
array reference like :
headers => [ qw(Description Provider Warranty Start End Days) ];
If the headers change, just change them here.
=cut

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
    use HTML::TableExtract;
    my @headers = qw(Description Provider Warranty Start End Days) ;
    my $te = HTML::TableExtract->new( headers => \@headers );

    #parse the $content 
    $te->parse_file( $content) ;

    # get the rows
    for my $ts ($te->tables) {

        for my $row_ref ($ts->rows) {
            # store the days left value in global @days_left
            push @days_left, $row_ref->[5];
        }
    }

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

sub get_days_left {
    if ( scalar(@days_left) == 2 ) {
        if ($_[1] == $_[0]) {
           $days_left = $_[1];
           return $days_left;
        }
    }
    else {
        return "UNKONWN";
    }
}

=pod
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
