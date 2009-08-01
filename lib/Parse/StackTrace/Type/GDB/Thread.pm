package Parse::StackTrace::Type::GDB::Thread;
use Moose;

extends 'Parse::StackTrace::Thread';

sub add_frame {
    my $self = shift;
    my ($frame) = @_;
    $self->SUPER::add_frame(@_);
}

sub frame_with_crash {
    my ($self) = @_;
    my ($frame) = grep { $_->function eq '<signal handler called>' }
                       @{ $self->frames };
    return $frame;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Parse::StackTrace::Type::GDB::Thread - A thread from a GDB stack trace

=head1 DESCRIPTION

This is a straightforward implementation of L<Parse::StackTrace::Thread>,
with nothing special about it.