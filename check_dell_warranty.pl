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

#use LWP::Debug qw(+);
#use WWW::Mechanize;
use HTML::TableExtract;


# we will save the 'days left' field in this array. There usually are
# two rows with this field on the $url
my @days_left;
#my $mech = WWW::Mechanize->new( autocheck => 1 );

#my $url =
#"http://support.dell.com/support/topics/global.aspx/support/my_systems_info/details?c=us&l=en&s=gen&ServiceTag=3GHKN4J";

my $url = "$ENV{HOME}/scripts/dell.html";

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
my @headers = qw(Description Provider Warranty Start End Days) ;
my $te = HTML::TableExtract->new( headers => \@headers );

# parse the $url 
$te->parse_file( $url) ;


# get the rows
for my $ts ($te->tables) {

    for my $row_ref ($ts->rows) {
    #print "Warranty days left: $row->[5]\n";
        push @days_left, $row_ref->[5];

    }
}

print join( ',', @days_left ), "\n" ;

=pod
How to debug HTML::TableExtract
Use the following $te object to see how many tables there are and where

my $te = HTML::TableExtract->new();
print "Table found at ", join(',', $ts->coords), ":\n";

You get something like this:

Table found at 6,0:
Description,Provider,Warranty Extension Notice *,Start Date,End Date,Days Left
Next Business Day,DELL,No,2/24/2010,2/25/2013,888
NBD ProSupport For IT On-Site,DELL,No,2/24/2010,2/25/2013,888

so we want to get the table at depth 6 count 0

get the table at depth 6 and count 0 because that one has the info we
want

my $te = HTML::TableExtract->new( depth => 6, count => 0);
=cut
