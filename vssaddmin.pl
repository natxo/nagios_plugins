#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  vssaddmin.pl
#
#        USAGE:  ./vssaddmin.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Natxo Asenjo (), nasenjo@asenjo.nl
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/05/2011 07:58:43 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Data::Dumper;

my ( $hash_ref, $writer_name, $writer_id, $writer_inst_id, $state,
    $last_error, %last_error_of );

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# a paragraph is a line
$/ = "" ;

# massage the DATA
# 1st split the paragraphs in lines, save the whole line in @line
# 2nd split @line in keys/values with ":"
while ( my $line = <DATA> ) {
    chomp $line ;

    my @line = split (/[\n\r]/, $line) ;

    for ( @line ) {
        my ($key, $value)  = split ( /:/) ;

        if ( $key =~ m/^.*name$/) {
            $writer_name = $value;
        }
        elsif ( $key =~ m/.*writer id$/i ) {
            $writer_id = $value;
        }
        elsif ( $key =~ m/.*writer instance id$/i ) {
            $writer_inst_id= $value;
        }
        elsif ( $key =~ m/.*state$/i ) {
            $state= $value;
        }
        elsif ( $key =~ m/.*last error$/i ) {
            $last_error= $value;
        }

        $hash_ref->{ $writer_name } = { 
                                        "Writer Name"           => $writer_name,
                                        "Writer ID"             => $writer_id,
                                        "Writer Instance ID"    => $writer_inst_id,
                                        "State"                 => $state,
                                        "Last error"            => $last_error,
                                    }; 
    }
}

#print Dumper $hash_ref;

# loop through the $hash_ref to get the value of 
# $hash_ref->{ $writer_name }->{ 'Last error' }
# if this value other is than " No error" (with a space before 'no'
# save it in a hash

for $writer_name ( keys %$hash_ref ) {
    $last_error = $hash_ref->{ $writer_name }{ 'Last error' };
    if ( $last_error ne " No error" ) {
        $last_error_of{$writer_name} = $last_error;
    }
}

# if the %lastresult_of is empty, this will be zero
if ( scalar keys %last_error_of == 0 ) {
    print "0K: All scheduled tasks seem to have run fine\n" ;
    exit $ERRORS{OK};
}
else{
    while ( my ( $key, $value) = each( %last_error_of) ) {
    print "WARNING: vssadmin list writers error: $key finished with error $value\n" ;
    exit $ERRORS{WARNING};
    }
}
__DATA__
Writer name: 'System Writer'
   Writer Id: {e8132975-6f93-4464-a53e-1050253ae220}
   Writer Instance Id: {eb6b4c30-aa48-486a-9618-0d1934d180ca}
   State: [1] Stable
   Last error: No error

Writer name: 'Registry Writer'
   Writer Id: {afbab4a2-367d-4d15-a586-71dbb18f8485}
   Writer Instance Id: {d3faa119-61c1-4ec4-b163-68b43efad58b}
   State: [1] Stable
   Last error: No error

Writer name: 'IIS Metabase Writer'
   Writer Id: {59b1f0cf-90ef-465f-9609-6ca8b2938366}
   Writer Instance Id: {d46610d4-d9a9-42c5-87c0-246aa1e352ad}
   State: [1] Stable
   Last error: No error

Writer name: 'Event Log Writer'
   Writer Id: {eee8c692-67ed-4250-8d86-390603070d00}
   Writer Instance Id: {8e45b579-b747-4967-9b4d-17f126bff3bb}
   State: [1] Stable
   Last error: No error

Writer name: 'Microsoft Exchange Writer'
   Writer Id: {76fe1ac4-15f7-4bcd-987e-8e1acb462fb7}
   Writer Instance Id: {728c7e4c-d8fa-46cc-999d-e20573e08a08}
   State: [7] Failed
   Last error: Retryable error

