#!perl

use feature 'say';
use common::sense;

use Coro;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);

# Define the subroutine to call remotely before locaing Ion::Macro to prevent
# Data::Dump::Streamer from attempting to include macro definitions in the
# serialized lexical scope.
sub double {
  my $n = shift;
  return [$n, $n * 2];
}

use Ion::Macro;

my $count = shift @ARGV || 10;
my $pending = Coro::Semaphore->new(0);

Remote 'localhost' 4242 {
  # Encode messages out
  Encode { Dump(shift)->Purity(1)->Declare(1)->Indent(0)->Out };
  Encode { encode_base64(shift, '') };

  # Decode messages in
  Decode { decode_base64($_[0]) };
  Decode { my $msg = eval $_[0]; $@ && die $@; $msg };

  say 'Connected to localhost:4242';

  foreach my $i (1 .. $count) {
    Send [\&double, $i] {
      my ($q, $a) = @$_;
      say "[$i] $q * 2 = $a";
      $pending->up;
    };
  }
};

$pending->down for 1 .. $count;
