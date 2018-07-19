BEGIN {
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
use Coro::Handle qw(unblock);
use AnyEvent::Util qw(portable_pipe);
use JSON::XS qw(encode_json decode_json);
use Ion;

subtest 'basics' => sub{
  ok(my $server = Service { uc $_[0] }, 'Server')
    or bail_out('failed to bind service');

  diag 'server started and listening on ' . ($server->host || 'undef') . ':' . ($server->port || 'undef');

  my $conn;
  ok lives{ $conn = Connect('localhost', $server->port), 'Connect' }, 'Connect';

  ok(lives{ $conn->connect }, 'conn->connect')
    or bail_out(sprintf('failed to connect to host %s:%s', $server->host || 'undef', $server->port || 'undef'));

  my $timeout = async {
    Coro::AnyEvent::sleep 10;
    $server->stop;
  };

  ok $conn->('hello world'), 'conn->(msg)';
  is <$conn>, 'HELLO WORLD', '<conn>';

  ok $conn->('how now brown bureaucrat'), 'conn->(msg)';
  is <$conn>, 'HOW NOW BROWN BUREAUCRAT', '<conn>';

  ok $conn->close, 'conn: close';

  ok $server->stop, 'server: stop';
  ok $server->join, 'server: join';

  $timeout->safe_cancel;
};

subtest 'wrapping handles' => sub{
  my $timeout = async {
    Coro::AnyEvent::sleep 10;
    die 'timed out';
  };

  my ($r, $w) = portable_pipe;
  my $in  = Connect(unblock($r)) << \&decode_json;
  my $out = Connect(unblock($w)) >> \&encode_json;

  ok $out->(['foo', 'bar']), 'pipe: out';
  is <$in>, ['foo', 'bar'],  'pipe: in';

  $timeout->safe_cancel;
};

done_testing;
