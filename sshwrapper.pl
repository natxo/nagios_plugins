#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  sshwrapper.pl
#
#        USAGE:  ./sshwrapper.pl  
#
#  DESCRIPTION:  ssh handler for firefox
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Natxo Asenjo (NA), nasenjo@asenjo.nl
#      COMPANY:  Lekkerthuis
#      VERSION:  1.0
#      CREATED:  07/27/2009 08:06:45 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

# save the link in $url
my $url = $ARGV[0] ;
my @values = ( my $protocol, my $host) ;

# split the url in protocol and host part
@values = split(':', $url);

$protocol = $values[0];
$host = $values[1];

# here we use the tr operator to delete the 2 slashes of $url
$host =~ tr!//!!d;

if ( $protocol eq "rdp" ) {
    `rdesktop -u administrator $host -d IRISZORG -g 1280x1024`;
}
elsif ( $protocol eq "ssh" ) {
    #`xterm -e "slogin root\@$host"`;
    `gnome-terminal -e \'slogin root\@$host\'`;
}
elsif ( $protocol eq "telnet") {
    # `xterm -e "telnet $host"`;
    `gnome-terminal -e \'telnet $host\'`;
}

elsif ( $protocol eq "ping") {
    `gnome-terminal -e \'ping $host\'`;
}
