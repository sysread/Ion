BEGIN {
  # win32 child watcher support
  if ($^O =~ /mswin32/i) {
    my $ok;
    local $SIG{CHLD} = sub { $ok = 1 };
    kill 'CHLD', 0;

    unless ($ok) {
      print <<EOF;
1..0 # SKIP broken perl detected
EOF
      exit 0;
    }
  }

  # Signal support
  unless (exists $SIG{USR1}) {
    print <<EOF;
1..0 # SKIP broken perl detected
EOF
    exit 0;
  }

  require AnyEvent::Impl::Perl;
}

use Test2::V0;
use Coro;
use Coro::AnyEvent;
use Storable qw(freeze thaw);
use MIME::Base64 qw(encode_base64 decode_base64);
use Ion;

my $message = {foo => 'bar', baz => [1, 2, qq{
bat
  bat
    bat
      bat
    bat
  bat
bat
}]};

my ($request, $response);

my $server = Service{ $request = $_[0] }
  >> sub{ freeze(shift) } >> sub{ encode_base64(shift, '') }
  << sub{ decode_base64(shift) } << sub{ thaw(shift) };

my $client = Connect($server->host, $server->port);
$client >>= sub{ freeze(shift) };
$client >>= sub{ encode_base64(shift, '') };
$client <<= sub{ decode_base64(shift) };
$client <<= sub{ thaw(shift) };

my $timeout = async {
  Coro::AnyEvent::sleep 10;
  $server->stop;
};

$client->($message);
$response = <$client>;
$client->close;
$server->stop;

is $request,  $message, 'request in expected format';
is $response, $message, 'response in expected format';

done_testing;
