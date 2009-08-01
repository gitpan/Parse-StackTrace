package Parse::StackTrace::Type::GDB;
use Moose;
use Parse::StackTrace::Exceptions;
use Math::BigInt;

extends 'Parse::StackTrace';

our $VERSION = '0.06';

our $WHITESPACE_ONLY = qr/^\s*$/;

use constant HAS_TRACE => qr/
    ^\#\d+\s+                             # #1
    (?:
        (?:0x[A-Fa-f0-9]{4,}\s+in\b)      # 0xdeadbeef in
        |
        (?:[A-Za-z]\S+\s+\()              # some_function_name
        |
        (?:<signal \s handler \s called>)
    )
/mx;
use constant BIN_REGEX => qr/(?:Backtrace|Core) was generated (?:from|by) (?:`|')(.+)/;
                                        #1num   #2name
use constant THREAD_START_REGEX => (
    qr/^Thread (\d+) \((.*)\):$/,
    qr/^\[Switching to Thread (.+) \((.+)\)\]$/,
);

use constant IGNORE_LINES => (
    'No symbol table info available.',
    'No locals.',
    '---Type <return> to continue, or q <return> to quit---',
);

# If we just have the default thread, return it when asked for Thread 1.
sub thread_number {
    my $self = shift;
    my ($number) = @_;
    if (scalar @{ $self->threads } == 1 and !$self->threads->[0]->has_number
        and $number == 1)
    {
        return $self->threads->[0];
    }
    return $self->SUPER::thread_number(@_)
}

# The most common parsing error during testing was that traces would be
# malformed with extra newlines in the "args" section.
sub _get_next_trace_line {
    my $self = shift;
    my $line = $self->SUPER::_get_next_trace_line(@_);
    # Check if the line contains an open-paren but no close-paren after it.
    if ($line =~ /\([^\)]*$/) {
        my ($lines) = @_;
        my $next_line = $lines->[0];
        
        if (defined $next_line){
            # If the next line is blank...
            if ($next_line =~ $WHITESPACE_ONLY) {
                # Then get rid of it and continue with the next line.
                shift @$lines;
                unshift(@$lines, $line);
                return $self->_get_next_trace_line(@_);
            }
            # If the next line is an end to this frame, then we just have
            # a really bad trace that we should try to deal with anyway by
            # closing the parens.
            if ($self->_next_line_ends_frame($next_line)) {
                $line .= ')';
            }
        }
    }
    return $line;
}

# We also want to ignore any lines containing gdb commands.
sub _ignore_line {
    my $class = shift;
    my $result = $class->SUPER::_ignore_line(@_);
    return $result if $result;
    my ($line) = @_;
    return $line =~ /^\(gdb\) / ? 1 : 0;
}

sub _line_starts_thread {
    my ($class, $line) = @_;
    foreach my $re (THREAD_START_REGEX) {
        if ($line =~ $re) {
            my ($number, $desc) = ($1, $2);
            if ($number =~ /^0x/) {
                # Greater than 0xffffffff needs to be a BigInt for portability.
                if (length($number) > 10) {
                    $number = Math::BigInt->new($number);
                }
                else {
                    $number = hex($number);
                }
            }
            return ($number, $desc);
        }
    }
    return ();
}

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