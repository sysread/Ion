package Ion::Conn;
# ABSTRACT: An Ion TCP socket connection

use common::sense;

use Moo;
use Carp;
use Coro;
use AnyEvent::Socket qw(tcp_connect);
use Coro::Handle qw(unblock);

use overload (
  '<>'     => 'readline',
  '&{}'    => '_coderef',
  fallback => 1,
);

with 'Ion::Role::Socket';

has guard  => (is => 'rw', clearer => 1);
has handle => (is => 'rw', clearer => 1);

sub BUILD {
  my $self = shift;

  unless ($self->handle) {
    my $host  = $self->host || croak 'host is required when handle is not specified';
    my $port  = $self->port || croak 'port is required when handle is not specified';
    my $guard = tcp_connect($host, $port, rouse_cb);
    my ($fh, @param) = rouse_wait;
    $self->handle(unblock $fh);
    $self->guard($guard);
  }
}

sub DEMOLISH {
  my $self = shift;
  $self->close;
}

sub print {
  my ($self, $msg) = @_;
  $self->handle->print($msg . $/);
}

sub readline {
  my $self = shift;
  my $line = $self->handle->readline or return;
  chomp $line;
  return $line;
}

sub close {
  my $self = shift;
  return unless $self->guard;

  $self->clear_guard;

  $self->handle->shutdown;
  $self->handle->close;
  $self->clear_handle;
}

sub _coderef {
  my $self = shift;
  sub { $self->print(shift) };
}

1;

=head1 METHODS

=head2 print

Writes data to the socket. The line is automatically appended with the value of
C<$/>.

=head2 readline

Returns the next line of data received on the socket. This method will cede
control of the thread until a complete line is available. The value will have
already been chomped to remove the line terminator (C<$/>).

=head2 close

Closes the socket. After calling this method, the connection object may not be
reopened.

=head1 OVERLOADED OPERATORS

=head2 <>

Calls L</readline>.

=head2 ${} (e.g. C<$conn->($data)>)

Calls L</print>.

=cut
