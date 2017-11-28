package Ion::Server;

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
  '&{}'    => '_coderef',
  fallback => 1,
);

with 'Ion::Role::Socket';

has guard  => (is => 'rw', clearer => 1);
has handle => (is => 'rw', clearer => 1);
has queue  => (is => 'rw', clearer => 1, default => sub{ Coro::Channel->new });
has conn   => (is => 'rw', default => sub{ {} });

sub DEMOLISH {
  my $self = shift;
  $self->stop;
}

sub accept {
  my $self = shift;
  $self->queue->get;
}

sub start {
  my ($self, $port, $host) = @_;
  $self->stop if $self->handle;
  $self->queue(Coro::Channel->new) unless $self->queue;

  my $guard = tcp_server $host, $port,
    sub {
      my ($fh, $host, $port) = @_;
      return unless $fh;

      my $conn = Ion::Conn->new(
        host   => $host,
        port   => $port,
        handle => unblock($fh),
      );

      $self->queue->put($conn);
    },
    rouse_cb;

  weaken $self;

  my @sock = rouse_wait;
  $self->handle(unblock(shift @sock));
  $self->host(shift @sock);
  $self->port(shift @sock);
  $self->guard($guard);

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

  return 1;
}

sub _coderef {
  my $self = shift;
  sub { $self->accept };
}

1;
