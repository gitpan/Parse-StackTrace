package Parse::StackTrace::Type::GDB::Frame;
use Moose;
use Parse::StackTrace::Exceptions;
use Data::Dumper;

extends 'Parse::StackTrace::Frame';

has 'memory_location' => (is => 'ro', isa => 'Str');
has 'lib_tag'         => (is => 'ro', isa => 'Str');
has 'library'         => (is => 'ro', isa => 'Str');

use constant FRAME_REGEX => qr/
    ^\# (\d+)                          # 1 level
    \s+ (?:(0x[A-Fa-f0-9]+)\s+in\s+)?  # 2 location
        ([^\@\s]+)                     # 3 function
        (?:\@+([A-Z]+_[\d\.]+))?       # 4 libtag
    \s* \(([^\)]*)\)                   # 5 args
    \s* (?:from\s(\S+))?               # 6 library
    \s* (?:at\s+([^:]+)                # 7 file
    :   (\d+))?                        # 8 line
/x;

sub parse {
    my ($class, %params) = @_;
    my $text = $params{'text'};
    my $debug = $params{'debug'};
    my %parsed;
    
    if ($text =~ FRAME_REGEX) {
        %parsed = (number => $1, memory_location => $2,
                   function => $3, lib_tag => $4, args => $5,
                   library => $6, file => $7, line => $8);
    }
    elsif ($text =~ /^#(\d+)\s+(<signal handler called>)/) {
        %parsed = (number => $1, function => $2);
    }
    
    if (!%parsed) {
        Parse::StackTrace::Exception::NotAFrame->throw(
            "Not a valid GDB stack frame: $text"
        );
    }
    
    foreach my $key (keys %parsed) {
        delete $parsed{$key} if !defined $parsed{$key};
    }
    print STDERR "Parsed As: " . Dumper(\%parsed) if $debug;
    return $class->new(%parsed);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace::Type::GDB::Frame - A GDB stack frame

=head1 DESCRIPTION

This is an implementation of L<Parse::StackTrace::Frame> for GDB.

Note that GDB frames never have a value for the C<code> accessor, but
they B<might> have values for all the other accessors.

For frames where the function is unknown, the function will be C<??>
(because that's what GDB prints out in that case).

=head1 METHODS

In addition to the methods available from L<Parse::StackTrace::Frame>,
GDB frames possibly have additional information. All of these
are C<undef> if they are not available for this Frame.

=head2 C<memory_location>

Almost all frames contain a hexidecimal memory address where that
frame resides. This is that address, as a string starting with C<0x>

=head2 C<lib_tag>

Some stack frames have a piece of text like C<@GLIBC_2.3.2> after the
function name. This is the C<GLIBC_2.3.2> part of that.

=head2 C<library>

Some stack frames contain the filesystem path to the dynamic library
that the binary code of this function lives in. This is a string
representing that filesystem path.