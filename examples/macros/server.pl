#!perl

use feature 'say';
use common::sense;
use Coro::ProcessPool;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);
#use Keyword::Declare {debug => 1};
use Ion::Macro;

my $pool = Coro::ProcessPool->new(max_procs => 4);

Listen $server 4242 {
  # Encode messages out
  Encode { Dump($_[0])->Purity(1)->Declare(1)->Indent(0)->Out };
  Encode { encode_base64($_[0], '') };

  # Decode messages in
  Decode { decode_base64($_[0]) };
  Decode { my $msg = eval $_[0]; $@ && die $@; $msg };

  my $host = $server->host;
  my $port = $server->port;
  say "Service started on $host:$port";

  Accept $conn {
    Respond $msg {
      $pool->process(@$msg);
    };
  }
}
