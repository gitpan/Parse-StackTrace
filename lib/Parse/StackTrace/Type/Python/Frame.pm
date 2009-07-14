package Parse::StackTrace::Type::Python::Frame;
use Moose;
use Data::Dumper;

extends 'Parse::StackTrace::Frame';
                                          #1file        #2line      #3func  #4line_detail
use constant FRAME_REGEX => qr/^\s*File\s"(.+)",\sline\s(\d+),\sin\s(\S+)\s+(.*)$/;

sub parse {
    my ($class, %params) = @_;
    my $text = $params{'text'};
    my $debug = $params{'debug'};
    my %parsed;
    
    if ($text =~ FRAME_REGEX) {
        %parsed = (file => $1, line => $2, function => $3, code => $4);
    }
    else {
        Parse::StackTrace::Exception::NotAFrame->throw(
            "Not a valid Python stack frame: $text"
        );
    }
   
    print STDERR "Parsed As: " . Dumper(\%parsed) if $debug;
    return $class->new(%parsed);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace::Type::Python::Frame - A frame from a Python stack trace

=head1 DESCRIPTION

This is an implementation of L<Parse::StackTrace::Frame>.

Python frames always have a C<file>, C<line>, C<function>, and C<code>
specified, and nothing else specified.