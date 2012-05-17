#!/usr/bin/perl

use strict;
use warnings;
use WWW::Mechanize;

my ($url,@links,$mech,$vineta);

$url = "http://elpais.com";

$mech = WWW::Mechanize->new(autocheck =>1);

$mech->show_progress(1); # show debugging info

$mech->agent_alias( 'Windows IE 6');
$mech->get($url);
die "cannot get the page: ", $mech->response->status_line
    unless $mech->success;

getlink("Forges");
send_attachment("Forges");
getlink("El Roto");
send_attachment("El Roto");
getlink("Romeu");
send_attachment("Romeu");

# getlink() gets as first and only parameter the name of a cartoonist. It
# finds the link of the cartoon for that day.
sub getlink {
    my ( $cartoonist ) = @_;

    # give some output when run interactively
    print "Fetching cartoon $cartoonist....\n";

    # get the link to the cartoon, find the name of cartoonist on page
    @links = $mech->find_link(
        tag         =>  "a",
        text_regex  =>  qr/.*$cartoonist.*/i,
    ) or warn "no link for $cartoonist found, maybe on holiday\n";
 
    # here we get the actual url to the cartoon
    for (@links) {
        my $href = $_->url;
        $vineta = "$url$href";
    }

    # we make another mechanize object to fecth the image and dump it to a file in
    # /tmp
    my $m = WWW::Mechanize->new(autocheck => 1, show_progress => 1,);

    $m->agent_alias( 'Windows IE 6');

    $m->get($vineta);

    my @links2 = $m->find_image( 
        url_regex   => qr/.*noticia_normal\.jpg$/,
    );

    for ( @links2 ) {
        my $url = $_->url;
        $m->get($url, ":content_file" => "/tmp/$cartoonist.jpg");
        
    }
}

sub send_attachment {
    my ( $cartoonist ) = @_ ;
    use MIME::Lite;
    my $msg = MIME::Lite->new(
        From        =>  'nasenjo@asenjo.nl',
        To          =>  'nasenjo@asenjo.nl',
        Subject     =>  "$cartoonist",
        Type        =>  'multipart/mixed',
    );
    $msg->attach(
        Type        =>  'TEXT',
        Data        =>  "$cartoonist",
    );
    $msg->attach(
        Type        =>  'image/gif',
        Path        =>  "/tmp/$cartoonist.jpg",
        Filename    =>  "$cartoonist.jpg",
    );
    $msg->send();
}
