package Ion::Server;
# ABSTRACT: An Ion TCP service

use common::sense;

use Carp;
use Coro;
use AnyEvent::Socket qw(tcp_server);
use Coro::Handle qw(unblock);
use Scalar::Util qw(weaken);
use Ion::Conn;

use overload (
  '<>'  => 'accept',
  '>>'  => 'encodes',
  '>>=' => 'encodes',
  '<<'  => 'decodes',
  '<<=' => 'decodes',
  fallback => 1,
);

sub new {
  my ($class, %param) = @_;
  return bless {
    host     => $param{host},
    port     => $param{port},
    guard    => undef,
    handle   => undef,
    cond     => undef,
    queue    => Coro::Channel->new,
    conn     => {},
    encoders => [],
    decoders => [],
  }, $class;
}

sub DESTROY {
  my $self = shift;
  $self->stop;
}

sub host { $_[0]->{host} }
sub port { $_[0]->{port} }

sub accept {
  my $self = shift;
  my $args = $self->{queue}->get;
  my ($fh, $host, $port) = @$args;
  return unless $fh;

  Ion::Conn->new(
    host     => $host,
    port     => $port,
    handle   => unblock($fh),
    encoders => $self->{encoders},
    decoders => $self->{decoders},
  );
}

sub start {
  my ($self, $port, $host) = @_;
  $self->stop if $self->{handle};
  $self->{queue} ||= Coro::Channel->new;

  my $guard = tcp_server(
    $host || $self->{host} || 0,
    $port || $self->{port} || 0,
    sub{ $self->{queue}->put([@_]) },
    rouse_cb
  );

  weaken $self;

  my @sock = rouse_wait;
  $self->{handle} = unblock(shift @sock);
  $self->{host}   = shift @sock;
  $self->{port}   = shift @sock;
  $self->{guard}  = $guard;
  $self->{cond}   = rouse_cb;

  return 1;
}

sub stop {
  my $self = shift;
  $self->{queue}->shutdown  if $self->{queue};
  $self->{handle}->shutdown if $self->{handle};
  $self->{handle}->close    if $self->{handle};
  $self->{cond}->()         if $self->{cond};
  undef $self->{queue};
  undef $self->{handle};
  undef $self->{guard};
  return 1;
}

sub join {
  my $self = shift;
  rouse_wait($self->{cond});
  return 1;
}

sub encodes {
  my ($self, $encoder) = @_;
  push @{$self->{encoders}}, $encoder;
  return $self;
}

sub decodes {
  my ($self, $decoder) = @_;
  push @{$self->{decoders}}, $decoder;
  return $self;
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

=head2 encodes

Adds a subroutine to process outgoing messages to clients of this server.
Encoder subs are applied in the order in which they are added.

=head2 decodes

Adds a subroutine to decode incoming messages from clients of this server.
Decoder subs are applied in the order in which they are added.

=head1 OVERLOADED OPERATORS

=head2 <>

Calls L</accept>.

=head2 >>, >>=

Calls L<encodes>.

=head2 <<, <<=

Calls L<decodes>.

=cut
