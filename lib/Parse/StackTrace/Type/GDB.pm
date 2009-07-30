package Parse::StackTrace::Type::GDB;
use Moose;
use Parse::StackTrace::Exceptions;

extends 'Parse::StackTrace';

our $VERSION = '0.04';

use constant HAS_TRACE => qr/^#\d+(?:\s+(?:0x[A-Fa-f0-9]+ in )?(?:\S+\s+\(|\?\?))|(?:<signal handler called>)/m;
use constant BIN_REGEX => qr/(?:Backtrace|Core) was generated (?:from|by) (?:`|')(.+)/;
                                        #1num   #2name
use constant THREAD_START => qr/^Thread (\d+) \((.*)\):$/;

use constant IGNORE_LINES => (
    'No symbol table info available.',
    'No locals.',
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace::Type::GDB - A stack trace produced by GDB, the GNU
Debugger

=head1 DESCRIPTION

This is an implementation of L<Parse::StackTrace> for GDB traces.

The parser assumes that the text it is parsing contains only one
stack trace, so all detected threads and frames are part of a single
trace.

GDB stack traces come in various levels of quality (some have threads,
some don't, some have symbols, some don't, etc.). The parser deals with
that just fine, but you should not expect all fields of threads and
frames to always be populated.

=head1 SEE ALSO

=over

=item L<Parse::StackTrace::Type::GDB::Thread>

=item L<Parse::StackTrace::Type::GDB::Frame>

=back