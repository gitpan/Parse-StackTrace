package Parse::StackTrace::Exceptions;
use strict;
use Exception::Class (
    'Parse::StackTrace::Exception',
    
    'Parse::StackTrace::Exception::NoTrace' =>
    { isa => 'Parse::StackTrace::Exception' },
    
    'Parse::StackTrace::Exception::NotAFrame' =>
    { isa => 'Parse::StackTrace::Exception' },

);

1;

__END__

=head1 NAME

Parse::StackTrace::Exceptions - Exceptions that can be thrown by
Parse::StackTrace modules

=head1 DESCRIPTION

Parse::StackTrace uses L<Exception::Class> to throw exceptions.

The base class for all exceptions thrown by Parse::StackTrace is
C<Parse::StackTrace::Exception>

=head1 EXCEPTIONS

=head2 Parse::StackTrace::Exception::NoTrace

Thrown by a Type-specific parser (for example, the GDB parser or the Python
parser) when you have asked it to parse a block of text where there are no
traces of this type.