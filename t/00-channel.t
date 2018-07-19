use Test2::V0;
use Ion::Test;
use Ion::Channel;
use AnyEvent;

ok my $ch = Ion::Channel->new, 'ctor';
is $ch->size,   0, 'size';
is $ch->put(1), 1, 'put 1';
is $ch->put(2), 2, 'put 2';
is $ch->put(3), 3, 'put 3';
is $ch->size,   3, 'size';
is $ch->get,    1, 'get 1';
is $ch->get,    2, 'get 2';
is $ch->get,    3, 'get 3';
is $ch->size,   0, 'size';

my $shutdown = AnyEvent->timer(after => 1, cb => sub{ $ch->shutdown });
my $backstop = AnyEvent->timer(after => 5, cb => sub{ bail_out("backstop timeout reached") });
is $ch->get, U, 'shutdown';

done_testing;
