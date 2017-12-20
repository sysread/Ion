#!perl

use feature 'say';
use common::sense;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);
#use Keyword::Declare {debug => 1};
use Ion::Macro;

sub task (&$){ [@_] }

my $count = shift @ARGV || 10;

Remote $conn 'localhost' 4242 {
  # Encode messages out
  Encode { Dump($_[0])->Purity(1)->Declare(1)->Indent(0)->Out };
  Encode { encode_base64($_[0], '') };

  # Decode messages in
  Decode { decode_base64($_[0]) };
  Decode { my $msg = eval $_[0]; $@ && die $@; $msg };

  say 'Connected to localhost:4242';

  foreach my $i (1 .. $count) {
    my $msg = task{ [$_[0], $_[0] * 2] } $i;

    Request $result $msg {
      my ($i, $n) = @$result;
      say "$i * 2 = $n";
    };
  }
};
