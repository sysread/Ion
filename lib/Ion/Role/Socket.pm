package Ion::Role::Socket;

use common::sense;

use Moo::Role;

has host => (is => 'rw');
has port => (is => 'rw');

1;
