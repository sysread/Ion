#!perl

use feature 'say';
use common::sense;
use Coro::ProcessPool;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);
use Try::Tiny;
use Ion::Macro;

my $pool = Coro::ProcessPool->new(max_procs => 4);

Listen 4242 {
  # Encode messages out
  Encode { Dump(shift)->Purity(1)->Declare(1)->Indent(0)->Out };
  Encode { encode_base64(shift, '') };

  # Decode messages in
  Decode { decode_base64($_[0]) };
  Decode { my $msg = eval $_[0]; $@ && die $@; $msg };

  my $host = $_->host;
  my $port = $_->port;
  say "Service started on $host:$port";

  Accept {
    Respond {
      try   { $pool->process(@$_) }
      catch { [undef, $_] };
    }
  }
}
