#!/usr/bin/perl
use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 22;

use Support qw(test_trace);

use constant TRACES => {
    # Multiple Threads, No Symbols, Signal Handler
    'ekiga-bug-364113' => {
        threads => 10,
        thread  => 1,
        frames  => 24,
        crash_frame => 3,
        description => 'Thread -1247730000 (LWP 5645)',
    },
    # Single Thread, Symbols, Signal Handler
    'gnumeric-bug-127364' => {
        threads => 1,
        thread  => 1,
        frames  => 42,
        crash_frame => 5,
        description => 'Thread 16384 (LWP 9708)',
    },
};

foreach my $file (sort keys %{ TRACES() }) {
    test_trace('GDB', $file, TRACES->{$file});
}

