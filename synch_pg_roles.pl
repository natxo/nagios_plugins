#!/usr/bin/perl 
#===============================================================================
#
#         FILE: synch_pg_roles
#
#        USAGE: .
#
#  DESCRIPTION: synchronize users in a freeipa ldap realm with postgresql
#               roles in the database server
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Natxo Asenjo (), nasenjo@asenjo.nl
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 03/27/2012 07:02:43 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use Net::LDAP;

my $ldap = Net::LDAP->new( 'kdc.ipa.asenjo.nx' ) or die "$@";

# freeipa allows anonymous binds
my $msg = $ldap->bind (
#                        "testuser.jose",
#                        password    => 'passwd',
#                        version     => 3,
                    ); 

# search objects filtering on uid
$msg = $ldap->search(
                        base    => "cn=accounts,dc=ipa,dc=asenjo,dc=nx",
                        scope   => "sub",
                        filter  => "(uid=*)",
                        #                       attr    => ['uid'],
                    );

# $msg->code ;

# save the ldap users in value of hash, key not important
my %ldap_users;

for my $entry ( $msg->entries) {
    my $uid = $entry->get_value( 'uid' ) ;
    $ldap_users{$uid} = $uid;
}

$ldap->unbind;

my $ldap_users;
while ( my ($key, $value) = each ( %ldap_users ) ) {
    $ldap_users++;
}

print "Total ldap users: $ldap_users\n";

use DBI;

my $dbhost = "postgres.ipa.asenjo.nx";

my $dbh = DBI->connect("DBI:Pg:dbname=template1;host=$dbhost",'admin','');

my $sth = $dbh->prepare("SELECT usename from pg_catalog.pg_user") ;

$sth->execute();

# save the postgres roles in value of hash, key not important
my %postgres_roles;
while ( my @data = $sth->fetchrow_array() ) {
    $postgres_roles{$data[0]} = $data[0];
}

my $postgres_users;
while ( my ($key, $value) = each ( %postgres_roles ) ) {
    $postgres_users++;
}

print "Total postgres roles: $postgres_users\n";

for ( keys %postgres_roles) {
    unless ( exists $ldap_users{$_} ) {
        print "$_: not found in ldap\n";
        next;
    }
}

for ( keys %ldap_users) {
    unless ( exists $postgres_roles{$_} ) {
        print "$_: not found in postgres\n";
        next;
    }
}
