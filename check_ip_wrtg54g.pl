#!/usr/bin/perl -w
########################################################################

use strict;
use warnings;
use LWP::UserAgent;
use Data::Dumper;
use Getopt::Long;
use HTML::TableExtract;

my $host="";
my $realm="";
my $password="";
my $addr = "";
my $port=80;

my $result=GetOptions(
                      "host=s" => \$host,
                      "realm=s" => \$realm,
                      "password=s" => \$password,
                      "ipaddress=s" => \$addr,
                      "port=i" => \$port
                   );
my $ua=LWP::UserAgent -> new();

barf_and_complain()
    unless (
            $host and $realm and $password and $addr

            );
my $host_settings=sprintf("%s:%d",$host,$port);
my $url = sprintf("http://%s:%d/Status_Router.asp",$host,$port);

$ua -> credentials ($host_settings,$realm,"",$password);

my $temp = "/tmp/content";
my $response = $ua->get($url, ':content_file' => $temp);

use HTML::TableExtract;

my $ip_addr="" ;

my $te = HTML::TableExtract->new( depth => 1, count => 1);
$te->parse_file($temp);
for my $ts ($te->tables) {
    for my $row_ref ($ts->rows) {
# for debugging, insert this in the for loop:
#        print "1st element: $row_ref->[0]\n";
#        print "2nd element: $row_ref->[1]\n";
#        print "3rd element: $row_ref->[2]\n";
#        print "4th element: $row_ref->[3]\n";
#        print "5th element: $row_ref->[4]\n";
#        print "6th element: $row_ref->[5]\n";
#        print "7th element: $row_ref->[6]\n";
        next unless defined $row_ref->[5];
        if ( $row_ref->[5] =~ m/^.*capture.*ipaddr.*/i ) {
            $ip_addr= $row_ref->[6];
        }
   }
}

if ( $ip_addr eq $addr ){
    printf "OK: My IP Address is: %s\n",$ip_addr;
    exit 0;
} else {
    printf "CRITICAL: My IP ADDESS HAS CHANGED to %s\n",$ip_addr;
    exit 2;
}

sub barf_and_complain {

printf "%s\n",qq(
You must specify all options for this plugin to work:
                 --host hostname or ip of router
                 --realm security realm of router
                 --ipaddress expected ip address
                 --password  login password for router

                 the --port option is just that, an option and defaults
                 to 80
                 );
exit(1);

}
