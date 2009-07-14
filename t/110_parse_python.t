#!/usr/bin/perl
use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 33;

use Support qw(test_trace);

use constant TRACES => {
    'bugbot' => {
        threads => 1,
        thread  => 1,
        frames  => 6,
        crash_frame => 0,
        description => 'Error: timed out',
    },
    # Frames split across lines
    'deskbar-bug-467629' => {
        threads => 1,
        thread  => 1,
        frames  => 2,
        crash_frame => 0,
        description => 'TypeError: could not parse URI',
    },
};

foreach my $file (sort keys %{ TRACES() }) {
    test_trace('Python', $file, TRACES->{$file});
}

# This is a file that has the "bugbot" trace and then another
# trace later down. This makes sure that we only parse the first trace.
test_trace('Python', 'bugbot-multiple', TRACES->{'bugbot'});

