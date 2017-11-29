#!perl

use common::sense;
use Ion;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);
use Coro::ProcessPool;

my $pool = Coro::ProcessPool->new(max_procs => 4);

sub encode {
  encode_base64(Dump(\@_)->Purity(1)->Declare(1)->Indent(0)->Out, '');
}

sub decode {
  my $line = shift || return;
  my $msg  = eval decode_base64($line);
  $@ && die $@;
  return @$msg;
}

my $service = Service {
  my $result = $pool->process(decode(shift));
  return encode($result);
} 4242;

$service->join;
