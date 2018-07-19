BEGIN {
  require Test2::V0;

  if ($^O =~ /mswin32/i) {
    my $ok; local $SIG{CHLD} = sub { $ok = 1 }; kill 'CHLD', 0;
    Test2::V0::skip_all('broken perl detected') unless $ok;
  }

  Test2::V0::skip_all('broken perl detected') unless exists $SIG{USR1};

  require AnyEvent::Impl::Perl;
}

use Test2::V0;
use Coro;
use Coro::AnyEvent;
use Ion;

ok my $server = Listen, 'Listen';
$server->start;

ok my $conn = Connect('localhost', $server->port), 'Connect';

my $service = async {
  while (my $client = <$server>) {
    while (my $msg = <$client>) {
      $client->(uc($msg));
    }
  }
};

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
$timeout->safe_cancel;

done_testing;
