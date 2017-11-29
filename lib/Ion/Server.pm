package Ion::Server;
# ABSTRACT: An Ion TCP service

use common::sense;

use Moo;
use Carp;
use Coro;
use AnyEvent::Socket qw(tcp_server);
use Coro::Handle qw(unblock);
use Scalar::Util qw(weaken);
use Ion::Conn;

use overload (
  '<>'     => 'accept',
  fallback => 1,
);

with 'Ion::Role::Socket';

has guard  => (is => 'rw', clearer => 1);
has handle => (is => 'rw', clearer => 1);
has queue  => (is => 'rw', clearer => 1, default => sub{ Coro::Channel->new });
has conn   => (is => 'rw', default => sub{ {} });
has cond   => (is => 'rw');

sub DEMOLISH {
  my $self = shift;
  $self->stop;
}

sub accept {
  my $self = shift;
  my $args = $self->queue->get;
  my ($fh, $host, $port) = @$args;
  return unless $fh;
  Ion::Conn->new(host => $host, port => $port, handle => unblock($fh));
}

sub start {
  my ($self, $port, $host) = @_;
  $self->stop if $self->handle;
  my $queue = $self->queue || Coro::Channel->new;

  my $guard = tcp_server(
    $host || $self->host,
    $port || $self->port,
    sub{ $queue->put([@_]) },
    rouse_cb
  );

  weaken $queue;

  my @sock = rouse_wait;
  $self->handle(unblock(shift @sock));
  $self->host(shift @sock);
  $self->port(shift @sock);
  $self->guard($guard);
  $self->queue($queue);
  $self->cond(rouse_cb);

  return 1;
}

sub stop {
  my $self = shift;
  return unless $self->guard;

  $self->queue->shutdown;
  $self->clear_queue;

  $self->clear_guard;

  $self->handle->shutdown;
  $self->handle->close;
  $self->clear_handle;

  $self->cond->();

  return 1;
}

sub join {
  my $self = shift;
  rouse_wait($self->cond);
  return 1;
}

1;

=head1 METHODS

=head2 start

Starts the listening socket. Optionally accepts a port number and host
interface on which to listen. If left unspecified, these will be assigned by
the operating system.

=head2 stop

Stops the listener and shuts down the incoming connection queue.

=head2 join

Cedes control until L</stop> is called.

=head2 port

Returns the listening port of a L<started|/start> service.

=head2 host

Returns the host interface of a L<started|/start> service.

=head2 accept

Returns the next incoming connection. This method will block until a new
connection is received.

=head1 OVERLOADED OPERATORS

=head2 <>

Calls L</accept>.

=cut
