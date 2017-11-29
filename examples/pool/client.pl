#!perl

use feature 'say';
use common::sense;
use Data::Dump::Streamer;
use MIME::Base64 qw(encode_base64 decode_base64);
use Ion;

sub encode {
  encode_base64(Dump(\@_)->Purity(1)->Declare(1)->Indent(0)->Out, '');
}

sub decode {
  my $line = shift || return;
  my $msg  = eval decode_base64($line);
  $@ && die $@;
  return @$msg;
}

sub work {
  my $n = shift;
  return $n * 2;
}

my $client = Connect localhost => 4242;
my $count  = shift @ARGV || 10;

foreach my $i (1 .. $count) {
  $client->(encode(\&work, $i));
  my ($result) = decode(<$client>);
  say $i, ' * 2 = ', $result;
}
