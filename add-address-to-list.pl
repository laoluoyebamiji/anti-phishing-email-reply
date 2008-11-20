#!/usr/bin/perl
# 
# add-address-to-list.pl, DESCRIPTION
# 
# Copyright (C) 2008 Jesse Thompson
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# $Id:$
# Jesse Thompson <jesse.thompson@doit.wisc.edu>

use strict;
use warnings;

my $usage = "$0 user\@domain\nor\n$0 user\@domain,type,date\n";
my $List_File = "phishing_reply_addresses";
my %List = ();

# load addresses from file
parse_list_file();

if ( @ARGV ) {

    # add new addresses from command line
    for ( @ARGV ) {
        add_to_list($_);
    }

}
else {

    # prompt for addresses
    while ( add_to_list() ) { }

}

# write out addresses to file
write_list_file();


# loads addresses from file into the hash
sub parse_list_file {
    die "$List_File does not exist\n" unless ( -e $List_File );
    open my $list_fh, "<", $List_File or die "can't open $List_File: $!\n";
    while ( <$list_fh> ) {
        s/\r$//;
        if ( m/^#/ ) {
            $List{'header'} .= $_;
            next;
        }
        chomp;
        add_to_list($_);
    }
    close $list_fh;
}

# adds an address entry to the hash
sub add_to_list {

    my $new_entry = shift;
    my $message = "";

    if ( ! $new_entry ) {
        print "Specify full or partial entry: ";
        $new_entry = <>;
        chomp $new_entry;
        $new_entry =~ s/\r$//;
    }

    return unless ( $new_entry );
    my @entry_parts = split /,/, $new_entry;

    unless ( $entry_parts[0] =~ m/^(.*@.*)$/ ) {
        die "invalid email address [$entry_parts[0]]\n";
    }
    $entry_parts[0] =~ s/^\s+//g;
    $entry_parts[0] =~ s/\s+$//g;
    $entry_parts[0] = lc $entry_parts[0];

    if ( ! $entry_parts[1] ) {
        print "specify type: ";
        $entry_parts[1] = <>;
        chomp $entry_parts[1];
        $entry_parts[1] =~ s/\r$//;
        if ( ! $entry_parts[1] ) {
            $entry_parts[1] = "A";
        }
    }
    unless ( $entry_parts[1] =~ m/^([ABCDE]+)$/ ) {
        die "invalid type [$entry_parts[1]]\n";
    }

    if ( ! $entry_parts[2] ) {
        print "specify date: ";
        $entry_parts[2] = <>;
        chomp $entry_parts[2];
        $entry_parts[2] =~ s/\r$//;
        if ( ! $entry_parts[2] ) {
            my @time = localtime();
            $time[3] = sprintf("%02d",$time[3]);
            $time[4] = sprintf("%02d",++$time[4]);
            $time[5] += 1900;
            $entry_parts[2] = $time[5] . $time[4] . $time[3];
        }
    }
    unless ( $entry_parts[2] =~ m/^(\d{8})$/ ) {
        die "invalid date [$entry_parts[2]]\n";
    }

    if ( ! $List{'entries'}{$entry_parts[0]} ) {
        $List{'entries'}{$entry_parts[0]}{'date'} = $entry_parts[2];
        for ( split //, $entry_parts[1] ) {
            $List{'entries'}{$entry_parts[0]}{'types'}{$_} = 1;
        }
    }
    else {
        if ( 
            $List{'entries'}{$entry_parts[0]}{'types'}
                and
            ! $List{'entries'}{$entry_parts[0]}{'types'}{$entry_parts[1]}
        ) {
            $List{'entries'}{$entry_parts[0]}{'types'}{$entry_parts[1]} = 1;
        }
        if ( 
            $List{'entries'}{$entry_parts[0]}{'date'}
                and 
            $List{'entries'}{$entry_parts[0]}{'date'} < $entry_parts[2] 
        ) {
            $List{'entries'}{$entry_parts[0]}{'date'} = $entry_parts[2];
        }
    }

    return 1;
}

# writes addresses from hash to file
sub write_list_file {
    my $tmp_list_file = $List_File.".tmp";
    if ( -e $tmp_list_file ) {
        unlink $tmp_list_file or die "can't remove existing $tmp_list_file: $!\n";
    }
    open my $tmp_list_fh, ">", $tmp_list_file or die "can't open $tmp_list_file: $!\n";

    print $tmp_list_fh $List{'header'};
    foreach my $address ( sort keys %{$List{'entries'}} ) {
        my $entry_to_add = join(
            ',',
            $address,
            join(
                '',
                sort keys %{$List{'entries'}{$address}{'types'}}
            ),
            $List{'entries'}{$address}{'date'}
        );
        print $tmp_list_fh $entry_to_add."\n";
    }
    close $tmp_list_fh;

    rename $tmp_list_file, $List_File or die "can't rename $tmp_list_file to $List_File: $!\n";
}

