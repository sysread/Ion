package Ion::Channel;

use common::sense;
use AnyEvent;
use Carp;

use constant QUEUE    => 0;
use constant WATCHERS => 1;
use constant OPEN     => 2;

sub new {
  my ($class) = @_;
  return bless [[], [], 1], $class;
}

sub size {
  my $self = shift;
  return scalar @{$self->[QUEUE]};
}

sub put {
  my ($self, $item) = @_;
  push @{$self->[QUEUE]}, $item;
  $self->_run;
  return $self->size;
}

sub get {
  my $self = shift;

  if ($self->[OPEN]) {
    my $ready = AnyEvent->condvar;
    push @{$self->[WATCHERS]}, $ready;

    $self->_run;
    return $ready->recv;
  }
  else {
    return shift @{$self->[QUEUE]};
  }
}

sub shutdown {
  my $self = shift;
  $self->[OPEN] = 0;
  $self->_run;
}

sub _run {
  my $self     = shift;
  my $queue    = $self->[QUEUE];
  my $watchers = $self->[WATCHERS];

  while (@$watchers && @$queue) {
    my $watcher = shift @$watchers;
    $watcher->send(shift @$queue);
  }

  unless ($self->[OPEN]) {
    while (@$watchers) {
      my $watcher = shift @$watchers;
      $watcher->send;
    }
  }
}

1;
