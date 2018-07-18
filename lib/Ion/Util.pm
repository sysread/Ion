package Ion::Util;
# ABSTRACT: Helpers to make Ion more Util

use common::sense;
use Coro;

use parent 'Exporter';

our @EXPORT = qw(
  gen
);

sub gen (&) {
  my $fn  = shift;
  my $in  = Coro::Channel->new;
  my $out = Coro::Channel->new;

  my $gen = async_pool{
    my ($in, $out) = @_;
    while (my $msg = $in->get) {
      $out->put($fn->(@$msg));
    }
  } $in, $out;

  return sub{
    $out->put(@_);
    $in->get;
  };
}


1;
