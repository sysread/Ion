use Test2::V0;
use Ion::Test;
use Ion::Loop;

ok my $loop = Loop{ $_[0] + 10 }, 'ctor';
ok $loop->isa('Ion::Loop'), 'isa';

$loop->put($_) foreach qw(2 4 6 8);
is $loop->get, 12, 'get: 10 + 2 = 12';
is $loop->get, 14, 'get: 10 + 4 = 14';
is $loop->get, 16, 'get: 10 + 6 = 16';
is $loop->get, 18, 'get: 10 + 8 = 18';

done_testing;
