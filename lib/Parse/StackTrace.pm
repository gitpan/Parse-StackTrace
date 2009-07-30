package Parse::StackTrace;
use 5.006;
use Moose;
use Parse::StackTrace::Exceptions;
use Exception::Class;
use Scalar::Util qw(blessed);

our $VERSION = '0.03';

has 'threads' => (is => 'ro', isa => 'ArrayRef[Parse::StackTrace::Thread]',
                  required => 1);
has 'binary'  => (is => 'ro', isa => 'Str|Undef');

#####################
# Parsing Functions #
#####################

sub parse {
    my $class = shift;
    # If you call parse() directly on this class, then we use the "type"
    # parameter to determine what type of StackTrace we're parsing.
    if ($class eq 'Parse::StackTrace') {
        my %params = @_;
        my $types = $params{'types'};
        die "You must specify trace types" if !$types || !scalar @$types;
        my $trace;
        foreach my $type (@$types) {
            my $parser = $class->_class("Type::$type");
            $trace = eval { $parser->parse(@_) };
            if (Exception::Class->caught('Parse::StackTrace::Exception::NoTrace')) {
                next;
            }
            elsif (my $e = Exception::Class->caught) {
                blessed $e ? $e->rethrow : die $e;
            }
            return $trace;
        }
        
        return undef;
    }
    
    # For subclasses
    return $class->_do_parse(@_);
}

sub _do_parse {
    my ($class, %params) = @_;
    my $text  = $params{text};
    my $debug = $params{debug};
    if (!$text =~ $class->HAS_TRACE) {
        Parse::StackTrace::Exception::NoTrace->throw(
            "This doesn't look like a stack trace."
        );
    }
    
    my $binary;
    if ($class->BIN_REGEX and $text =~ $class->BIN_REGEX) {
        $binary = $1;
    }

    my $threads = $class->_parse_text($text, $debug);
    my $trace = $class->new(threads => $threads, binary => $binary);
    return $trace;
}

sub _get_trace_start {
    my ($class, $lines) = @_;
    my $count = 0;
    foreach my $line (@$lines) {
        if ($line =~ $class->HAS_TRACE) {
            return $count;
        }
        $count++;
    }
}

sub _parse_text {
    my ($class, $text, $debug) = @_;
   
    my @lines = split(/\r?\n/, $text);
    my @threads;
    my $current_thread = $class->thread_class->new();
    print STDERR "Current Thread: Default\n" if $debug;
    while (scalar @lines) {
        my $line = $class->_get_next_trace_line(\@lines);
        print STDERR "Next Trace Line: [$line]\n" if $debug;
        next if (trim($line) eq '' or grep($_ eq $line, $class->IGNORE_LINES));
        $current_thread = $class->_handle_line(
            line => $line, thread => $current_thread,
            threads => \@threads, debug => $debug, lines => \@lines);
    }
    
    @threads = ($current_thread) if not @threads;
    @threads = sort { ($a->number || 0) <=> ($b->number || 0) } @threads;
    return \@threads;
}

sub _handle_line {
    my ($class, %params) = @_;
    my ($line, $current_thread, $threads, $debug) =
        @params{qw(line thread threads debug)};
        
    if ($class->THREAD_START and $line =~ $class->THREAD_START) {
        $current_thread = $class->thread_class->new(number => $1,
                                                    description => $2);
        push(@$threads, $current_thread);
        print STDERR "Current Thread: " . $current_thread->number . "\n"
            if $debug;
    }
    elsif ($line =~ $class->HAS_TRACE) {
        my $frame = $class->frame_class->parse(text => $line, debug => $debug);
        $current_thread->add_frame($frame);
    }
    
    return $current_thread;
}

sub _get_next_trace_line {
    my ($class, $lines) = @_;
    my $line = shift @$lines;
    if ($line =~ $class->HAS_TRACE) {
        while (@$lines) {
            my $next_line = $class->_get_next_frame_line($lines);
            last if not $next_line;
            $line = "$line $next_line";
        }
    }
    
    return $line;
}

# Returns the next line only if it's a *fragment* of a stack frame.
# If it's the start of a new frame, a new thread, or a line that we
# ignore, then we return nothing.
sub _get_next_frame_line {
    my ($class, $lines) = @_;
    my $line = $lines->[0];
    if (trim($line) eq '' or grep($_ eq $line, $class->IGNORE_LINES)
        or $line =~ $class->HAS_TRACE
        or ($class->THREAD_START and $line =~ $class->THREAD_START))
    {
        return undef
    }
    return shift @$lines
}

#####################
# Complex Accessors #
#####################

sub thread_number {
    my ($self, $number) = @_;
    # First check if the frame at that array position (minus one, because
    # threads are numbered from 1) is the frame we want, as an optimization.    
    my $try = $self->threads->[$number - 1];
    if ($try && $try->number && $try->number == $number) {
        return $try;
    }
    my ($thread) = grep { defined $_->number and $_->number == $number }
                        @{ $self->threads };
    return $thread;
}

#####################
# Utility Functions #
#####################
    
sub trim {
    my ($string) = @_;
    $string =~ s/\s+$//;
    $string =~ s/^\s+//;
    return $string;
}

####################
# Subclass Helpers #
####################

sub thread_class { return shift->_class('Thread') }
sub frame_class  { return shift->_class('Frame')  }

