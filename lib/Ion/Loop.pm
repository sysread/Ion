package Ion::Loop;
# ABSTRACT: A coro with an in and out channel

use common::sense;
use Carp;
use Coro;

use parent 'Exporter';

our @EXPORT = qw(Loop);

sub Loop (&) {
  Ion::Loop->new($_[0]);
}

sub new {
  my ($class, $fn) = @_;
  bless {fn => $fn}, $class;
}

sub start {
  my $self = shift;
  return if $self->{gen};

  my $in  = Coro::Channel->new;
  my $out = Coro::Channel->new;

  my $gen = async_pool{
    my ($in, $out, $fn) = @_;

    while (defined(my $msg = $in->get)) {
      $out->put($fn->(@$msg));
    }

  } $in, $out, $self->{fn};

  $self->{in}  = $in;
  $self->{out} = $out;
  $self->{gen} = $gen;

  return;
}

sub stop {
  my $self = shift;

  if ($self->{gen}) {
    $self->{in}->shutdown;
    $self->{out}->shutdown;
    $self->{gen}->join;
    undef $self->{in};
    undef $self->{out};
    undef $self->{gen};
  }

  return;
}

sub put {
  my ($self, @args) = @_;
  $self->start;
  $self->{in}->put(\@args);
}

sub get {
  my $self = shift;
  $self->start;
  $self->{out}->get;
}

1;
