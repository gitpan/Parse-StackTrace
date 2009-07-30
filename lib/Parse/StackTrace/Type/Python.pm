package Parse::StackTrace::Type::Python;
use Moose;

extends 'Parse::StackTrace';

our $VERSION = '0.03';

use constant HAS_TRACE => qr/^\s*File\s".+",/ms;
use constant EXCEPTION_REGEX => qr/^\S*(?:Error|Exception):\s+.+$/;

use constant BIN_REGEX => '';
use constant THREAD_START => '';
use constant IGNORE_LINES => ();

sub thread_number {
    my ($self, $number) = @_;
    return $self->threads->[0] if $number == 1;
    return undef;
}

sub _handle_line {
    my $class = shift;
    my %params = @_;
    my ($line, $current_thread, $lines, $debug) =
        @params{qw(line thread lines debug)};
    # If we have frames and run into the description of the exception,
    # then we're done parsing the trace.
    if (scalar @{ $current_thread->frames } and $line =~ EXCEPTION_REGEX) {
        $current_thread->{description} = $line;
        print STDERR "Thread Exception: $line\n" if $debug;
        # Don't parse anymore.
        @$lines = ();
        return $current_thread;
    }
    
    return $class->SUPER::_handle_line(@_);
}

sub _get_next_frame_line {
    my $class = shift;
    my ($lines) = @_;
    my $line = $class->SUPER::_get_next_frame_line(@_);
    # Don't include the exception line in a frame, and unshift it
    # back onto the array for _handle_line to deal with.
    if (defined $line and $line =~ EXCEPTION_REGEX) {
        unshift(@$lines, $line);
        return undef;
    }
    return $line;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace::Type::Python - A stack trace produced by python

=head1 DESCRIPTION

This is an implementation of L<Parse::StackTrace> for Python tracebacks.

The parser will only parse the I<first> Python stack trace it finds in
a block of text, and then stop parsing.

=head1 SEE ALSO

=over

=item L<Parse::StackTrace::Type::Python::Thread>

=item L<Parse::StackTrace::Type::Python::Frame>

=back