sub _class {
    my ($invocant, $what) = @_;
    my $class = ref $invocant || $invocant;
    my $module = $class . '::' . $what;
    my $file = $module;
    $file =~ s{::}{/}g;
    eval { require "$file.pm" }
        || die("Error requiring $module: $@");
    return $module;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace - Parse the text representation of a stack trace into an
object.

=head1 SYNOPSIS

 my $trace = Parse::StackTrace->parse(types => ['GDB', 'Python'],
                                      text => $text,
                                      debug => 1);
 my $thread = $trace->thread_number(1);
 my $frame = $thread->frame_number(0);

=head1 DESCRIPTION

This module parses stack traces thrown by different types of languages
and converts them into an object that you can use to get information
about the trace.

If the text you're parsing could contain different types of
stack traces, then you should call L</parse> in this module to parse
your text. (So, you'd be calling C<< Parse::StackTrace->parse >>.)

Alternately, if you know you just want to parse one type of trace (say,
just GDB traces) you can call C<parse()> on the Type class you want.
For example, if you just want to parse GDB traces, you could call
C<< Parse::StackTrace::Type::GDB->parse >>. The only difference between
the Type-specific C<parse> methods and L</parse> in this module is
that the Type-specific C<parse> methods don't take a C<types> argument.

=head1 PARTS OF A STACK TRACE

Stack traces have two main components: L<Threads|Parse::StackTrace::Thread>
and L<Frames|Parse::StackTrace::Frame>. A running program can have multiple
threads, and then each thread has a "stack" of functions that were called.
Each function is a single "frame". A frame also can contain other
information, like what arguments were passed to the function, or what
code file the frame's function is in.

You access Threads by calling methods on the returned StackTrace object
you get from L</parse>.

You access Frames by calling methods on Threads.

=head1 EXCEPTIONS

Parse::StackTrace uses L<Exception::Class> to throw errors. Each method
will specify what exceptions it can throw.

=head1 CLASS METHODS

=head2 C<parse>

=over

=item B<Description>

Takes a block of text, and if there are any valid stack traces in that
block of text, it will find the first one and return it.

=item B<Parameters>

This method takes the following named parameters:

=over

=item C<text>

A string. The block of text that you want to find a stack trace in.

=item C<types>

An arrayref containing strings. These are the types of traces that you
want to find in the block. Traces are searched for in the order specified,
so if there is a trace of the first type in the list, inside the text, then
the second type in the list will be ignored, and so on.

Currently valid types are: C<GDB>, C<Python>

Types are case-sensitive.

=item C<debug>

Set to 1 if you want the method to output detailed information about
its parsing.

=back

=item B<Returns>

An object that is a subclass of Parse::StackTrace, or C<undef> if no
traces of any of the specified types were found in the list.

=item B<Throws>

C<Parse::StackTrace::Exception::NotAFrame> - If there is an error during
parsing.

C<Parse::StackTrace::Exception::NoTrace> - Thrown by subclass implementations
of C<parse> when they don't detect any stack trace in the parsed text.
However, when you call I<this> implementation of parse
(C<< Parse::StackTrace->parse >>, not something like
C<< Parse::StackTrace::Type::GDB->parse >>), it doesn't throw this
exception--it just returns C<undef> when there are no traces of any type
found.

=back


=head1 INSTANCE ATTRIBUTES

These are methods of Parse::StackTrace objects that return data.
You should always call them as methods (never like
C<< $object->{attribute} >>).

=head2 C<binary>

Some stack traces contain information on what binary threw the stack trace.
If the parsed trace had that information, this will be a string specifying
the binary that threw the stack trace. If this information was not in
the stack trace, then this will be C<undef>.

=head2 C<threads>

An arrayref of L<Parse::StackTrace::Thread> objects, representing the
threads in the trace. Sometimes traces have only one thread, in which
case that will simply be C<< threads->[0] >>.

The threads will be in the array in the order that they were listed
in the trace.

There is always at least one thread in every trace.

=head1 INSTANCE METHODS

These are additional methods to get information about the stacktrace.

=head2 C<thread_number>

Takes a single integer argument. Returns the thread with that number, from
the L</threads> array. Thread numbering starts at 1, not at 0 (because this
is how GDB does it, and GDB was our first implementation).

Note that if you want a particular-numbered thread, you should use
this method, not L</threads>, because it's possible somebody could have
a stack trace with the threads out of order, in which case C<< threads->[0] >>
would not be "Thread 1".

=head1 SEE ALSO

The various parts of a stack trace:

=over

=item L<Parse::StackTrace::Thread>

=item L<Parse::StackTrace::Frame>

=back

The different types of stack traces we can parse (which have special methods
for the specific sort of data available in those traces that aren't available
in all traces):

=over

=item L<Parse::StackTrace::Type::GDB>

=item L<Parse::StackTrace::Type::Python>

=back

=head1 TODO

Eventually we should be able to parse out multiple stack traces from
one block of text. (This will be the list-context return of L</parse>.)

=head1 BUGS

This module has currently received only limited testing, so it might
die or fail on certain unexpected input.

=head1 AUTHOR

Max Kanat-Alexander <mkanat@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 Canonical Ltd.

This library (the entirety of Parse-StackTrace) is free software;
you can redistribute it and/or modify it under the same terms as Perl
itself.
